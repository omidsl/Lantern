import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0F19),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LanternCoreApp());
}

class LanternCoreApp extends StatelessWidget {
  const LanternCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0066FF),
          secondary: Color(0xFF00D4FF),
          surface: Color(0xFF131B2E),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const LanternDashboard(),
    );
  }
}

// ==================== مدل داده سرور ====================
class VpnProfile {
  final String id;
  final String name;
  final String rawUri;
  final String protocol;
  final String address;
  final int port;
  int ping;
  bool isPinging;

  VpnProfile({
    required this.id,
    required this.name,
    required this.rawUri,
    required this.protocol,
    required this.address,
    required this.port,
    this.ping = -1,
    this.isPinging = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rawUri': rawUri,
        'protocol': protocol,
        'address': address,
        'port': port,
        'ping': ping,
      };

  factory VpnProfile.fromJson(Map<String, dynamic> json) => VpnProfile(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name']?.toString() ?? 'Server',
        rawUri: json['rawUri']?.toString() ?? '',
        protocol: json['protocol']?.toString() ?? 'VLESS',
        address: json['address']?.toString() ?? '',
        port: int.tryParse(json['port']?.toString() ?? '443') ?? 443,
        ping: json['ping'] is int ? json['ping'] : -1,
      );
}

// ==================== موتور مبدل اختصاصی استاندارد Xray (پشتیبانی کامل از Reality / WS / gRPC) ====================
class XrayConfigBuilder {
  static String decodeB64(String str) {
    String clean = str.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '+').replaceAll('_', '/');
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    return utf8.decode(base64.decode(clean), allowMalformed: true);
  }

  static VpnProfile? parseProfile(String link, int index) {
    final clean = link.trim();
    try {
      if (clean.startsWith('vmess://')) {
        final decoded = decodeB64(clean.substring(8));
        final Map<String, dynamic> map = jsonDecode(decoded);
        final String host = map['add']?.toString() ?? '';
        final int port = int.tryParse(map['port']?.toString() ?? '443') ?? 443;
        final String ps = map['ps']?.toString() ?? 'VMess #$index';
        if (host.isEmpty) return null;
        return VpnProfile(
          id: '${DateTime.now().microsecondsSinceEpoch}_$index',
          name: ps,
          rawUri: clean,
          protocol: 'VMESS',
          address: host,
          port: port,
        );
      } else if (clean.startsWith('vless://') ||
          clean.startsWith('trojan://') ||
          clean.startsWith('ss://')) {
        String remark = 'Server #$index';
        String withoutHash = clean;
        final int hashIdx = clean.indexOf('#');
        if (hashIdx != -1) {
          remark = Uri.decodeComponent(clean.substring(hashIdx + 1)).trim();
          withoutHash = clean.substring(0, hashIdx);
        }
        final Uri uri = Uri.parse(withoutHash);
        if (uri.host.isEmpty) return null;
        final String proto = clean.split('://').first.toUpperCase();
        return VpnProfile(
          id: '${DateTime.now().microsecondsSinceEpoch}_$index',
          name: remark.isNotEmpty ? remark : '$proto #$index',
          rawUri: clean,
          protocol: proto,
          address: uri.host,
          port: uri.port > 0 ? uri.port : 443,
        );
      }
    } catch (_) {
      // اگر فرمت خاص بود، تلاش با پارسر پلاگین
      try {
        final p = FlutterV2ray.parseFromURL(clean);
        return VpnProfile(
          id: '${DateTime.now().microsecondsSinceEpoch}_$index',
          name: p.remark.isNotEmpty ? p.remark : 'Server #$index',
          rawUri: clean,
          protocol: clean.split('://').first.toUpperCase(),
          address: 'Auto',
          port: 443,
        );
      } catch (_) {}
    }
    return null;
  }

  // ساخت کانفیگ کامل Xray مطابق استاندارد v2rayNG
  static String buildFullJson(String rawUri) {
    final trimmed = rawUri.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    try {
      // برای لینک‌های VLESS (شامل Reality، WS، gRPC و TLS) از موتور دقیق داخلی استفاده می‌کنیم
      if (trimmed.startsWith('vless://')) {
        return _buildVlessConfig(trimmed);
      } else if (trimmed.startsWith('trojan://')) {
        return _buildTrojanConfig(trimmed);
      }
    } catch (_) {}

    // فالبک استاندارد به پارسر پلاگین برای VMess و Shadowsocks
    final parsed = FlutterV2ray.parseFromURL(trimmed);
    return parsed.getFullConfiguration();
  }

  static String _buildVlessConfig(String link) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    final Map<String, String> q = uri.queryParameters;

    final String uuid = Uri.decodeComponent(uri.userInfo);
    final String address = uri.host;
    final int port = uri.port > 0 ? uri.port : 443;
    final String encryption = q['encryption'] ?? 'none';
    final String flow = q['flow'] ?? '';

    final Map<String, dynamic> user = {
      'id': uuid,
      'encryption': encryption,
      'level': 8,
    };
    if (flow.isNotEmpty) {
      user['flow'] = flow;
    }

    final Map<String, dynamic> outbound = {
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': address,
            'port': port,
            'users': [user],
          }
        ]
      },
      'streamSettings': _buildStreamSettings(q, address),
    };

    return _wrapInBaseConfig(outbound);
  }

  static String _buildTrojanConfig(String link) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    final Map<String, String> q = uri.queryParameters;

    final String password = Uri.decodeComponent(uri.userInfo);
    final String address = uri.host;
    final int port = uri.port > 0 ? uri.port : 443;

    final Map<String, dynamic> outbound = {
      'tag': 'proxy',
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {
            'address': address,
            'port': port,
            'password': password,
            'level': 8,
          }
        ]
      },
      'streamSettings': _buildStreamSettings(q, address),
    };

    return _wrapInBaseConfig(outbound);
  }

  static Map<String, dynamic> _buildStreamSettings(Map<String, String> q, String defaultHost) {
    final String net = (q['type'] ?? 'tcp').toLowerCase();
    final String security = (q['security'] ?? 'none').toLowerCase();
    final String sni = q['sni'] ?? q['host'] ?? defaultHost;
    final String fp = q['fp'] ?? 'chrome';
    final String alpnStr = q['alpn'] ?? '';
    final String path = q['path'] ?? '/';
    final String hostHeader = q['host'] ?? '';

    final Map<String, dynamic> stream = {
      'network': net,
      'security': security,
    };

    if (security == 'tls') {
      final Map<String, dynamic> tlsSettings = {
        'allowInsecure': q['allowInsecure'] == '1' || q['allowInsecure'] == 'true',
        'serverName': sni,
        'fingerprint': fp,
      };
      if (alpnStr.isNotEmpty) {
        tlsSettings['alpn'] = alpnStr.split(',').map((e) => e.trim()).toList();
      }
      stream['tlsSettings'] = tlsSettings;
    } else if (security == 'reality') {
      stream['realitySettings'] = {
        'show': false,
        'fingerprint': fp,
        'serverName': sni,
        'publicKey': q['pbk'] ?? '',
        'shortId': q['sid'] ?? '',
        'spiderX': q['spx'] ?? '/',
      };
    }

    if (net == 'ws') {
      stream['wsSettings'] = {
        'path': path,
        'headers': hostHeader.isNotEmpty ? {'Host': hostHeader} : {},
      };
    } else if (net == 'grpc') {
      stream['grpcSettings'] = {
        'serviceName': q['serviceName'] ?? path,
        'multiMode': q['mode'] == 'multi',
      };
    } else if (net == 'tcp' && (q['headerType'] == 'http')) {
      stream['tcpSettings'] = {
        'header': {
          'type': 'http',
          'request': {
            'version': '1.1',
            'method': 'GET',
            'path': [path],
            'headers': {
              'Host': hostHeader.isNotEmpty ? [hostHeader] : [defaultHost],
              'User-Agent': [
                'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.75 Safari/537.36'
              ],
              'Accept-Encoding': ['gzip, deflate'],
              'Connection': ['keep-alive'],
              'Pragma': 'no-cache',
            }
          }
        }
      };
    }

    return stream;
  }

  static String _wrapInBaseConfig(Map<String, dynamic> proxyOutbound) {
    final Map<String, dynamic> fullConfig = {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks',
          'port': 10808,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls'],
          },
          'settings': {'auth': 'noauth', 'udp': true},
        },
        {
          'tag': 'http',
          'port': 10809,
          'listen': '127.0.0.1',
          'protocol': 'http',
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls'],
          },
          'settings': {},
        }
      ],
      'outbounds': [
        proxyOutbound,
        {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
        {'tag': 'block', 'protocol': 'blackhole', 'settings': {}},
      ],
      'dns': {
        'servers': ['8.8.8.8', '1.1.1.1']
      },
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          {
            'type': 'field',
            'outboundTag': 'direct',
            'ip': ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
          }
        ]
      }
    };
    return jsonEncode(fullConfig);
  }
}

// ==================== صفحه اصلی نرم‌افزار ====================
class LanternDashboard extends StatefulWidget {
  const LanternDashboard({super.key});

  @override
  State<LanternDashboard> createState() => _LanternDashboardState();
}

class _LanternDashboardState extends State<LanternDashboard> {
  late final FlutterV2ray flutterV2ray;
  V2RayStatus v2rayStatus = V2RayStatus();

  List<VpnProfile> profiles = [];
  int activeIdx = 0;

  bool engineReady = false;
  bool isBusy = false;
  bool isPingingAll = false;
  String statusMessage = "آماده اتصال";

  @override
  void initState() {
    super.initState();
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        setState(() {
          v2rayStatus = status;
          if (status.state == 'CONNECTED') {
            isBusy = false;
            statusMessage = "متصل شد • تونل فعال است";
          } else if (status.state == 'DISCONNECTED') {
            isBusy = false;
            statusMessage = "قطع شد";
          }
        });
      },
    );
    _initEngine();
    _loadProfiles();
  }

  Future<void> _initEngine() async {
    try {
      await flutterV2ray.initializeV2Ray();
      if (mounted) {
        setState(() {
          engineReady = true;
          statusMessage = "هسته Xray آماده به کار است";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => statusMessage = "خطا در راه‌اندازی اولیه هسته: $e");
      }
    }
  }

  Future<void> _loadProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('lantern_v8_profiles') ?? [];
      final loaded = <VpnProfile>[];
      for (var item in list) {
        try {
          loaded.add(VpnProfile.fromJson(jsonDecode(item)));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        profiles = loaded;
        activeIdx = prefs.getInt('activeIdx') ?? 0;
        if (activeIdx >= profiles.length) activeIdx = 0;
      });
    } catch (_) {}
  }

  Future<void> _saveProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'lantern_v8_profiles',
        profiles.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await prefs.setInt('activeIdx', activeIdx);
    } catch (_) {}
  }

  // ==================== اتصال و قطع تضمینی ====================
  Future<void> handleConnectButton() async {
    HapticFeedback.mediumImpact();

    if (v2rayStatus.state == 'CONNECTED') {
      setState(() => statusMessage = "در حال قطع اتصال...");
      await flutterV2ray.stopV2Ray();
      return;
    }

    if (profiles.isEmpty) {
      _showAddModal();
      return;
    }

    if (activeIdx < 0 || activeIdx >= profiles.length) {
      activeIdx = 0;
    }

    final VpnProfile selected = profiles[activeIdx];

    setState(() {
      isBusy = true;
      statusMessage = "در حال بررسی مجوز VPN...";
    });

    try {
      if (!engineReady) {
        await flutterV2ray.initializeV2Ray();
        engineReady = true;
      }

      final bool allowed = await flutterV2ray.requestPermission();
      if (!allowed) {
        setState(() {
          isBusy = false;
          statusMessage = "مجوز VPN توسط گوشی رد شد!";
        });
        return;
      }

      setState(() => statusMessage = "در حال ساخت کانفیگ برای ${selected.name}...");
      final String configJson = XrayConfigBuilder.buildFullJson(selected.rawUri);

      setState(() => statusMessage = "در حال استارت هسته Xray...");
      await flutterV2ray.startV2Ray(
        remark: selected.name,
        config: configJson,
        bypassSubnets: null,
      );

      // تایمر بررسی اتصال در صورتی که هسته بدون خطا رد شود
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && isBusy && v2rayStatus.state != 'CONNECTED') {
          setState(() {
            isBusy = false;
            statusMessage = "سرور پاسخ نداد. سرور دیگری انتخاب کنید.";
          });
        }
      });
    } catch (e) {
      setState(() {
        isBusy = false;
        statusMessage = "خطا در کانفیگ: $e";
      });
    }
  }

  // انتخاب دستی سرور از لیست
  Future<void> selectProfile(int index) async {
    if (index < 0 || index >= profiles.length) return;
    HapticFeedback.selectionClick();

    final bool wasConnected = v2rayStatus.state == 'CONNECTED';
    setState(() {
      activeIdx = index;
      statusMessage = "سرور «${profiles[index].name}» انتخاب شد";
    });
    await _saveProfiles();

    if (wasConnected) {
      await flutterV2ray.stopV2Ray();
      await Future.delayed(const Duration(milliseconds: 500));
      await handleConnectButton();
    }
  }

  // تست پینگ سریع TCP (بدون قفل کردن هسته Xray)
  Future<void> testTcpPing(VpnProfile p) async {
    if (!mounted || p.address.isEmpty || p.address == 'Auto') return;
    setState(() => p.isPinging = true);

    int result = -2;
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        p.address,
        p.port,
        timeout: const Duration(milliseconds: 2200),
      );
      sw.stop();
      await socket.close();
      result = sw.elapsedMilliseconds;
    } catch (_) {
      result = -2;
    }

    if (!mounted) return;
    setState(() {
      p.ping = result;
      p.isPinging = false;
    });
  }

  Future<void> testAllPings() async {
    if (profiles.isEmpty || isPingingAll) return;
    setState(() {
      isPingingAll = true;
      statusMessage = "در حال تست پینگ سرورها...";
    });

    for (final p in profiles) {
      await testTcpPing(p);
    }

    if (!mounted) return;
    setState(() {
      isPingingAll = false;
      statusMessage = "تست پینگ تمام شد";
    });
    _saveProfiles();
  }

  void sortProfilesByPing() {
    if (profiles.length < 2) return;
    final currentId = profiles[activeIdx].id;
    setState(() {
      profiles.sort((a, b) {
        if (a.ping <= 0 && b.ping <= 0) return 0;
        if (a.ping <= 0) return 1;
        if (b.ping <= 0) return -1;
        return a.ping.compareTo(b.ping);
      });
      final newIndex = profiles.indexWhere((e) => e.id == currentId);
      activeIdx = newIndex != -1 ? newIndex : 0;
      statusMessage = "سرورها بر اساس سریع‌ترین پینگ مرتب شدند";
    });
    _saveProfiles();
  }

  // ==================== ایمپورت کانفیگ یا لینک اشتراک ====================
  Future<void> pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      setState(() => statusMessage = "کلیپ‌بورد گوشی خالی است!");
      return;
    }
    await _importText(data.text!.trim());
  }

  Future<void> _importText(String rawText) async {
    if (rawText.startsWith('http://') || rawText.startsWith('https://')) {
      setState(() => statusMessage = "در حال دانلود سرورها از لینک اشتراک...");
      try {
        final res = await http.get(
          Uri.parse(rawText),
          headers: {'User-Agent': 'v2rayNG/1.8.19'},
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          String body = res.body.trim();
          if (!body.contains('://')) {
            try {
              body = XrayConfigBuilder.decodeB64(body);
            } catch (_) {}
          }
          _parseMultipleLines(body);
        } else {
          setState(() => statusMessage = "خطای سرور اشتراک: کد ${res.statusCode}");
        }
      } catch (e) {
        setState(() => statusMessage = "خطا در باز کردن لینک اشتراک");
      }
    } else {
      _parseMultipleLines(rawText);
    }
  }

  void _parseMultipleLines(String text) {
    final lines = text.split(RegExp(r'[\r\n]+'));
    final added = <VpnProfile>[];

    for (var line in lines) {
      final l = line.trim();
      if (l.isEmpty) continue;
      final profile = XrayConfigBuilder.parseProfile(l, profiles.length + added.length + 1);
      if (profile != null) {
        added.add(profile);
      }
    }

    if (added.isEmpty) {
      setState(() => statusMessage = "هیچ کانفیگ معتبری در متن پیدا نشد!");
      return;
    }

    setState(() {
      profiles.insertAll(0, added);
      activeIdx = 0;
      statusMessage = "${added.length} کانفیگ با موفقیت اضافه و انتخاب شد";
    });
    _saveProfiles();
    testAllPings();
  }

  void _showAddModal() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('افزودن کانفیگ یا اشتراک', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'vless://...\nvmess://...\nhttps://...',
            filled: true,
            fillColor: const Color(0xFF0B0F19),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بستن', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0066FF)),
            onPressed: () {
              final txt = ctrl.text.trim();
              Navigator.pop(ctx);
              if (txt.isNotEmpty) _importText(txt);
            },
            child: const Text('افزودن', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showConfigInspector(VpnProfile p) {
    String jsonStr = "";
    try {
      final raw = XrayConfigBuilder.buildFullJson(p.rawUri);
      final obj = jsonDecode(raw);
      jsonStr = const JsonEncoder.withIndent('  ').convert(obj);
    } catch (e) {
      jsonStr = "Error building JSON: $e";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('خروجی هسته: ${p.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF00D4FF)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonStr));
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonStr,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF00FF9D)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtSpeed(dynamic val) {
    final int b = int.tryParse(val.toString()) ?? 0;
    if (b < 1024) return '$b B/s';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB/s';
    return '${(b / 1048576).toStringAsFixed(2)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = v2rayStatus.state == 'CONNECTED';
    final VpnProfile? current =
        (profiles.isNotEmpty && activeIdx < profiles.length) ? profiles[activeIdx] : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ۱. نوار ابزار صنعتی بالا
            _buildTopBar(),

            // ۲. پنل فرمان اتصال و وضعیت زنده
            _buildConnectionControlCard(isConnected, current),

            // ۳. هدر لیست سرورها با دکمه‌های کنترلی
            _buildListActionHeader(),

            // ۴. لیست سرورها با انتخاب مستقیم
            Expanded(
              child: _buildServerListView(isConnected),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LANTERN CORE',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2),
                  ),
                  Text(
                    'Xray Native Tunnel Engine',
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF131B2E),
                  foregroundColor: const Color(0xFF00D4FF),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF0066FF), width: 1),
                  ),
                ),
                onPressed: pasteFromClipboard,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('چسباندن لینک', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _showAddModal,
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionControlCard(bool isConnected, VpnProfile? current) {
    final Color statusColor = isConnected
        ? const Color(0xFF00E676)
        : (isBusy ? const Color(0xFFFFB300) : const Color(0xFF0066FF));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(isConnected ? 0.8 : 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(isConnected ? 0.18 : 0.05),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // دکمه بزرگ پاور در سمت راست کارت
              GestureDetector(
                onTap: handleConnectButton,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.15),
                    border: Border.all(color: statusColor, width: 2.5),
                  ),
                  child: Center(
                    child: isBusy
                        ? SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(strokeWidth: 3, color: statusColor),
                          )
                        : Icon(
                            isConnected ? Icons.stop_rounded : Icons.power_settings_new_rounded,
                            size: 38,
                            color: statusColor,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // اطلاعات سرور فعال و وضعیت
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isConnected
                            ? '● متصل (${v2rayStatus.duration})'
                            : (isBusy ? '⏳ در حال اتصال...' : '○ آماده اتصال'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      current != null ? current.name : 'هیچ سروری انتخاب نشده',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),
          // نوار سرعت دانلود و آپلود
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_downward_rounded, size: 15, color: Color(0xFF00E676)),
                  const SizedBox(width: 4),
                  const Text('دانلود: ', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  Text(
                    isConnected ? _fmtSpeed(v2rayStatus.downloadSpeed) : '0 B/s',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00E676)),
                  ),
                ],
              ),
              Container(width: 1, height: 16, color: Colors.white12),
              Row(
                children: [
                  const Icon(Icons.arrow_upward_rounded, size: 15, color: Color(0xFF00D4FF)),
                  const SizedBox(width: 4),
                  const Text('آپلود: ', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  Text(
                    isConnected ? _fmtSpeed(v2rayStatus.uploadSpeed) : '0 B/s',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00D4FF)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListActionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'سرورها (${profiles.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white70),
          ),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                onPressed: testAllPings,
                icon: const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF00D4FF)),
                label: const Text('تست پینگ', style: TextStyle(fontSize: 11.5, color: Color(0xFF00D4FF))),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
                onPressed: sortProfilesByPing,
                icon: const Icon(Icons.sort_rounded, size: 16, color: Colors.white70),
                label: const Text('مرتب‌سازی', style: TextStyle(fontSize: 11.5, color: Colors.white70)),
              ),
              if (profiles.isNotEmpty) ...[
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () {
                    setState(() {
                      profiles.clear();
                      activeIdx = 0;
                    });
                    _saveProfiles();
                  },
                  child: const Text('حذف همه', style: TextStyle(fontSize: 11.5, color: Colors.redAccent)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServerListView(bool isConnected) {
    if (profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns_outlined, size: 48, color: Colors.white24),
            const SizedBox(height: 10),
            const Text(
              'لیست سرورها خالی است',
              style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'لینک کانفیگ یا اشتراک خود را کپی کنید و دکمه «چسباندن لینک» بالا را بزنید',
              style: TextStyle(color: Colors.white38, fontSize: 11.5),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final p = profiles[index];
        final bool selected = index == activeIdx;

        Color pingColor = const Color(0xFF00E676);
        if (p.ping > 250) pingColor = const Color(0xFFFFB300);
        if (p.ping <= 0 || p.ping > 600) pingColor = Colors.redAccent;

        return GestureDetector(
          onTap: () => selectProfile(index),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF192542) : const Color(0xFF111726),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? (isConnected ? const Color(0xFF00E676) : const Color(0xFF0066FF))
                    : Colors.white.withOpacity(0.05),
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected
                      ? (isConnected ? const Color(0xFF00E676) : const Color(0xFF00D4FF))
                      : Colors.white30,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                          color: selected ? Colors.white : Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0066FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.protocol,
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF00D4FF), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${p.address}:${p.port}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // نمایش و تست تکی پینگ
                GestureDetector(
                  onTap: () => testTcpPing(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: p.isPinging
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF)),
                          )
                        : Text(
                            p.ping > 0 ? '${p.ping} ms' : (p.ping == -2 ? 'Timeout' : 'تست'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: p.ping > 0 ? pingColor : Colors.white38,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 4),
                // دکمه بررسی کانفیگ JSON تولیدشده
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'مشاهده کانفیگ هسته',
                  icon: const Icon(Icons.code_rounded, size: 18, color: Colors.white38),
                  onPressed: () => _showConfigInspector(p),
                ),
                // دکمه حذف تکی
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white38),
                  onPressed: () {
                    setState(() {
                      profiles.removeAt(index);
                      if (activeIdx >= profiles.length) activeIdx = 0;
                    });
                    _saveProfiles();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
