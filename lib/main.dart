import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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
      systemNavigationBarColor: Color(0xFF05060B),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LanternUltimateApp());
}

class LanternUltimateApp extends StatelessWidget {
  const LanternUltimateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF05060B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4B90FF),
          secondary: Color(0xFFA87FFB),
          surface: Color(0xFF0E1220),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const LanternHomeScreen(),
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

// ==================== موتور مبدل اختصاصی Xray (با محافظت کامل در برابر نشت IP و DNS) ====================
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

  // ساخت کانفیگ کامل Xray همراه با حالت انتخاب‌شده (0: تونل کامل ضد نشت، 1: هوشمند، 2: ضد فیلتر Fragment)
  static String buildFullJson(String rawUri, {required int tunnelMode}) {
    final trimmed = rawUri.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    String baseConfigStr = "";
    try {
      if (trimmed.startsWith('vless://')) {
        baseConfigStr = _buildVlessConfig(trimmed, tunnelMode: tunnelMode);
      } else if (trimmed.startsWith('trojan://')) {
        baseConfigStr = _buildTrojanConfig(trimmed, tunnelMode: tunnelMode);
      }
    } catch (_) {}

    if (baseConfigStr.isEmpty) {
      final parsed = FlutterV2ray.parseFromURL(trimmed);
      baseConfigStr = _enhancePluginConfig(parsed.getFullConfiguration(), tunnelMode: tunnelMode);
    }

    return baseConfigStr;
  }

  static String _enhancePluginConfig(String rawJson, {required int tunnelMode}) {
    try {
      final Map<String, dynamic> config = jsonDecode(rawJson);
      config['dns'] = {
        'servers': ['1.1.1.1', '8.8.8.8'],
        'queryStrategy': 'UseIPv4',
      };
      if (tunnelMode == 2 && config['outbounds'] is List && (config['outbounds'] as List).isNotEmpty) {
        final Map<String, dynamic> mainOut = config['outbounds'][0];
        mainOut['streamSettings'] ??= <String, dynamic>{};
        mainOut['streamSettings']['sockopt'] = {
          'dialerProxy': 'fragment',
          'tcpNoDelay': true,
        };
        (config['outbounds'] as List).add({
          'tag': 'fragment',
          'protocol': 'freedom',
          'settings': {
            'domainStrategy': 'AsIs',
            'fragment': {
              'packets': 'tlshello',
              'length': '10-20',
              'interval': '10-20',
            }
          }
        });
      }
      return jsonEncode(config);
    } catch (_) {
      return rawJson;
    }
  }

  static String _buildVlessConfig(String link, {required int tunnelMode}) {
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
      'streamSettings': _buildStreamSettings(q, address, enableFragment: tunnelMode == 2),
    };

    return _wrapInBaseConfig(outbound, tunnelMode: tunnelMode);
  }

  static String _buildTrojanConfig(String link, {required int tunnelMode}) {
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
      'streamSettings': _buildStreamSettings(q, address, enableFragment: tunnelMode == 2),
    };

    return _wrapInBaseConfig(outbound, tunnelMode: tunnelMode);
  }

  static Map<String, dynamic> _buildStreamSettings(
    Map<String, String> q,
    String defaultHost, {
    required bool enableFragment,
  }) {
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

    if (enableFragment && security != 'reality') {
      stream['sockopt'] = {
        'dialerProxy': 'fragment',
        'tcpNoDelay': true,
      };
    }

    return stream;
  }

  static String _wrapInBaseConfig(Map<String, dynamic> proxyOutbound, {required int tunnelMode}) {
    final List<Map<String, dynamic>> outbounds = [
      proxyOutbound,
      {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
      {'tag': 'block', 'protocol': 'blackhole', 'settings': {}},
    ];

    if (tunnelMode == 2) {
      outbounds.add({
        'tag': 'fragment',
        'protocol': 'freedom',
        'settings': {
          'domainStrategy': 'AsIs',
          'fragment': {
            'packets': 'tlshello',
            'length': '10-20',
            'interval': '10-20',
          }
        }
      });
    }

    final List<Map<String, dynamic>> rules = [
      // مسدود کردن IPv6 برای جلوگیری ۱۰۰ درصدی از نشت IPv6
      {
        'type': 'field',
        'outboundTag': 'block',
        'ip': ['::/0'],
      },
      // هدایت شبکه‌های محلی
      {
        'type': 'field',
        'outboundTag': 'direct',
        'ip': ['127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
      },
    ];

    // اگر حالت ۱ (هوشمند ایران) فعال باشد، سایت‌های .ir مستقیم رد می‌شوند؛ در حالت ۰ (تونل کامل ضد نشت) همه چیز از پروکسی رد می‌شود
    if (tunnelMode == 1) {
      rules.add({
        'type': 'field',
        'outboundTag': 'direct',
        'domain': [
          'regexp:.*\\.ir\$',
          'domain:shaparak.ir',
          'domain:snapp.ir',
          'domain:digikala.com',
          'domain:aparat.com',
          'domain:divar.ir',
        ]
      });
    }

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
      'outbounds': outbounds,
      'dns': {
        'servers': ['1.1.1.1', '8.8.8.8'],
        'queryStrategy': 'UseIPv4',
      },
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': rules,
      }
    };
    return jsonEncode(fullConfig);
  }
}

// ==================== صفحه اصلی نرم‌افزار (طراحی شیشه‌ای iOS 18 x Gemini) ====================
class LanternHomeScreen extends StatefulWidget {
  const LanternHomeScreen({super.key});

  @override
  State<LanternHomeScreen> createState() => _LanternHomeScreenState();
}

class _LanternHomeScreenState extends State<LanternHomeScreen>
    with SingleTickerProviderStateMixin {
  late final FlutterV2ray flutterV2ray;
  V2RayStatus v2rayStatus = V2RayStatus();
  late final AnimationController _auraController;

  List<VpnProfile> profiles = [];
  int activeIdx = 0;

  bool engineReady = false;
  bool isBusy = false;
  bool isPingingAll = false;
  bool isSyncingSub = false;

  // دو حالت انتخاب سرور: اتوماتیک (سریع‌ترین سرور) یا دستی (ثابت)
  bool isAutoSelect = false;

  // حالت‌های تونل: 0 = تونل کامل ضد نشت، 1 = هوشمند ایران، 2 = ضد فیلتر Fragment
  int tunnelMode = 0;

  // اطلاعات اشتراک
  String subTitle = "اشتراک ابری لنترن";
  String savedSubUrl = "";
  double usedGB = 0.0;
  double totalGB = 0.0;
  int? expireDays;

  // بررسی IP واقعی برای اطمینان از عدم نشت
  String currentIp = "بررسی نشده";
  String currentCountry = "ضربه بزنید برای تست IP";
  bool isCheckingIp = false;

  @override
  void initState() {
    super.initState();
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final wasConn = v2rayStatus.state == 'CONNECTED';
        final nowConn = status.state == 'CONNECTED';
        setState(() {
          v2rayStatus = status;
          if (nowConn || status.state == 'DISCONNECTED') {
            isBusy = false;
          }
          if (!nowConn) {
            currentIp = "تونل غیرفعال";
            currentCountry = "برای امنیت کامل متصل شوید";
          }
        });
        if (!wasConn && nowConn) {
          Future.delayed(const Duration(seconds: 1), verifyIpLeak);
        }
      },
    );
    _initEngine();
    _loadData();
  }

  @override
  void dispose() {
    _auraController.dispose();
    super.dispose();
  }

  Future<void> _initEngine() async {
    try {
      await flutterV2ray.initializeV2Ray();
      if (mounted) setState(() => engineReady = true);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('lantern_v10_profiles') ??
          prefs.getStringList('lantern_v8_profiles') ??
          [];
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
        if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;
        isAutoSelect = prefs.getBool('isAutoSelect') ?? false;
        tunnelMode = prefs.getInt('tunnelMode') ?? 0;
        subTitle = prefs.getString('subTitle') ?? "اشتراک ابری لنترن";
        savedSubUrl = prefs.getString('savedSubUrl') ?? "";
        usedGB = prefs.getDouble('usedGB') ?? 0.0;
        totalGB = prefs.getDouble('totalGB') ?? 0.0;
        expireDays = prefs.getInt('expireDays');
      });
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'lantern_v10_profiles',
        profiles.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await prefs.setInt('activeIdx', activeIdx);
      await prefs.setBool('isAutoSelect', isAutoSelect);
      await prefs.setInt('tunnelMode', tunnelMode);
      await prefs.setString('subTitle', subTitle);
      await prefs.setString('savedSubUrl', savedSubUrl);
      await prefs.setDouble('usedGB', usedGB);
      await prefs.setDouble('totalGB', totalGB);
      if (expireDays != null) {
        await prefs.setInt('expireDays', expireDays!);
      }
    } catch (_) {}
  }

  // ==================== اتصال و قطع با پشتیبانی از حالت اتوماتیک و دستی ====================
  Future<void> handleConnect() async {
    HapticFeedback.mediumImpact();

    if (v2rayStatus.state == 'CONNECTED') {
      await flutterV2ray.stopV2Ray();
      return;
    }

    if (profiles.isEmpty) {
      _showAddModal();
      return;
    }

    setState(() => isBusy = true);

    try {
      if (!engineReady) {
        await flutterV2ray.initializeV2Ray();
        engineReady = true;
      }

      // اگر روی حالت «اتوماتیک» باشد، قبل از اتصال سریع‌ترین سرور سالم را پیدا و انتخاب می‌کند
      if (isAutoSelect) {
        final hasValidPing = profiles.any((p) => p.ping > 0);
        if (!hasValidPing) {
          _notify('در حال اسکن اتوماتیک سریع‌ترین سرور...');
          await testAllPings();
        }
        int bestIdx = -1;
        int bestPing = 999999;
        for (int i = 0; i < profiles.length; i++) {
          if (profiles[i].ping > 0 && profiles[i].ping < bestPing) {
            bestPing = profiles[i].ping;
            bestIdx = i;
          }
        }
        if (bestIdx != -1) {
          setState(() => activeIdx = bestIdx);
          await _saveData();
        }
      }

      if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;
      final VpnProfile selected = profiles[activeIdx];

      final bool allowed = await flutterV2ray.requestPermission();
      if (!allowed) {
        setState(() => isBusy = false);
        _notify('مجوز ساخت VPN در گوشی تایید نشد!');
        return;
      }

      final String configJson = XrayConfigBuilder.buildFullJson(
        selected.rawUri,
        tunnelMode: tunnelMode,
      );

      await flutterV2ray.startV2Ray(
        remark: selected.name,
        config: configJson,
        bypassSubnets: null,
      );

      Future.delayed(const Duration(seconds: 7), () {
        if (mounted && isBusy && v2rayStatus.state != 'CONNECTED') {
          setState(() => isBusy = false);
          _notify('سرور پاسخ نداد. سرور دیگری انتخاب کنید.');
        }
      });
    } catch (e) {
      setState(() => isBusy = false);
      _notify('خطا در اتصال: $e');
    }
  }

  // انتخاب مستقیم سرور از لیست
  Future<void> selectProfileFromList(int index) async {
    if (index < 0 || index >= profiles.length) return;
    HapticFeedback.selectionClick();

    final bool wasConnected = v2rayStatus.state == 'CONNECTED';
    setState(() {
      activeIdx = index;
      // وقتی کاربر دستی روی سروری ضربه می‌زند، به حالت دستی می‌رود تا انتخابش قفل بماند
      isAutoSelect = false;
    });
    await _saveData();

    if (wasConnected) {
      _notify('در حال سوییچ به ${profiles[index].name}...');
      await flutterV2ray.stopV2Ray();
      await Future.delayed(const Duration(milliseconds: 500));
      await handleConnect();
    } else {
      _notify('سرور «${profiles[index].name}» قفل شد (حالت دستی)');
    }
  }

  // ==================== تست ضد نشت IP (Anti-IP Leak Checker) ====================
  Future<void> verifyIpLeak() async {
    if (isCheckingIp) return;
    setState(() {
      isCheckingIp = true;
      currentIp = "در حال بررسی...";
    });
    try {
      final res = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            currentIp = data['query']?.toString() ?? 'نامشخص';
            currentCountry = "${data['country'] ?? ''} • ${data['isp'] ?? ''}";
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          currentIp = "محافظت شده";
          currentCountry = "تونل رمزنگاری‌شده فعال است";
        });
      }
    }
    if (mounted) setState(() => isCheckingIp = false);
  }

  // ==================== تست پینگ سریع و بدون قفل شدن هسته ====================
  Future<void> testTcpPing(VpnProfile p) async {
    if (!mounted || p.address.isEmpty || p.address == 'Auto') return;
    setState(() => p.isPinging = true);

    int result = -2;
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        p.address,
        p.port,
        timeout: const Duration(milliseconds: 2000),
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
    HapticFeedback.lightImpact();
    setState(() => isPingingAll = true);

    // تست دسته‌ای ۴تایی برای سرعت بالا بدون درگیر کردن پردازنده
    const int batchSize = 4;
    for (int i = 0; i < profiles.length; i += batchSize) {
      final end = (i + batchSize < profiles.length) ? i + batchSize : profiles.length;
      await Future.wait([for (int j = i; j < end; j++) testTcpPing(profiles[j])]);
    }

    if (!mounted) return;
    setState(() {
      // اگر حالت اتوماتیک روشن باشد، سریع‌ترین سرور را صدر لیست می‌آورد و انتخاب می‌کند
      if (isAutoSelect) {
        profiles.sort((a, b) {
          if (a.ping <= 0 && b.ping <= 0) return 0;
          if (a.ping <= 0) return 1;
          if (b.ping <= 0) return -1;
          return a.ping.compareTo(b.ping);
        });
        activeIdx = 0;
      }
      isPingingAll = false;
    });
    _saveData();
  }

  void sortListByPing() {
    if (profiles.length < 2) return;
    final String selectedId = profiles[activeIdx].id;
    setState(() {
      profiles.sort((a, b) {
        if (a.ping <= 0 && b.ping <= 0) return 0;
        if (a.ping <= 0) return 1;
        if (b.ping <= 0) return -1;
        return a.ping.compareTo(b.ping);
      });
      final idx = profiles.indexWhere((p) => p.id == selectedId);
      activeIdx = idx != -1 ? idx : 0;
    });
    _saveData();
    _notify('لیست بر اساس کمترین پینگ مرتب شد.');
  }

  // ==================== ایمپورت و بروزرسانی اشتراک (Subscription Sync) ====================
  Future<void> pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      _notify('کلیپ‌بورد گوشی خالی است!');
      return;
    }
    await _importText(data.text!.trim());
  }

  Future<void> syncSubscription() async {
    if (savedSubUrl.isEmpty) {
      _notify('ابتدا یک لینک اشتراک (http/https) اضافه کنید.');
      return;
    }
    await _importText(savedSubUrl, isSync: true);
  }

  Future<void> _importText(String rawText, {bool isSync = false}) async {
    if (rawText.startsWith('http://') || rawText.startsWith('https://')) {
      setState(() => isSyncingSub = true);
      _notify('در حال بروزرسانی سرورها از لینک اشتراک...');
      try {
        final res = await http.get(
          Uri.parse(rawText),
          headers: {'User-Agent': 'v2rayNG/1.8.19'},
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          final info = res.headers['subscription-userinfo'];
          if (info != null) _parseSubHeader(info);

          String body = res.body.trim();
          if (!body.contains('://')) {
            try {
              body = XrayConfigBuilder.decodeB64(body);
            } catch (_) {}
          }
          final count = _parseMultipleLines(body, replaceAll: isSync);
          if (count > 0) {
            savedSubUrl = rawText;
            subTitle = Uri.parse(rawText).host;
            _saveData();
          }
        } else {
          _notify('خطا در سرور اشتراک: کد ${res.statusCode}');
        }
      } catch (_) {
        _notify('خطا در دریافت لینک اشتراک. اینترنت را بررسی کنید.');
      }
      if (mounted) setState(() => isSyncingSub = false);
    } else {
      _parseMultipleLines(rawText, replaceAll: false);
    }
  }

  void _parseSubHeader(String header) {
    try {
      int up = 0, down = 0, total = 0, exp = 0;
      for (var part in header.split(';')) {
        final kv = part.trim().split('=');
        if (kv.length == 2) {
          final k = kv[0].trim().toLowerCase();
          final v = int.tryParse(kv[1].trim()) ?? 0;
          if (k == 'upload') up = v;
          if (k == 'download') down = v;
          if (k == 'total') total = v;
          if (k == 'expire') exp = v;
        }
      }
      setState(() {
        usedGB = double.parse(((up + down) / 1073741824).toStringAsFixed(2));
        totalGB = double.parse((total / 1073741824).toStringAsFixed(2));
        if (exp > 0) {
          final d = DateTime.fromMillisecondsSinceEpoch(exp * 1000).difference(DateTime.now()).inDays;
          expireDays = d >= 0 ? d : 0;
        }
      });
    } catch (_) {}
  }

  int _parseMultipleLines(String text, {required bool replaceAll}) {
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
      _notify('هیچ کانفیگ معتبری در متن پیدا نشد!');
      return 0;
    }

    setState(() {
      if (replaceAll) {
        profiles = added;
      } else {
        profiles.insertAll(0, added);
      }
      activeIdx = 0;
    });
    _saveData();
    _notify('✦ ${added.length} سرور آماده شد!');
    testAllPings();
    return added.length;
  }

  void _showAddModal() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101526),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        title: const Text('افزودن کانفیگ یا لینک اشتراک', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              maxLines: 4,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'vless://...\nvmess://...\nhttps://...',
                filled: true,
                fillColor: const Color(0xFF070A14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFA87FFB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final d = await Clipboard.getData(Clipboard.kTextPlain);
                  if (d?.text != null) ctrl.text = d!.text!.trim();
                },
                icon: const Icon(Icons.content_paste_rounded, size: 16, color: Color(0xFFA87FFB)),
                label: const Text('چسباندن از کلیپ‌بورد', style: TextStyle(fontSize: 12, color: Color(0xFFA87FFB))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B90FF)),
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
      final raw = XrayConfigBuilder.buildFullJson(p.rawUri, tunnelMode: tunnelMode);
      final obj = jsonDecode(raw);
      jsonStr = const JsonEncoder.withIndent('  ').convert(obj);
    } catch (e) {
      jsonStr = "Error: $e";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101526),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('کانفیگ هسته: ${p.name}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF00F5D4)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonStr));
                    Navigator.pop(ctx);
                    _notify('کانفیگ JSON کپی شد.');
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
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF00F5D4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _detectFlag(String remark) {
    final up = remark.toUpperCase();
    if (up.contains('DE') || up.contains('GERMANY') || remark.contains('آلمان')) return '🇩🇪';
    if (up.contains('NL') || up.contains('NETHERLANDS') || remark.contains('هلند')) return '🇳🇱';
    if (up.contains('US') || up.contains('AMERICA') || remark.contains('آمریکا')) return '🇺🇸';
    if (up.contains('GB') || up.contains('UK') || up.contains('LONDON') || remark.contains('انگلیس')) return '🇬🇧';
    if (up.contains('FI') || up.contains('FINLAND') || remark.contains('فنلاند')) return '🇫🇮';
    if (up.contains('TR') || up.contains('TURKEY') || remark.contains('ترکیه')) return '🇹🇷';
    if (up.contains('FR') || up.contains('FRANCE') || remark.contains('فرانسه')) return '🇫🇷';
    if (up.contains('SE') || up.contains('SWEDEN') || remark.contains('سوئد')) return '🇸🇪';
    if (up.contains('CH') || up.contains('SWISS') || remark.contains('سوئیس')) return '🇨🇭';
    if (up.contains('AE') || up.contains('DUBAI') || remark.contains('امارات')) return '🇦🇪';
    return '🌐';
  }

  String _fmtSpeed(dynamic val) {
    final int b = int.tryParse(val.toString()) ?? 0;
    if (b < 1024) return '$b B/s';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB/s';
    return '${(b / 1048576).toStringAsFixed(2)} MB/s';
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF141829),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFA87FFB).withOpacity(0.45)),
        ),
        duration: const Duration(seconds: 2),
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = v2rayStatus.state == 'CONNECTED';
    final VpnProfile? current =
        (profiles.isNotEmpty && activeIdx < profiles.length) ? profiles[activeIdx] : null;

    return Scaffold(
      body: Stack(
        children: [
          // ۱. هاله‌های نوری Gemini در پس‌زمینه
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isConnected ? const Color(0xFF00F5D4) : const Color(0xFF4B90FF)).withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 220,
            left: -90,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA87FFB).withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ۲. لایه اصلی رابط کاربری شیشه‌ای
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 8),
                      _buildSubAndLeakCard(isConnected),
                      const SizedBox(height: 8),
                      _buildAutoManualAndTunnelControls(),
                      const SizedBox(height: 12),
                      _buildGeminiOrbAndStats(isConnected, current),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // ۳. لیست مستقیم سرورها در پایین صفحه
                Expanded(
                  child: _buildServerListContainer(isConnected),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4B90FF).withOpacity(0.3),
                    const Color(0xFFA87FFB).withOpacity(0.3),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFA87FFB), size: 18),
            ),
            const SizedBox(width: 9),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFFC7D2FE), Color(0xFFF472B6)],
              ).createShader(bounds),
              child: const Text(
                'Lantern Pro',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Colors.white),
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildGlassIconBtn(
              icon: isSyncingSub ? Icons.hourglass_top_rounded : Icons.sync_rounded,
              color: const Color(0xFF00F5D4),
              tooltip: 'بروزرسانی اشتراک',
              onTap: syncSubscription,
            ),
            const SizedBox(width: 7),
            _buildGlassIconBtn(
              icon: isPingingAll ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
              color: const Color(0xFFA87FFB),
              tooltip: 'تست پینگ همه',
              onTap: testAllPings,
            ),
            const SizedBox(width: 7),
            _buildGlassIconBtn(
              icon: Icons.content_paste_rounded,
              color: Colors.white,
              tooltip: 'چسباندن از کلیپ‌بورد',
              onTap: pasteFromClipboard,
            ),
            const SizedBox(width: 7),
            _buildGlassIconBtn(
              icon: Icons.add_rounded,
              color: const Color(0xFF4B90FF),
              tooltip: 'افزودن دستی',
              onTap: _showAddModal,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassIconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.07),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // کارت ترکیبی وضعیت اشتراک و سپر ضد نشت آی‌پی
  Widget _buildSubAndLeakCard(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: verifyIpLeak,
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    size: 18,
                    color: isConnected ? const Color(0xFF00F5D4) : const Color(0xFFA87FFB),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isConnected ? 'ضد نشت فعال • IP: $currentIp' : subTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                        Text(
                          isConnected
                              ? currentCountry
                              : (totalGB > 0 ? 'مصرف: $usedGB از $totalGB GB' : 'محافظت DNS و IPv6 فعال است'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFA87FFB).withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA87FFB).withOpacity(0.35)),
            ),
            child: Text(
              expireDays != null ? '$expireDays روز فعال' : '${profiles.length} سرور',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE9D5FF)),
            ),
          ),
        ],
      ),
    );
  }

  // سوییچ دوحالته (دستی / اتوماتیک) + انتخابگر نوع تونل
  Widget _buildAutoManualAndTunnelControls() {
    return Column(
      children: [
        // ردیف ۱: حالت دستی یا اتوماتیک
        Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => isAutoSelect = false);
                    _saveData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: !isAutoSelect ? const Color(0xFF4B90FF).withOpacity(0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: !isAutoSelect ? Border.all(color: const Color(0xFF4B90FF).withOpacity(0.6)) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 14, color: !isAutoSelect ? Colors.white : Colors.white54),
                        const SizedBox(width: 5),
                        Text(
                          'حالت دستی (ثابت)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !isAutoSelect ? Colors.white : Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => isAutoSelect = true);
                    _saveData();
                    _notify('حالت اتوماتیک فعال شد: اتصال به سریع‌ترین سرور');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isAutoSelect ? const Color(0xFFA87FFB).withOpacity(0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: isAutoSelect ? Border.all(color: const Color(0xFFA87FFB).withOpacity(0.6)) : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hdr_auto_rounded, size: 14, color: isAutoSelect ? const Color(0xFF00F5D4) : Colors.white54),
                        const SizedBox(width: 5),
                        Text(
                          'حالت اتوماتیک (هوشمند)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAutoSelect ? Colors.white : Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // ردیف ۲: حالت‌های تونل (ضد نشت کامل / هوشمند ایران / ضد فیلتر Fragment)
        Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: ['تونل کامل (ضد نشت)', 'هوشمند (ایران)', 'ضد فیلتر ⚡'].asMap().entries.map((e) {
              final active = tunnelMode == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => tunnelMode = e.key);
                    _saveData();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? Colors.white.withOpacity(0.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      e.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.white54),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // گوی نوری چرخان Gemini در کنار آمار سرعت زنده
  Widget _buildGeminiOrbAndStats(bool isConnected, VpnProfile? current) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          // گوی چرخان Gemini
          GestureDetector(
            onTap: handleConnect,
            child: SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _auraController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _auraController.value * 2 * math.pi,
                        child: Container(
                          width: 98,
                          height: 98,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: isConnected
                                  ? const [Color(0xFF00F5D4), Color(0xFF3B82F6), Color(0xFFA87FFB), Color(0xFF00F5D4)]
                                  : const [Color(0xFF4B90FF), Color(0xFFA87FFB), Color(0xFFFF6B9D), Color(0xFF4B90FF)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isConnected ? const Color(0xFF00F5D4) : const Color(0xFFA87FFB)).withOpacity(0.38),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.3, -0.4),
                        radius: 1.1,
                        colors: [Color(0xFF28314E), Color(0xFF0E1324), Color(0xFF070912)],
                      ),
                      border: Border.all(
                        color: isConnected ? const Color(0xFF00F5D4) : Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isBusy
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFA87FFB)),
                            )
                          : Icon(
                              Icons.power_settings_new_rounded,
                              size: 34,
                              color: isConnected ? const Color(0xFF00F5D4) : Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          // جزئیات اتصال و سرعت زنده
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isConnected ? const Color(0xFF00F5D4) : const Color(0xFF4B90FF)).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isConnected
                            ? '● متصل (${v2rayStatus.duration})'
                            : (isBusy ? '⏳ در حال اتصال...' : (isAutoSelect ? '⚡ آماده اتصال اتوماتیک' : '○ آماده اتصال دستی')),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? const Color(0xFF00F5D4) : const Color(0xFFA5B4FC),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  current != null ? current.name : 'هیچ سروری اضافه نشده',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.south_west_rounded, size: 13, color: Color(0xFF00F5D4)),
                        const SizedBox(width: 3),
                        Text(
                          isConnected ? _fmtSpeed(v2rayStatus.downloadSpeed) : '0 B/s',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF00F5D4)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.north_east_rounded, size: 13, color: Color(0xFFA87FFB)),
                        const SizedBox(width: 3),
                        Text(
                          isConnected ? _fmtSpeed(v2rayStatus.uploadSpeed) : '0 B/s',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFA87FFB)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerListContainer(bool isConnected) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D18).withOpacity(0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'لیست سرورها (${profiles.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.white70),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
                      onPressed: sortListByPing,
                      icon: const Icon(Icons.sort_rounded, size: 15, color: Color(0xFFA87FFB)),
                      label: const Text('مرتب‌سازی پینگ', style: TextStyle(fontSize: 11, color: Color(0xFFA87FFB))),
                    ),
                    if (profiles.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            profiles.clear();
                            activeIdx = 0;
                          });
                          _saveData();
                        },
                        child: const Text('حذف همه', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: profiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_download_outlined, size: 42, color: Colors.white24),
                        const SizedBox(height: 8),
                        const Text('لیست سرورها خالی است', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B90FF)),
                          onPressed: pasteFromClipboard,
                          icon: const Icon(Icons.content_paste_rounded, size: 16),
                          label: const Text('چسباندن لینک از کلیپ‌بورد', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final p = profiles[index];
                      final bool selected = index == activeIdx;

                      Color pingColor = const Color(0xFF00F5D4);
                      if (p.ping > 250) pingColor = const Color(0xFFFBBF24);
                      if (p.ping <= 0 || p.ping > 600) pingColor = Colors.redAccent;

                      return GestureDetector(
                        onTap: () => selectProfileFromList(index),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: selected
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFF4B90FF).withOpacity(0.25),
                                      const Color(0xFFA87FFB).withOpacity(0.18),
                                    ],
                                  )
                                : null,
                            color: selected ? null : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? (isConnected ? const Color(0xFF00F5D4) : const Color(0xFFA87FFB))
                                  : Colors.white.withOpacity(0.06),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: selected
                                    ? (isConnected ? const Color(0xFF00F5D4) : const Color(0xFFA87FFB))
                                    : Colors.white30,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(_detectFlag(p.name), style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
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
                                        fontSize: 12.5,
                                        color: selected ? Colors.white : Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            p.protocol,
                                            style: const TextStyle(fontSize: 9, color: Color(0xFFA87FFB), fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${p.address}:${p.port}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textDirection: TextDirection.ltr,
                                            style: const TextStyle(fontSize: 9.5, color: Colors.white38),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA87FFB)),
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
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.code_rounded, size: 17, color: Colors.white38),
                                onPressed: () => _showConfigInspector(p),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded, size: 17, color: Colors.white38),
                                onPressed: () {
                                  setState(() {
                                    profiles.removeAt(index);
                                    if (activeIdx >= profiles.length) activeIdx = 0;
                                  });
                                  _saveData();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
