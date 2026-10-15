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
  runApp(const LanternVisionApp());
}

class LanternVisionApp extends StatelessWidget {
  const LanternVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern VPN',
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
      home: const LanternMainScreen(),
    );
  }
}

class ServerItem {
  final String id;
  final String remark;
  final String uri;
  final String protocol;
  int ping;
  bool testing;

  ServerItem({
    required this.id,
    required this.remark,
    required this.uri,
    required this.protocol,
    this.ping = -1,
    this.testing = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'remark': remark,
        'uri': uri,
        'protocol': protocol,
        'ping': ping,
      };

  factory ServerItem.fromJson(Map<String, dynamic> json) => ServerItem(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        remark: json['remark']?.toString() ?? 'Server',
        uri: json['uri']?.toString() ?? '',
        protocol: json['protocol']?.toString() ?? 'VLESS',
        ping: json['ping'] is int ? json['ping'] : -1,
      );
}

class LanternMainScreen extends StatefulWidget {
  const LanternMainScreen({super.key});

  @override
  State<LanternMainScreen> createState() => _LanternMainScreenState();
}

class _LanternMainScreenState extends State<LanternMainScreen>
    with SingleTickerProviderStateMixin {
  late final FlutterV2ray flutterV2ray;
  V2RayStatus v2rayStatus = V2RayStatus();
  late final AnimationController _auraController;

  List<ServerItem> servers = [];
  int selectedIndex = 0;

  bool isInitialized = false;
  bool isConnecting = false;
  bool isTestingPings = false;
  Timer? _watchdogTimer;

  // 0 = تونل استاندارد (بدون دستکاری کانفیگ - بالاترین سازگاری)
  // 1 = بدون شبکه محلی (LAN Bypass)
  // 2 = حالت Fragment (مخصوص سرورهای TLS مسدود شده)
  int connectionMode = 0;

  String subName = "اشتراک لنترن";
  String savedSubUrl = "";
  double usedGB = 0.0;
  double totalGB = 0.0;
  int? expireTimestamp;

  static const List<String> privateLanSubnets = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "127.0.0.0/8",
  ];

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
        setState(() {
          v2rayStatus = status;
          if (status.state == 'CONNECTED' || status.state == 'DISCONNECTED') {
            isConnecting = false;
            _watchdogTimer?.cancel();
          }
        });
      },
    );

    _bootEngine();
    _loadSavedData();
  }

  Future<void> _bootEngine() async {
    try {
      await flutterV2ray.initializeV2Ray();
      if (mounted) {
        setState(() => isInitialized = true);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _auraController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('lantern_v7_servers') ?? [];
      final List<ServerItem> loaded = [];
      for (var item in rawList) {
        try {
          final s = ServerItem.fromJson(jsonDecode(item));
          if (s.uri.isNotEmpty) loaded.add(s);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        servers = loaded;
        selectedIndex = prefs.getInt('selectedIndex') ?? 0;
        if (selectedIndex < 0 || selectedIndex >= servers.length) {
          selectedIndex = 0;
        }
        subName = prefs.getString('subName') ?? "اشتراک لنترن";
        savedSubUrl = prefs.getString('savedSubUrl') ?? "";
        usedGB = prefs.getDouble('usedGB') ?? 0.0;
        totalGB = prefs.getDouble('totalGB') ?? 0.0;
        expireTimestamp = prefs.getInt('expireTimestamp');
        connectionMode = prefs.getInt('connectionMode') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'lantern_v7_servers',
        servers.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await prefs.setInt('selectedIndex', selectedIndex);
      await prefs.setString('subName', subName);
      await prefs.setString('savedSubUrl', savedSubUrl);
      await prefs.setDouble('usedGB', usedGB);
      await prefs.setDouble('totalGB', totalGB);
      await prefs.setInt('connectionMode', connectionMode);
      if (expireTimestamp != null) {
        await prefs.setInt('expireTimestamp', expireTimestamp!);
      }
    } catch (_) {}
  }

  // ساخت کانفیگ ۱۰۰٪ خالص و بدون کرش (دقیقاً مشابه نسخه ۱ که روی گوشی شما وصل می‌شد)
  String _buildWorkingConfig(String uriOrJson) {
    final trimmed = uriOrJson.trim();
    // اگر کاربر کانفیگ JSON کامل وارد کرده بود:
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      return trimmed;
    }

    final V2RayURL parser = FlutterV2ray.parseFromURL(trimmed);
    final String rawJson = parser.getFullConfiguration();

    // در حالت ۰ و ۱، اصلاً به ساختار JSON دست نمی‌زنیم تا سرورهای Reality، WS و gRPC بدون خطا وصل شوند
    if (connectionMode != 2) {
      return rawJson;
    }

    // فقط اگر کاربر خودش صراحتاً تب «ضد فیلتر (Fragment)» را انتخاب کرده باشد:
    try {
      final Map<String, dynamic> config = jsonDecode(rawJson);
      final outbounds = config['outbounds'];
      if (outbounds is List && outbounds.isNotEmpty) {
        final Map<String, dynamic> mainOut = outbounds[0];
        mainOut['streamSettings'] ??= <String, dynamic>{};
        mainOut['streamSettings']['sockopt'] = {
          'dialerProxy': 'fragment',
          'tcpNoDelay': true,
        };
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
      return jsonEncode(config);
    } catch (_) {
      return rawJson;
    }
  }

  // تابع اتصال مستقیم و تضمینی به سرور انتخاب‌شده توسط کاربر
  Future<void> connectToSelectedServer() async {
    if (servers.isEmpty) {
      _showAddConfigDialog();
      return;
    }

    if (selectedIndex < 0 || selectedIndex >= servers.length) {
      selectedIndex = 0;
    }

    final ServerItem target = servers[selectedIndex];

    setState(() => isConnecting = true);

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && isConnecting && v2rayStatus.state != 'CONNECTED') {
        setState(() => isConnecting = false);
      }
    });

    try {
      if (!isInitialized) {
        await flutterV2ray.initializeV2Ray();
        isInitialized = true;
      }

      final bool hasPermission = await flutterV2ray.requestPermission();
      if (!hasPermission) {
        _watchdogTimer?.cancel();
        if (mounted) setState(() => isConnecting = false);
        _notify('مجوز ساخت VPN در گوشی تایید نشد.');
        return;
      }

      final String finalConfig = _buildWorkingConfig(target.uri);

      await flutterV2ray.startV2Ray(
        remark: target.remark,
        config: finalConfig,
        bypassSubnets: connectionMode == 1 ? privateLanSubnets : null,
      );
    } catch (e) {
      _watchdogTimer?.cancel();
      if (mounted) setState(() => isConnecting = false);
      _notify('خطا در اتصال به "${target.remark}". کانفیگ دیگری را انتخاب کنید.');
    }
  }

  Future<void> toggleConnection() async {
    HapticFeedback.mediumImpact();
    if (v2rayStatus.state == 'CONNECTED' || isConnecting) {
      _watchdogTimer?.cancel();
      setState(() => isConnecting = false);
      await flutterV2ray.stopV2Ray();
      return;
    }
    await connectToSelectedServer();
  }

  // انتخاب دستی سرور توسط کاربر (و سوییچ خودکار اگر در حال حاضر وصل باشد)
  Future<void> selectServerManually(int index) async {
    if (index < 0 || index >= servers.length) return;
    HapticFeedback.selectionClick();

    final bool wasConnected = v2rayStatus.state == 'CONNECTED';
    setState(() => selectedIndex = index);
    await _saveData();

    if (wasConnected) {
      _notify('در حال تغییر سرور به ${servers[index].remark}...');
      await flutterV2ray.stopV2Ray();
      await Future.delayed(const Duration(milliseconds: 500));
      await connectToSelectedServer();
    } else {
      _notify('سرور "${servers[index].remark}" انتخاب شد. دکمه وسط را برای اتصال بزنید.');
    }
  }

  // استخراج Host و Port برای پینگ سریع و تضمینی
  Map<String, dynamic>? _extractHostPort(String uriStr) {
    try {
      if (uriStr.startsWith('vmess://')) {
        final decoded = _robustBase64Decode(uriStr.substring(8));
        final map = jsonDecode(decoded);
        return {
          'host': map['add']?.toString() ?? '',
          'port': int.tryParse(map['port'].toString()) ?? 443,
        };
      } else if (!uriStr.startsWith('{')) {
        final hashIdx = uriStr.indexOf('#');
        final clean = hashIdx != -1 ? uriStr.substring(0, hashIdx) : uriStr;
        final u = Uri.parse(clean);
        return {
          'host': u.host,
          'port': u.port > 0 ? u.port : 443,
        };
      }
    } catch (_) {}
    return null;
  }

  // تست پینگ ترکیبی (اول هسته Xray، و اگر جواب نداد سوکت مستقیم) بدون تغییر دادن سرور انتخابی کاربر!
  Future<void> pingSingleServer(ServerItem item) async {
    if (!mounted) return;
    setState(() => item.testing = true);

    int delay = -2;

    try {
      final cfg = _buildWorkingConfig(item.uri);
      delay = await flutterV2ray
          .getServerDelay(config: cfg)
          .timeout(const Duration(milliseconds: 3000), onTimeout: () => -1);
    } catch (_) {
      delay = -1;
    }

    if (delay <= 0) {
      try {
        final hp = _extractHostPort(item.uri);
        if (hp != null && hp['host'].toString().isNotEmpty) {
          final sw = Stopwatch()..start();
          final sock = await Socket.connect(
            hp['host'],
            hp['port'],
            timeout: const Duration(milliseconds: 2000),
          );
          sw.stop();
          await sock.close();
          delay = sw.elapsedMilliseconds;
        }
      } catch (_) {
        delay = -2;
      }
    }

    if (!mounted) return;
    setState(() {
      item.ping = delay > 0 ? delay : -2;
      item.testing = false;
    });
  }

  Future<void> pingAllServers({bool sortAfter = false}) async {
    if (servers.isEmpty || isTestingPings) return;
    HapticFeedback.lightImpact();

    final String currentlySelectedId =
        (selectedIndex >= 0 && selectedIndex < servers.length) ? servers[selectedIndex].id : '';

    setState(() => isTestingPings = true);

    final snapshot = List<ServerItem>.from(servers);
    const int batch = 5;
    for (int i = 0; i < snapshot.length; i += batch) {
      final end = (i + batch < snapshot.length) ? i + batch : snapshot.length;
      await Future.wait([for (int j = i; j < end; j++) pingSingleServer(snapshot[j])]);
    }

    if (!mounted) return;
    setState(() {
      if (sortAfter) {
        servers.sort((a, b) {
          if (a.ping <= 0 && b.ping <= 0) return 0;
          if (a.ping <= 0) return 1;
          if (b.ping <= 0) return -1;
          return a.ping.compareTo(b.ping);
        });
      }
      // حفظ ۱۰۰ درصدی سروری که کاربر دستی انتخاب کرده بود
      if (currentlySelectedId.isNotEmpty) {
        final newIdx = servers.indexWhere((s) => s.id == currentlySelectedId);
        if (newIdx != -1) selectedIndex = newIdx;
      }
      isTestingPings = false;
    });
    _saveData();
  }

  String _robustBase64Decode(String input) {
    String clean = input.replaceAll(RegExp(r'\s+'), '');
    clean = clean.replaceAll('-', '+').replaceAll('_', '/');
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    return utf8.decode(base64.decode(clean), allowMalformed: true);
  }

  // پنجره افزودن کانفیگ (هم از کلیپ‌بورد و هم تایپ/پیست دستی)
  void _showAddConfigDialog() {
    final TextEditingController textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101526),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          title: const Text(
            'افزودن کانفیگ یا لینک اشتراک',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'لینک vless / vmess / trojan یا لینک اشتراک (http) را در کادر زیر قرار دهید:',
                style: TextStyle(fontSize: 11.5, color: Colors.white60),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'vless://... یا https://...',
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
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
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      textCtrl.text = data!.text!.trim();
                    }
                  },
                  icon: const Icon(Icons.content_paste_rounded, size: 17, color: Color(0xFFA87FFB)),
                  label: const Text(
                    'چسباندن خودکار از کلیپ‌بورد',
                    style: TextStyle(fontSize: 12, color: Color(0xFFA87FFB)),
                  ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B90FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final input = textCtrl.text.trim();
                Navigator.pop(ctx);
                if (input.isNotEmpty) {
                  await _processInputText(input);
                } else {
                  await _importFromClipboardDirect();
                }
              },
              child: const Text('افزودن به لیست', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importFromClipboardDirect() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      _notify('کلیپ‌بورد خالی است!');
      return;
    }
    await _processInputText(data.text!.trim());
  }

  Future<void> _processInputText(String text) async {
    if (text.startsWith('http://') || text.startsWith('https://')) {
      _notify('در حال دریافت سرورها از لینک اشتراک...');
      await _fetchSub(text);
    } else {
      _addRawLinks(text, replace: false);
    }
  }

  Future<void> _fetchSub(String url) async {
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'v2rayNG/1.8.19'},
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        String body = res.body.trim();
        if (!body.contains('://')) {
          try {
            body = _robustBase64Decode(body);
          } catch (_) {}
        }

        final added = _addRawLinks(body, replace: true);
        if (added > 0) {
          savedSubUrl = url;
          usedGB = 0.0;
          totalGB = 0.0;
          expireTimestamp = null;

          final info = res.headers['subscription-userinfo'];
          if (info != null) _parseUserInfo(info);

          subName = Uri.parse(url).host;
          _saveData();
        }
      } else {
        _notify('خطا در دریافت اشتراک (کد ${res.statusCode})');
      }
    } catch (_) {
      _notify('عدم دسترسی به لینک اشتراک. اینترنت را بررسی کنید.');
    }
  }

  void _parseUserInfo(String header) {
    try {
      int up = 0, down = 0, total = 0;
      int? exp;
      for (var part in header.split(';')) {
        final kv = part.trim().split('=');
        if (kv.length == 2) {
          final key = kv[0].trim().toLowerCase();
          final v = int.tryParse(kv[1].trim()) ?? 0;
          if (key == 'upload') up = v;
          if (key == 'download') down = v;
          if (key == 'total') total = v;
          if (key == 'expire') exp = v;
        }
      }
      setState(() {
        usedGB = double.parse(((up + down) / 1073741824).toStringAsFixed(2));
        totalGB = double.parse((total / 1073741824).toStringAsFixed(2));
        expireTimestamp = exp;
      });
    } catch (_) {}
  }

  String _getProto(String link) {
    final l = link.toLowerCase();
    if (l.startsWith('vless://')) return 'VLESS';
    if (l.startsWith('vmess://')) return 'VMess';
    if (l.startsWith('trojan://')) return 'Trojan';
    if (l.startsWith('ss://')) return 'Shadowsocks';
    return 'Xray';
  }

  int _addRawLinks(String raw, {required bool replace}) {
    final lines = raw.split(RegExp(r'[\r\n]+'));
    final List<ServerItem> parsedList = [];

    for (var l in lines) {
      final link = l.trim();
      if (link.startsWith('vless://') ||
          link.startsWith('vmess://') ||
          link.startsWith('trojan://') ||
          link.startsWith('ss://')) {
        try {
          final p = FlutterV2ray.parseFromURL(link);
          parsedList.add(ServerItem(
            id: '${DateTime.now().microsecondsSinceEpoch}_${parsedList.length}',
            remark: p.remark.isNotEmpty
                ? p.remark
                : 'سرور ${servers.length + parsedList.length + 1}',
            uri: link,
            protocol: _getProto(link),
          ));
        } catch (_) {}
      }
    }

    if (parsedList.isEmpty) {
      _notify('لینک کانفیگ معتبری پیدا نشد.');
      return 0;
    }

    setState(() {
      if (replace) {
        servers = parsedList;
        selectedIndex = 0;
      } else {
        servers.insertAll(0, parsedList);
        selectedIndex = 0;
      }
    });
    _saveData();
    _notify('✅ ${parsedList.length} سرور اضافه و انتخاب شد!');
    pingAllServers(sortAfter: false);
    return parsedList.length;
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

  String _formatSpeed(dynamic speed) {
    final int bytes = int.tryParse(speed.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / 1048576).toStringAsFixed(2)} MB/s';
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF161B30),
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
    final ServerItem? activeServer =
        (servers.isNotEmpty && selectedIndex < servers.length) ? servers[selectedIndex] : null;

    return Scaffold(
      body: Stack(
        children: [
          // ۱. هاله‌های نوری Gemini در پس‌زمینه
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isConnected ? const Color(0xFF00F5D4) : const Color(0xFF4B90FF))
                        .withOpacity(0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
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

          // ۲. چیدمان اصلی: بالا دکمه اتصال و وضعیت، پایین لیست مستقیم و قابل انتخاب سرورها
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 10),
                      _buildModeSelector(),
                      const SizedBox(height: 14),
                      _buildGeminiOrbSection(isConnected, activeServer),
                      const SizedBox(height: 12),
                      _buildTelemetryBar(isConnected),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // ۳. لیست مستقیم سرورها روی صفحه اصلی برای انتخاب دستی راحت
                Expanded(
                  child: _buildDirectServerList(isConnected),
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4B90FF).withOpacity(0.3),
                    const Color(0xFFA87FFB).withOpacity(0.3),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFA87FFB), size: 19),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFFC7D2FE), Color(0xFFF472B6)],
              ).createShader(bounds),
              child: const Text(
                'Lantern',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (savedSubUrl.isNotEmpty) ...[
              _buildCircleBtn(
                icon: Icons.sync_rounded,
                tooltip: 'آپدیت اشتراک',
                onTap: () => _fetchSub(savedSubUrl),
              ),
              const SizedBox(width: 8),
            ],
            _buildCircleBtn(
              icon: isTestingPings ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
              color: const Color(0xFFA87FFB),
              tooltip: 'تست پینگ همه',
              onTap: () => pingAllServers(sortAfter: false),
            ),
            const SizedBox(width: 8),
            _buildCircleBtn(
              icon: Icons.content_paste_go_rounded,
              color: const Color(0xFF00F5D4),
              tooltip: 'افزودن فوری از کلیپ‌بورد',
              onTap: _importFromClipboardDirect,
            ),
            const SizedBox(width: 8),
            _buildCircleBtn(
              icon: Icons.add_rounded,
              color: const Color(0xFF4B90FF),
              tooltip: 'افزودن دستی کانفیگ',
              onTap: _showAddConfigDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleBtn({
    required IconData icon,
    required String tooltip,
    Color color = Colors.white70,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.07),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    final modes = ['استاندارد (پایدار)', 'بدون شبکه محلی', 'ضد فیلتر (Fragment)'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.11)),
      ),
      child: Row(
        children: List.generate(modes.length, (i) {
          final active = connectionMode == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => connectionMode = i);
                _saveData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  modes[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : Colors.white54,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGeminiOrbSection(bool isConnected, ServerItem? activeServer) {
    return Column(
      children: [
        GestureDetector(
          onTap: toggleConnection,
          child: SizedBox(
            width: 146,
            height: 146,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _auraController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _auraController.value * 2 * math.pi,
                      child: Container(
                        width: 138,
                        height: 138,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: isConnected
                                ? const [
                                    Color(0xFF00F5D4),
                                    Color(0xFF3B82F6),
                                    Color(0xFFA87FFB),
                                    Color(0xFF00F5D4),
                                  ]
                                : const [
                                    Color(0xFF4B90FF),
                                    Color(0xFFA87FFB),
                                    Color(0xFFFF6B9D),
                                    Color(0xFF4B90FF),
                                  ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isConnected
                                      ? const Color(0xFF00F5D4)
                                      : const Color(0xFFA87FFB))
                                  .withOpacity(isConnected ? 0.45 : 0.25),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      radius: 1.1,
                      colors: [
                        Color(0xFF28314E),
                        Color(0xFF0E1324),
                        Color(0xFF070912),
                      ],
                    ),
                    border: Border.all(
                      color: isConnected
                          ? const Color(0xFF00F5D4).withOpacity(0.8)
                          : Colors.white.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isConnecting)
                        const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFA87FFB),
                          ),
                        )
                      else
                        Icon(
                          Icons.power_settings_new_rounded,
                          size: 42,
                          color: isConnected ? const Color(0xFF00F5D4) : Colors.white,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        isConnecting
                            ? 'CONNECTING'
                            : (isConnected ? 'CONNECTED' : 'CONNECT'),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isConnected ? const Color(0xFF00F5D4) : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isConnecting
              ? 'در حال اتصال به سرور...'
              : (isConnected
                  ? 'متصل به: ${activeServer?.remark ?? "سرور"}'
                  : (activeServer != null
                      ? 'سرور انتخابی: ${activeServer.remark}'
                      : 'هیچ سروری اضافه نشده است')),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isConnected ? const Color(0xFF00F5D4) : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryBar(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.south_west_rounded, size: 14, color: Color(0xFF00F5D4)),
              const SizedBox(width: 5),
              Text(
                isConnected ? _formatSpeed(v2rayStatus.downloadSpeed) : '0.0 KB/s',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF00F5D4)),
              ),
            ],
          ),
          Container(width: 1, height: 18, color: Colors.white12),
          Row(
            children: [
              const Icon(Icons.north_east_rounded, size: 14, color: Color(0xFFA87FFB)),
              const SizedBox(width: 5),
              Text(
                isConnected ? _formatSpeed(v2rayStatus.uploadSpeed) : '0.0 KB/s',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFA87FFB)),
              ),
            ],
          ),
          Container(width: 1, height: 18, color: Colors.white12),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: Colors.white60),
              const SizedBox(width: 5),
              Text(
                isConnected ? v2rayStatus.duration : '00:00:00',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // لیست مستقیم و همیشه باز سرورها روی صفحه اصلی برای انتخاب دستی ۱۰۰٪ راحت
  Widget _buildDirectServerList(bool isConnected) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E1A).withOpacity(0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'لیست سرورها (${servers.length}) — روی سرور دلخواه بزنید:',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.white70),
                ),
                Row(
                  children: [
                    if (servers.length > 1)
                      GestureDetector(
                        onTap: () => pingAllServers(sortAfter: true),
                        child: const Text(
                          'مرتب‌سازی پینگ',
                          style: TextStyle(fontSize: 11, color: Color(0xFFA87FFB), fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (servers.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            servers.clear();
                            selectedIndex = 0;
                          });
                          _saveData();
                        },
                        child: const Text(
                          'حذف همه',
                          style: TextStyle(fontSize: 11, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: servers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_link_rounded, size: 42, color: Colors.white24),
                          const SizedBox(height: 10),
                          const Text(
                            'هنوز هیچ کانفیگی اضافه نکرده‌اید.',
                            style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4B90FF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _importFromClipboardDirect,
                            icon: const Icon(Icons.content_paste_rounded, size: 18),
                            label: const Text('چسباندن کانفیگ یا اشتراک از کلیپ‌بورد'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: servers.length,
                    itemBuilder: (context, index) {
                      final s = servers[index];
                      final bool isSelected = index == selectedIndex;

                      Color pColor = const Color(0xFF00F5D4);
                      if (s.ping > 280) pColor = const Color(0xFFFBBF24);
                      if (s.ping <= 0 || s.ping > 650) pColor = const Color(0xFFF43F5E);

                      return GestureDetector(
                        onTap: () => selectServerManually(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 9),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      const Color(0xFF4B90FF).withOpacity(0.28),
                                      const Color(0xFFA87FFB).withOpacity(0.20),
                                    ],
                                  )
                                : null,
                            color: isSelected ? null : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? (isConnected ? const Color(0xFF00F5D4) : const Color(0xFFA87FFB))
                                  : Colors.white.withOpacity(0.07),
                              width: isSelected ? 1.6 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // دکمه رادیویی واضح برای نشان دادن سرور انتخاب‌شده
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isSelected
                                    ? (isConnected ? const Color(0xFF00F5D4) : const Color(0xFFA87FFB))
                                    : Colors.white30,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(_detectFlag(s.remark), style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.remark,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        fontSize: 13,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            s.protocol,
                                            style: const TextStyle(fontSize: 9.5, color: Color(0xFFA87FFB)),
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            isConnected ? '● متصل' : '✓ انتخاب شده',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isConnected
                                                  ? const Color(0xFF00F5D4)
                                                  : const Color(0xFFA87FFB),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // دکمه تست پینگ تکی
                              GestureDetector(
                                onTap: () => pingSingleServer(s),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: s.testing
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFA87FFB),
                                          ),
                                        )
                                      : Text(
                                          s.ping > 0
                                              ? '${s.ping} ms'
                                              : (s.ping == -2 ? 'Timeout' : 'تست پینگ'),
                                          style: TextStyle(
                                            color: s.ping > 0 ? pColor : Colors.white54,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    servers.removeAt(index);
                                    if (selectedIndex >= servers.length) {
                                      selectedIndex = math.max(0, servers.length - 1);
                                    }
                                  });
                                  _saveData();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.close_rounded, size: 18, color: Colors.white30),
                                ),
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
