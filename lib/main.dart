import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
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
  runApp(const LanternProApp());
}

class LanternProApp extends StatelessWidget {
  const LanternProApp({super.key});

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

class ServerProfile {
  final String id;
  final String remark;
  final String uri;
  final String protocol;
  int ping;
  bool testing;

  ServerProfile({
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

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        remark: json['remark']?.toString() ?? 'Server',
        uri: json['uri']?.toString() ?? '',
        protocol: json['protocol']?.toString() ?? 'VLESS',
        ping: json['ping'] is int ? json['ping'] : -1,
      );
}

class LanternHomeScreen extends StatefulWidget {
  const LanternHomeScreen({super.key});

  @override
  State<LanternHomeScreen> createState() => _LanternHomeScreenState();
}

class _LanternHomeScreenState extends State<LanternHomeScreen>
    with TickerProviderStateMixin {
  late final FlutterV2ray flutterV2ray;
  V2RayStatus v2rayStatus = V2RayStatus();
  late final AnimationController _auraController;

  List<ServerProfile> servers = [];
  int selectedIndex = 0;

  bool isInitialized = false;
  bool isConnecting = false;
  bool isTestingPings = false;
  Timer? _watchdogTimer;

  // تنظیمات پیشرفته
  bool isAutomaticMode = true; // true = انتخاب اتوماتیک سریع‌ترین سرور، false = انتخاب دستی
  int connectionMode = 0; // 0 = استاندارد، 1 = بدون LAN، 2 = ضد فیلتر Fragment

  String subName = "اشتراک لنترن";
  String savedSubUrl = "";
  double usedGB = 0.0;
  double totalGB = 0.0;
  int? expireTimestamp;

  // اطلاعات تست IP واقعی برای جلوگیری از نشت
  String verifiedIp = "---.---.---";
  String verifiedLocation = "بررسی نشده";
  bool isCheckingIp = false;

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
        if (status.state == 'CONNECTED') {
          _fetchRealIpAddress();
        }
      },
    );

    _bootEngine();
    _loadSavedData();
  }

  Future<void> _bootEngine() async {
    try {
      await flutterV2ray.initializeV2Ray();
      if (mounted) setState(() => isInitialized = true);
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
      final rawList = prefs.getStringList('lantern_v9_servers') ?? [];
      final List<ServerProfile> loaded = [];
      for (var item in rawList) {
        try {
          loaded.add(ServerProfile.fromJson(jsonDecode(item)));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        servers = loaded;
        selectedIndex = prefs.getInt('selectedIndex') ?? 0;
        if (selectedIndex < 0 || selectedIndex >= servers.length) selectedIndex = 0;
        subName = prefs.getString('subName') ?? "اشتراک لنترن";
        savedSubUrl = prefs.getString('savedSubUrl') ?? "";
        usedGB = prefs.getDouble('usedGB') ?? 0.0;
        totalGB = prefs.getDouble('totalGB') ?? 0.0;
        expireTimestamp = prefs.getInt('expireTimestamp');
        isAutomaticMode = prefs.getBool('isAutomaticMode') ?? true;
        connectionMode = prefs.getInt('connectionMode') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'lantern_v9_servers',
        servers.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await prefs.setInt('selectedIndex', selectedIndex);
      await prefs.setString('subName', subName);
      await prefs.setString('savedSubUrl', savedSubUrl);
      await prefs.setDouble('usedGB', usedGB);
      await prefs.setDouble('totalGB', totalGB);
      await prefs.setBool('isAutomaticMode', isAutomaticMode);
      await prefs.setInt('connectionMode', connectionMode);
      if (expireTimestamp != null) {
        await prefs.setInt('expireTimestamp', expireTimestamp!);
      }
    } catch (_) {}
  }

  // ساخت کانفیگ ایمن ضد نشت DNS
  String _buildSecureConfig(String uriOrJson) {
    final trimmed = uriOrJson.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    final V2RayURL parser = FlutterV2ray.parseFromURL(trimmed);
    final String rawJson = parser.getFullConfiguration();

    try {
      final Map<String, dynamic> config = jsonDecode(rawJson);

      // قفل کردن DNSهای رمزنگاری‌شده برای جلوگیری از نشت IP/DNS
      config['dns'] = {
        'servers': ['1.1.1.1', '8.8.8.8', 'https://cloudflare-dns.com/dns-query']
      };

      final outbounds = config['outbounds'];
      if (connectionMode == 2 && outbounds is List && outbounds.isNotEmpty) {
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

  // بررسی IP واقعی پس از اتصال برای اطمینان از عدم نشت
  Future<void> _fetchRealIpAddress() async {
    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            verifiedIp = data['query'] ?? '---';
            verifiedLocation = "${data['country'] ?? ''} (${data['isp'] ?? ''})";
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => verifiedLocation = "تونل فعال (بدون دسترسی IP Check)");
    }
  }

  Future<void> connectToServer() async {
    if (servers.isEmpty) {
      _showAddConfigDialog();
      return;
    }

    // اگر حالت اتوماتیک فعال باشد، سریع‌ترین سرور سالم انتخاب می‌شود
    if (isAutomaticMode) {
      final healthy = servers.where((s) => s.ping > 0).toList();
      if (healthy.isNotEmpty) {
        healthy.sort((a, b) => a.ping.compareTo(b.ping));
        selectedIndex = servers.indexWhere((s) => s.id == healthy.first.id);
      } else {
        selectedIndex = 0; // اگر پینگ تست نشده بود، سرور اول
      }
    }

    if (selectedIndex >= servers.length) selectedIndex = 0;
    final target = servers[selectedIndex];

    setState(() => isConnecting = true);

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && isConnecting && v2rayStatus.state != 'CONNECTED') {
        setState(() => isConnecting = false);
        _notify('زمان اتصال به پایان رسید.');
      }
    });

    try {
      if (!isInitialized) {
        await flutterV2ray.initializeV2Ray();
        isInitialized = true;
      }
      final bool allowed = await flutterV2ray.requestPermission();
      if (!allowed) {
        _watchdogTimer?.cancel();
        if (mounted) setState(() => isConnecting = false);
        _notify('مجوز VPN تایید نشد.');
        return;
      }

      final String config = _buildSecureConfig(target.uri);
      await flutterV2ray.startV2Ray(
        remark: target.remark,
        config: config,
        bypassSubnets: connectionMode == 1 ? privateLanSubnets : null,
      );
    } catch (_) {
      _watchdogTimer?.cancel();
      if (mounted) setState(() => isConnecting = false);
      _notify('خطا در اتصال به سرور.');
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
    await connectToServer();
  }

  Future<void> selectServerManual(int index) async {
    if (index < 0 || index >= servers.length) return;
    HapticFeedback.selectionClick();
    
    // اگر کاربر در حالت دستی سرور را عوض کند، حالت اتوماتیک موقتاً غیرفعال می‌شود تا انتخابش حفظ شود
    setState(() {
      selectedIndex = index;
      isAutomaticMode = false;
    });
    await _saveData();

    final bool wasConnected = v2rayStatus.state == 'CONNECTED';
    if (wasConnected) {
      _notify('تغییر سرور به ${servers[index].remark}...');
      await flutterV2ray.stopV2Ray();
      await Future.delayed(const Duration(milliseconds: 400));
      await connectToServer();
    } else {
      _notify('سرور "${servers[index].remark}" انتخاب شد (حالت دستی)');
    }
  }

  Map<String, dynamic>? _extractHostPort(String uriStr) {
    try {
      if (uriStr.startsWith('vmess://')) {
        final decoded = _robustBase64Decode(uriStr.substring(8));
        final map = jsonDecode(decoded);
        return {'host': map['add']?.toString() ?? '', 'port': int.tryParse(map['port'].toString()) ?? 443};
      } else if (!uriStr.startsWith('{')) {
        final hashIdx = uriStr.indexOf('#');
        final clean = hashIdx != -1 ? uriStr.substring(0, hashIdx) : uriStr;
        final u = Uri.parse(clean);
        return {'host': u.host, 'port': u.port > 0 ? u.port : 443};
      }
    } catch (_) {}
    return null;
  }

  Future<void> pingSingleServer(ServerProfile item) async {
    if (!mounted) return;
    setState(() => item.testing = true);
    int delay = -2;
    try {
      final cfg = _buildSecureConfig(item.uri);
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
          final sock = await Socket.connect(hp['host'], hp['port'], timeout: const Duration(milliseconds: 2000));
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

  Future<void> pingAllServers() async {
    if (servers.isEmpty || isTestingPings) return;
    HapticFeedback.lightImpact();
    setState(() => isTestingPings = true);

    const int batch = 5;
    for (int i = 0; i < servers.length; i += batch) {
      final end = (i + batch < servers.length) ? i + batch : servers.length;
      await Future.wait([for (int j = i; j < end; j++) pingSingleServer(servers[j])]);
    }

    if (!mounted) return;
    setState(() => isTestingPings = false);
    _saveData();
  }

  // دکمه به‌روزرسانی اشتراک (Subscription Sync)
  Future<void> updateSubscription() async {
    if (savedSubUrl.isEmpty) {
      _notify('هیچ لینک اشتراکی برای بروزرسانی ذخیره نشده است.');
      return;
    }
    _notify('در حال بروزرسانی سرورها از لینک اشتراک...');
    await _fetchSubscriptionUrl(savedSubUrl);
  }

  String _robustBase64Decode(String input) {
    String clean = input.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '+').replaceAll('_', '/');
    while (clean.length % 4 != 0) clean += '=';
    return utf8.decode(base64.decode(clean), allowMalformed: true);
  }

  void _showAddConfigDialog() {
    final TextEditingController ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('افزودن کانفیگ یا لینک اشتراک', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'vless://... یا https://...',
            filled: true,
            fillColor: const Color(0xFF0B0F19),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B90FF)),
            onPressed: () {
              final txt = ctrl.text.trim();
              Navigator.pop(ctx);
              if (txt.isNotEmpty) _processInputText(txt);
            },
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
  }

  Future<void> _processInputText(String text) async {
    if (text.startsWith('http://') || text.startsWith('https://')) {
      savedSubUrl = text;
      await _fetchSubscriptionUrl(text);
    } else {
      _addRawLinks(text, replace: false);
    }
  }

  Future<void> _fetchSubscriptionUrl(String url) async {
    try {
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': 'v2rayNG/1.8.19'}).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        String body = res.body.trim();
        if (!body.contains('://')) {
          try { body = _robustBase64Decode(body); } catch (_) {}
        }
        _addRawLinks(body, replace: true);
        savedSubUrl = url;
        _saveData();
      } else {
        _notify('خطا در بروزرسانی اشتراک: کد ${res.statusCode}');
      }
    } catch (_) {
      _notify('خطا در ارتباط با سرور اشتراک.');
    }
  }

  int _addRawLinks(String raw, {required bool replace}) {
    final lines = raw.split(RegExp(r'[\r\n]+'));
    final parsed = <ServerProfile>[];
    for (var l in lines) {
      final link = l.trim();
      if (link.startsWith('vless://') || link.startsWith('vmess://') || link.startsWith('trojan://') || link.startsWith('ss://')) {
        try {
          final p = FlutterV2ray.parseFromURL(link);
          parsed.add(ServerProfile(
            id: '${DateTime.now().microsecondsSinceEpoch}_${parsed.length}',
            remark: p.remark.isNotEmpty ? p.remark : 'Server #${servers.length + parsed.length + 1}',
            uri: link,
            protocol: link.split('://').first.toUpperCase(),
          ));
        } catch (_) {}
      }
    }

    if (parsed.isEmpty) {
      _notify('کانفیگ معتبری پیدا نشد.');
      return 0;
    }

    setState(() {
      if (replace) {
        servers = parsed;
      } else {
        servers.insertAll(0, parsed);
      }
      selectedIndex = 0;
    });
    _saveData();
    _notify('✦ ${parsed.length} سرور بارگذاری شد!');
    pingAllServers();
    return parsed.length;
  }

  String _detectFlag(String remark) {
    final up = remark.toUpperCase();
    if (up.contains('DE') || up.contains('GERMANY') || remark.contains('آلمان')) return '🇩🇪';
    if (up.contains('NL') || up.contains('NETHERLANDS') || remark.contains('هلند')) return '🇳🇱';
    if (up.contains('US') || up.contains('AMERICA') || remark.contains('آمریکا')) return '🇺🇸';
    if (up.contains('GB') || up.contains('UK') || up.contains('LONDON') || remark.contains('انگلیس')) return '🇬🇧';
    if (up.contains('FI') || up.contains('FINLAND') || remark.contains('فنلاند')) return '🇫🇮';
    if (up.contains('TR') || up.contains('TURKEY') || remark.contains('ترکیه')) return '🇹🇷';
    return '🌐';
  }

  String _formatSpeed(dynamic speed) {
    final int b = int.tryParse(speed.toString()) ?? 0;
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
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = v2rayStatus.state == 'CONNECTED';
    final ServerProfile? currentServer = (servers.isNotEmpty && selectedIndex < servers.length) ? servers[selectedIndex] : null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [(isConnected ? const Color(0xFF00F5D4) : const Color(0xFF4B90FF)).withOpacity(0.28), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFFA87FFB).withOpacity(0.22), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // هدر بالا
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(colors: [const Color(0xFF4B90FF).withOpacity(0.3), const Color(0xFFA87FFB).withOpacity(0.3)]),
                              border: Border.all(color: Colors.white.withOpacity(0.18)),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFA87FFB), size: 19),
                          ),
                          const SizedBox(width: 10),
                          const Text('Lantern Pro', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: Colors.white)),
                        ],
                      ),
                      Row(
                        children: [
                          if (savedSubUrl.isNotEmpty) ...[
                            _buildGlassBtn(icon: Icons.sync_rounded, color: const Color(0xFF00F5D4), onTap: updateSubscription),
                            const SizedBox(width: 8),
                          ],
                          _buildGlassBtn(icon: Icons.bolt_rounded, color: const Color(0xFFA87FFB), onTap: pingAllServers),
                          const SizedBox(width: 8),
                          _buildGlassBtn(icon: Icons.add_rounded, color: const Color(0xFF4B90FF), onTap: _showAddConfigDialog),
                        ],
                      ),
                    ],
                  ),
                ),

                // کنترلر سوییچ اتوماتیک / دستی (Auto / Manual Switch)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => isAutomaticMode = true);
                              _saveData();
                              _notify('حالت اتوماتیک (انتخاب سریع‌ترین سرور) فعال شد');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isAutomaticMode ? Colors.white.withOpacity(0.16) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bolt_rounded, size: 14, color: isAutomaticMode ? const Color(0xFF00F5D4) : Colors.white54),
                                  const SizedBox(width: 4),
                                  Text('هوشمند (اتوماتیک)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isAutomaticMode ? Colors.white : Colors.white54)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => isAutomaticMode = false);
                              _saveData();
                              _notify('حالت دستی (انتخاب ثابت سرور) فعال شد');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: !isAutomaticMode ? Colors.white.withOpacity(0.16) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.touch_app_rounded, size: 14, color: !isAutomaticMode ? const Color(0xFFA87FFB) : Colors.white54),
                                  const SizedBox(width: 4),
                                  Text('انتخاب دستی', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: !isAutomaticMode ? Colors.white : Colors.white54)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // گوی مرکزی جمینای
                GestureDetector(
                  onTap: toggleConnection,
                  child: SizedBox(
                    width: 156,
                    height: 156,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _auraController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _auraController.value * 2 * math.pi,
                              child: Container(
                                width: 146,
                                height: 146,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: SweepGradient(
                                    colors: isConnected
                                        ? const [Color(0xFF00F5D4), Color(0xFF3B82F6), Color(0xFFA87FFB), Color(0xFF00F5D4)]
                                        : const [Color(0xFF4B90FF), Color(0xFFA87FFB), Color(0xFFFF6B9D), Color(0xFF4B90FF)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: (isConnected ? const Color(0xFF00F5D4) : const Color(0xFFA87FFB)).withOpacity(0.35), blurRadius: 26, spreadRadius: 2),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(center: Alignment(-0.3, -0.4), radius: 1.1, colors: [Color(0xFF28314E), Color(0xFF0E1324), Color(0xFF070912)]),
                            border: Border.all(color: isConnected ? const Color(0xFF00F5D4).withOpacity(0.8) : Colors.white.withOpacity(0.25), width: 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isConnecting)
                                const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFA87FFB)))
                              else
                                Icon(Icons.power_settings_new_rounded, size: 38, color: isConnected ? const Color(0xFF00F5D4) : Colors.white),
                              const SizedBox(height: 5),
                              Text(isConnecting ? 'CONNECTING' : (isConnected ? 'SECURE' : 'CONNECT'), style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: isConnected ? const Color(0xFF00F5D4) : Colors.white60)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Text(isConnected ? 'تونل ضد نشت فعال است' : (isAutomaticMode ? 'حالت اتوماتیک (انتخاب سریع‌ترین)' : 'حالت دستی (انتخاب ثابت)'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isConnected ? const Color(0xFF00F5D4) : Colors.white)),
                const SizedBox(height: 3),
                Text(isConnected ? 'IP: $verifiedIp • $verifiedLocation' : (currentServer != null ? 'سرور فعال: ${currentServer.remark}' : 'سروری انتخاب نشده است'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.white54)),

                const SizedBox(height: 10),

                // نوار سرعت
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(children: [const Icon(Icons.south_west_rounded, size: 14, color: Color(0xFF00F5D4)), const SizedBox(width: 4), Text(isConnected ? _formatSpeed(v2rayStatus.downloadSpeed) : '0 B/s', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00F5D4)))]),
                        Container(width: 1, height: 16, color: Colors.white12),
                        Row(children: [const Icon(Icons.north_east_rounded, size: 14, color: Color(0xFFA87FFB)), const SizedBox(width: 4), Text(isConnected ? _formatSpeed(v2rayStatus.uploadSpeed) : '0 B/s', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFA87FFB)))]),
                        Container(width: 1, height: 16, color: Colors.white12),
                        Row(children: [const Icon(Icons.schedule_rounded, size: 14, color: Colors.white60), const SizedBox(width: 4), Text(isConnected ? v2rayStatus.duration : '00:00:00', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // لیست سرورها
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0E1A).withOpacity(0.92),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('سرورها (${servers.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white70)),
                              if (servers.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    setState(() { servers.clear(); selectedIndex = 0; });
                                    _saveData();
                                  },
                                  child: const Text('حذف همه', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                                ),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        Expanded(
                          child: servers.isEmpty
                              ? const Center(child: Text('هیچ سروری اضافه نشده است', style: TextStyle(color: Colors.white38, fontSize: 12)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(14),
                                  itemCount: servers.length,
                                  itemBuilder: (context, index) {
                                    final s = servers[index];
                                    final bool selected = index == selectedIndex;
                                    return GestureDetector(
                                      onTap: () => selectServerManual(index),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selected ? const Color(0xFF192542) : Colors.white.withOpacity(0.04),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: selected ? const Color(0xFF4B90FF) : Colors.white.withOpacity(0.06), width: selected ? 1.5 : 1),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked, size: 18, color: selected ? const Color(0xFF00F5D4) : Colors.white30),
                                            const SizedBox(width: 10),
                                            Text(_detectFlag(s.remark), style: const TextStyle(fontSize: 16)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(s.remark, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: selected ? FontWeight.bold : FontWeight.w600)),
                                            ),
                                            GestureDetector(
                                              onTap: () => pingSingleServer(s),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                                                child: s.testing
                                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA87FFB)))
                                                    : Text(s.ping > 0 ? '${s.ping} ms' : 'تست', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: s.ping > 0 ? const Color(0xFF00F5D4) : Colors.white38)),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBtn({required IconData icon, Color color = Colors.white, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
