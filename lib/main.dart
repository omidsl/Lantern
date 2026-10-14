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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF060913),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LanternUltraApp());
}

class LanternUltraApp extends StatelessWidget {
  const LanternUltraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern Ultra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060913),
        primaryColor: const Color(0xFF0055FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0055FF),
          secondary: Color(0xFF00F0FF),
          surface: Color(0xFF0F1629),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class ServerNode {
  final String remark;
  final String uri;
  final String protocol;
  int ping;
  bool isTesting;

  ServerNode({
    required this.remark,
    required this.uri,
    required this.protocol,
    this.ping = -1,
    this.isTesting = false,
  });

  Map<String, dynamic> toJson() => {
        'remark': remark,
        'uri': uri,
        'protocol': protocol,
        'ping': ping,
      };

  factory ServerNode.fromJson(Map<String, dynamic> json) => ServerNode(
        remark: json['remark'] ?? 'Unknown Server',
        uri: json['uri'] ?? '',
        protocol: json['protocol'] ?? 'Xray',
        ping: json['ping'] ?? -1,
      );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  late final FlutterV2ray flutterV2ray;
  V2RayStatus v2rayStatus = V2RayStatus();

  late AnimationController _pulseController;
  late AnimationController _rotateController;

  int currentTab = 0;
  List<ServerNode> servers = [];
  int selectedIndex = 0;

  // فیلتر و جستجو در تب سرورها
  String searchQuery = "";
  String selectedProtocolFilter = "ALL";

  // تنظیمات سپر ضد فیلترینگ (Core Shield)
  bool bypassLocal = true;
  bool enableFragment = true;
  bool smartAutoSelect = true;
  bool muxEnabled = false;
  bool isTestingAll = false;

  String selectedDns = '1.1.1.1';
  String fragmentPreset = 'MCI/Irancell';
  String fragmentLength = '10-20';
  String fragmentInterval = '10-20';
  String pingTestUrl = 'https://www.gstatic.com/generate_204';

  // اطلاعات اشتراک (Happ Style)
  String subTitle = "اشتراک ویژه لنترن";
  String lastSubUrl = "";
  double usedGB = 0.0;
  double totalGB = 0.0;
  int expireDays = 0;

  // لاگ‌های زنده هسته
  final List<String> coreLogs = [];
  String detectedIp = "---.---.---.---";
  String detectedCountry = "نامشخص";
  bool isCheckingIp = false;

  static const List<String> defaultBypassList = [
    "0.0.0.0/5", "8.0.0.0/7", "11.0.0.0/8", "12.0.0.0/6", "16.0.0.0/4",
    "32.0.0.0/3", "64.0.0.0/2", "128.0.0.0/3", "160.0.0.0/5", "168.0.0.0/6",
    "172.0.0.0/12", "172.32.0.0/11", "172.64.0.0/10", "172.128.0.0/9",
    "173.0.0.0/8", "174.0.0.0/7", "176.0.0.0/4", "192.0.0.0/9",
    "192.128.0.0/11", "192.160.0.0/13", "192.169.0.0/16", "192.170.0.0/15",
    "192.172.0.0/14", "192.176.0.0/12", "192.192.0.0/10", "193.0.0.0/8",
    "194.0.0.0/7", "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4",
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (mounted) {
          final prevState = v2rayStatus.state;
          setState(() => v2rayStatus = status);
          if (prevState != status.state) {
            _addLog("وضعیت هسته تغییر کرد به: ${status.state}");
          }
        }
      },
    );
    _initV2ray();
    _loadSavedData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    setState(() {
      coreLogs.insert(0, "[$timeStr] $message");
      if (coreLogs.length > 80) coreLogs.removeLast();
    });
  }

  Future<void> _initV2ray() async {
    await flutterV2ray.initializeV2Ray();
    _addLog("موتور Xray-Core با موفقیت مقداردهی شد.");
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedList = prefs.getStringList('servers') ?? [];
    setState(() {
      servers = savedList
          .map((item) => ServerNode.fromJson(jsonDecode(item)))
          .toList();
      selectedIndex = prefs.getInt('selectedIndex') ?? 0;
      if (selectedIndex >= servers.length) selectedIndex = 0;
      subTitle = prefs.getString('subTitle') ?? "اشتراک ویژه لنترن";
      lastSubUrl = prefs.getString('lastSubUrl') ?? "";
      usedGB = prefs.getDouble('usedGB') ?? 0.0;
      totalGB = prefs.getDouble('totalGB') ?? 0.0;
      expireDays = prefs.getInt('expireDays') ?? 0;
      enableFragment = prefs.getBool('enableFragment') ?? true;
      bypassLocal = prefs.getBool('bypassLocal') ?? true;
      smartAutoSelect = prefs.getBool('smartAutoSelect') ?? true;
      muxEnabled = prefs.getBool('muxEnabled') ?? false;
      selectedDns = prefs.getString('selectedDns') ?? '1.1.1.1';
      fragmentPreset = prefs.getString('fragmentPreset') ?? 'MCI/Irancell';
      fragmentLength = prefs.getString('fragmentLength') ?? '10-20';
      fragmentInterval = prefs.getString('fragmentInterval') ?? '10-20';
    });
    _addLog("${servers.length} سرور از حافظه بارگذاری شد.");
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = servers.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('servers', encoded);
    await prefs.setInt('selectedIndex', selectedIndex);
    await prefs.setString('subTitle', subTitle);
    await prefs.setString('lastSubUrl', lastSubUrl);
    await prefs.setDouble('usedGB', usedGB);
    await prefs.setDouble('totalGB', totalGB);
    await prefs.setInt('expireDays', expireDays);
    await prefs.setBool('enableFragment', enableFragment);
    await prefs.setBool('bypassLocal', bypassLocal);
    await prefs.setBool('smartAutoSelect', smartAutoSelect);
    await prefs.setBool('muxEnabled', muxEnabled);
    await prefs.setString('selectedDns', selectedDns);
    await prefs.setString('fragmentPreset', fragmentPreset);
    await prefs.setString('fragmentLength', fragmentLength);
    await prefs.setString('fragmentInterval', fragmentInterval);
  }

  String _detectProtocol(String uri) {
    final lower = uri.toLowerCase();
    if (lower.startsWith('vless://')) return 'VLESS';
    if (lower.startsWith('vmess://')) return 'VMess';
    if (lower.startsWith('trojan://')) return 'Trojan';
    if (lower.startsWith('ss://')) return 'Shadowsocks';
    return 'Xray';
  }

  Map<String, dynamic>? _extractHostPort(String uriStr) {
    try {
      if (uriStr.startsWith('vmess://')) {
        String b64 = uriStr.substring(8);
        String decoded = utf8.decode(base64.decode(base64.normalize(b64)));
        var map = jsonDecode(decoded);
        return {
          'host': map['add']?.toString() ?? '',
          'port': int.tryParse(map['port'].toString()) ?? 443
        };
      } else {
        int hashIdx = uriStr.indexOf('#');
        String clean = hashIdx != -1 ? uriStr.substring(0, hashIdx) : uriStr;
        Uri u = Uri.parse(clean);
        return {
          'host': u.host,
          'port': u.port > 0 ? u.port : 443,
        };
      }
    } catch (_) {
      return null;
    }
  }

  // تست پینگ واقعی دوحالته (Xray Delay + TCP Handshake Fallback)
  Future<void> testSingleServerPing(int index) async {
    if (index < 0 || index >= servers.length) return;
    setState(() => servers[index].isTesting = true);

    int resultPing = -1;
    final node = servers[index];

    try {
      final hp = _extractHostPort(node.uri);
      if (hp != null && hp['host'].toString().isNotEmpty) {
        final sw = Stopwatch()..start();
        final socket = await Socket.connect(
          hp['host'],
          hp['port'],
          timeout: const Duration(milliseconds: 2000),
        );
        sw.stop();
        await socket.close();
        resultPing = sw.elapsedMilliseconds;
      }
    } catch (_) {
      resultPing = -1;
    }

    if (resultPing <= 0) {
      try {
        final parser = FlutterV2ray.parseFromURL(node.uri);
        resultPing = await flutterV2ray
            .getServerDelay(config: parser.getFullConfiguration(), url: pingTestUrl)
            .timeout(const Duration(milliseconds: 2200), onTimeout: () => -2);
      } catch (_) {
        resultPing = -2;
      }
    }

    if (mounted && index < servers.length) {
      setState(() {
        servers[index].ping = resultPing > 0 ? resultPing : -2;
        servers[index].isTesting = false;
      });
    }
  }

  Future<void> testAllPings() async {
    if (servers.isEmpty || isTestingAll) return;
    setState(() => isTestingAll = true);
    _addLog("شروع تست پینگ موازی برای ${servers.length} سرور...");

    const int batchSize = 6;
    for (int i = 0; i < servers.length; i += batchSize) {
      final end = (i + batchSize < servers.length) ? i + batchSize : servers.length;
      final List<Future<void>> batch = [];
      for (int j = i; j < end; j++) {
        batch.add(testSingleServerPing(j));
      }
      await Future.wait(batch);
    }

    if (!mounted) return;
    setState(() {
      servers.sort((a, b) {
        if (a.ping <= 0 && b.ping <= 0) return 0;
        if (a.ping <= 0) return 1;
        if (b.ping <= 0) return -1;
        return a.ping.compareTo(b.ping);
      });
      selectedIndex = 0;
      isTestingAll = false;
    });
    _saveData();
    final healthyCount = servers.where((s) => s.ping > 0).length;
    _addLog("تست پینگ کامل شد. $healthyCount سرور سالم یافت شد.");
    _showToast("تست کامل شد! $healthyCount سرور فعال و آماده اتصال است.");
  }

  String _buildEnhancedConfig(String rawConfigJson) {
    try {
      final Map<String, dynamic> config = jsonDecode(rawConfigJson);

      config['dns'] = {
        'servers': [selectedDns, '8.8.8.8']
      };

      if (config['outbounds'] is List && (config['outbounds'] as List).isNotEmpty) {
        final Map<String, dynamic> mainOutbound = config['outbounds'][0];

        if (muxEnabled) {
          mainOutbound['mux'] = {'enabled': true, 'concurrency': 8};
        }

        if (enableFragment) {
          mainOutbound['streamSettings'] ??= <String, dynamic>{};
          mainOutbound['streamSettings']['sockopt'] = {
            'dialerProxy': 'fragment',
            'tcpKeepAliveIdle': 100,
            'tcpNoDelay': true,
          };

          (config['outbounds'] as List).add({
            'tag': 'fragment',
            'protocol': 'freedom',
            'settings': {
              'domainStrategy': 'AsIs',
              'fragment': {
                'packets': 'tlshello',
                'length': fragmentLength,
                'interval': fragmentInterval,
              }
            },
            'streamSettings': {
              'sockopt': {'tcpNoDelay': true}
            }
          });
        }
      }
      return jsonEncode(config);
    } catch (_) {
      return rawConfigJson;
    }
  }

  Future<void> importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      _showToast('کلیپ‌بورد خالی است! ابتدا لینک کانفیگ یا اشتراک را کپی کنید.');
      return;
    }

    final text = data.text!.trim();
    if (text.startsWith('http://') || text.startsWith('https://')) {
      lastSubUrl = text;
      _addLog("دریافت لینک اشتراک: $text");
      _showToast('در حال دریافت سرورها از لینک اشتراک...');
      await _fetchSubscription(text);
    } else {
      _parseAndAddLinks(text);
    }
  }

  Future<void> _fetchSubscription(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final userInfo = response.headers['subscription-userinfo'];
        if (userInfo != null) {
          _parseSubHeader(userInfo);
        }
        final profileTitle = response.headers['profile-title'];
        if (profileTitle != null) {
          subTitle = profileTitle;
        } else {
          subTitle = "اشتراک فعال (${Uri.parse(url).host})";
        }

        String body = response.body.trim();
        try {
          body = utf8.decode(base64.decode(base64.normalize(body)));
        } catch (_) {}

        _parseAndAddLinks(body, clearOld: true);
      } else {
        _showToast('خطا در دریافت اشتراک: کد ${response.statusCode}');
      }
    } catch (e) {
      _addLog("خطا در آپدیت اشتراک: $e");
      _showToast('خطا در ارتباط با سرور اشتراک.');
    }
  }

  void _parseSubHeader(String header) {
    try {
      int upload = 0, download = 0, total = 0, expire = 0;
      final parts = header.split(';');
      for (var p in parts) {
        final kv = p.trim().split('=');
        if (kv.length == 2) {
          final key = kv[0].trim();
          final val = int.tryParse(kv[1].trim()) ?? 0;
          if (key == 'upload') upload = val;
          if (key == 'download') download = val;
          if (key == 'total') total = val;
          if (key == 'expire') expire = val;
        }
      }
      setState(() {
        usedGB = double.parse(((upload + download) / (1024 * 1024 * 1024)).toStringAsFixed(2));
        totalGB = double.parse((total / (1024 * 1024 * 1024)).toStringAsFixed(2));
        if (expire > 0) {
          final expDate = DateTime.fromMillisecondsSinceEpoch(expire * 1000);
          expireDays = expDate.difference(DateTime.now()).inDays;
          if (expireDays < 0) expireDays = 0;
        }
      });
    } catch (_) {}
  }

  void _parseAndAddLinks(String rawText, {bool clearOld = false}) {
    final lines = rawText.split(RegExp(r'[\r\n]+'));
    int added = 0;
    if (clearOld) servers.clear();

    for (var line in lines) {
      final link = line.trim();
      if (link.startsWith('vless://') ||
          link.startsWith('vmess://') ||
          link.startsWith('trojan://') ||
          link.startsWith('ss://')) {
        try {
          final parsed = FlutterV2ray.parseFromURL(link);
          setState(() {
            servers.add(ServerNode(
              remark: parsed.remark.isNotEmpty ? parsed.remark : 'Node #${servers.length + 1}',
              uri: link,
              protocol: _detectProtocol(link),
            ));
          });
          added++;
        } catch (_) {}
      }
    }

    if (added > 0) {
      selectedIndex = 0;
      _saveData();
      _addLog("$added کانفیگ جدید به لیست اضافه شد.");
      _showToast('$added سرور با موفقیت اضافه شد!');
      testAllPings();
    } else {
      _showToast('هیچ لینک معتبری در کلیپ‌بورد پیدا نشد.');
    }
  }

  Future<void> toggleConnection() async {
    if (v2rayStatus.state == 'CONNECTED') {
      await flutterV2ray.stopV2Ray();
      _addLog("اتصال به درخواست کاربر قطع شد.");
      return;
    }

    if (servers.isEmpty) {
      _showToast('ابتدا از بالا دکمه + را بزنید و کانفیگ وارد کنید.');
      return;
    }

    if (smartAutoSelect) {
      final hasValidPing = servers.any((s) => s.ping > 0);
      if (!hasValidPing) {
        _showToast('در حال اسکن هوشمند سریع‌ترین سرور...');
        await testAllPings();
      } else {
        final bestIdx = servers.indexWhere((s) => s.ping > 0);
        if (bestIdx != -1) {
          setState(() => selectedIndex = bestIdx);
        }
      }
    }

    try {
      final currentServer = servers[selectedIndex];
      final parser = FlutterV2ray.parseFromURL(currentServer.uri);
      final finalConfig = _buildEnhancedConfig(parser.getFullConfiguration());

      if (await flutterV2ray.requestPermission()) {
        _addLog("در حال اتصال به [${currentServer.remark}] (Fragment: $enableFragment)...");
        await flutterV2ray.startV2Ray(
          remark: parser.remark,
          config: finalConfig,
          bypassSubnets: bypassLocal ? defaultBypassList : null,
        );
      } else {
        _showToast('مجوز ساخت تونل VPN تایید نشد.');
      }
    } catch (e) {
      _addLog("خطا در اتصال: $e");
      _showToast('خطا در اجرای این کانفیگ.');
    }
  }

  Future<void> checkRealIp() async {
    if (isCheckingIp) return;
    setState(() => isCheckingIp = true);
    try {
      final res = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          detectedIp = data['query'] ?? 'نامشخص';
          detectedCountry = "${data['country'] ?? ''} (${data['isp'] ?? ''})";
        });
        _addLog("آی‌پی شناسایی شد: $detectedIp - $detectedCountry");
      }
    } catch (_) {
      _showToast('خطا در بررسی آی‌پی.');
    }
    setState(() => isCheckingIp = false);
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF141E38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: const Color(0xFF00F0FF).withOpacity(0.3)),
        ),
        content: Row(
          children: [
            const Icon(Icons.Auto_awesome, color: Color(0xFF00F0FF), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = v2rayStatus.state == 'CONNECTED';

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ۱. پس‌زمینه نوری سایبرپانک (Ambient Glow Orbs)
          Positioned(
            top: -100,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isConnected ? const Color(0xFF00F0FF) : const Color(0xFF0055FF))
                    .withOpacity(0.14),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            right: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6A00FF).withOpacity(0.12),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(color: Colors.transparent),
          ),

          // ۲. محتوای اصلی صفحات
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopHeader(isConnected),
                Expanded(
                  child: IndexedStack(
                    index: currentTab,
                    children: [
                      _buildDashboardTab(isConnected),
                      _buildNodesTab(),
                      _buildShieldSettingsTab(),
                      _buildRadarLogsTab(isConnected),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildFloatingGlassDock(),
    );
  }

  // هدر بالای برنامه با دکمه‌های شناور شیشه‌ای
  Widget _buildTopHeader(bool isConnected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F0FF), Color(0xFF0055FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00F0FF).withOpacity(0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.flare_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'LANTERN',
                        style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.8, fontSize: 16),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F0FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.4)),
                        ),
                        child: const Text(
                          'ULTRA',
                          style: TextStyle(color: Color(0xFF00F0FF), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isConnected ? 'تونل امن Xray فعال است' : 'محافظت پیشرفته شبکه',
                    style: TextStyle(
                      fontSize: 10,
                      color: isConnected ? const Color(0xFF00F0FF) : Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildGlassIconButton(
                icon: isTestingAll ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
                tooltip: 'تست پینگ سریع همه سرورها',
                color: const Color(0xFFFFB800),
                onTap: testAllPings,
              ),
              const SizedBox(width: 8),
              if (lastSubUrl.isNotEmpty) ...[
                _buildGlassIconButton(
                  icon: Icons.sync_rounded,
                  tooltip: 'آپدیت اشتراک',
                  color: Colors.white,
                  onTap: () => _fetchSubscription(lastSubUrl),
                ),
                const SizedBox(width: 8),
              ],
              _buildGlassIconButton(
                icon: Icons.add_rounded,
                tooltip: 'افزودن از کلیپ‌بورد',
                color: const Color(0xFF00F0FF),
                onTap: importFromClipboard,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF141E36).withOpacity(0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ==================== تب ۱: داشبورد اصلی (HOME) ====================
  Widget _buildDashboardTab(bool isConnected) {
    final activeServer = servers.isNotEmpty && selectedIndex < servers.length
        ? servers[selectedIndex]
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
      child: Column(
        children: [
          // ۱. کارت شیشه‌ای اشتراک (Happ Style)
          _buildGlassSubscriptionCard(),

          const SizedBox(height: 22),

          // ۲. دکمه اتصال مرکزی چندلایه نئونی (Animated Cyber Orb)
          _buildCyberConnectOrb(isConnected),

          const SizedBox(height: 22),

          // ۳. پنل زنده ترافیک دانلود، آپلود و زمان اتصال
          _buildLiveTelemetryRow(isConnected),

          const SizedBox(height: 16),

          // ۴. کارت سرور انتخابی فعلی (با قابلیت کلیک برای رفتن به لیست سرورها)
          GestureDetector(
            onTap: () => setState(() => currentTab = 1),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF15203B).withOpacity(0.85),
                    const Color(0xFF0D1426).withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0055FF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.public_rounded, color: Color(0xFF00F0FF)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'سرور انتخاب‌شده فعلی',
                          style: TextStyle(fontSize: 10, color: Colors.white54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeServer != null
                              ? activeServer.remark
                              : 'هیچ سروری انتخاب نشده (ضربه بزنید)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  if (activeServer != null) ...[
                    _buildSignalBars(activeServer.ping),
                    const SizedBox(width: 8),
                    Text(
                      activeServer.ping > 0 ? '${activeServer.ping} ms' : '---',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00F0FF),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ۵. سوییچ‌های سریع ضد فیلترینگ روی داشبورد
          Row(
            children: [
              Expanded(
                child: _buildMiniDashboardToggle(
                  title: 'Auto Fragment',
                  subtitle: enableFragment ? 'فعال ($fragmentLength)' : 'غیرفعال',
                  icon: Icons.grain_rounded,
                  active: enableFragment,
                  onTap: () {
                    setState(() => enableFragment = !enableFragment);
                    _saveData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniDashboardToggle(
                  title: 'اتصال هوشمند',
                  subtitle: smartAutoSelect ? 'سریع‌ترین پینگ' : 'انتخاب دستی',
                  icon: Icons.auto_awesome_rounded,
                  active: smartAutoSelect,
                  onTap: () {
                    setState(() => smartAutoSelect = !smartAutoSelect);
                    _saveData();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSubscriptionCard() {
    double progress = totalGB > 0 ? (usedGB / totalGB).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172442), Color(0xFF0E162B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F0FF).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFF00F0FF), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subTitle,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${servers.length} سرور آماده در لیست',
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0055FF).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.3)),
                ),
                child: Text(
                  expireDays > 0 ? '$expireDays روز باقی‌مانده' : 'نسخه PRO',
                  style: const TextStyle(color: Color(0xFF00F0FF), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: totalGB > 0 ? progress : 0.15,
              minHeight: 7,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00F0FF)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalGB > 0 ? 'مصرف شده: $usedGB GB' : 'کپی لینک و زدن دکمه + برای افزودن اشتراک',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              if (totalGB > 0)
                Text(
                  'کل حجم: $totalGB GB',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCyberConnectOrb(bool isConnected) {
    final Color primaryOrb = isConnected ? const Color(0xFF00F0FF) : const Color(0xFF0055FF);

    return GestureDetector(
      onTap: toggleConnection,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _rotateController]),
        builder: (context, child) {
          final double pulse = _pulseController.value;
          return SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // هاله بیرونی تنفسی
                Container(
                  width: 175 + (pulse * 22),
                  height: 175 + (pulse * 22),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryOrb.withOpacity(isConnected ? 0.12 : 0.05),
                  ),
                ),
                // حلقه چرخان راداری در زمان اتصال
                if (isConnected)
                  Transform.rotate(
                    angle: _rotateController.value * 2 * math.pi,
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Colors.transparent,
                            primaryOrb.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                // دکمه اصلی شیشه‌ای
                Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF192647), Color(0xFF0C1224)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: primaryOrb.withOpacity(isConnected ? 0.9 : 0.4),
                      width: isConnected ? 3.5 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryOrb.withOpacity(isConnected ? 0.45 : 0.15),
                        blurRadius: isConnected ? 40 : 20,
                        spreadRadius: isConnected ? 5 : 1,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.power_settings_new_rounded,
                        size: 54,
                        color: isConnected ? const Color(0xFF00F0FF) : Colors.white,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isConnected ? 'CONNECTED' : 'CONNECT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: isConnected ? const Color(0xFF00F0FF) : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiveTelemetryRow(bool isConnected) {
    return Row(
      children: [
        Expanded(
          child: _buildTelemetryCard(
            title: 'دانلود زنده',
            value: isConnected ? '${v2rayStatus.downloadSpeed} B/s' : '0 B/s',
            icon: Icons.south_west_rounded,
            iconColor: const Color(0xFF00FF9D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTelemetryCard(
            title: 'آپلود زنده',
            value: isConnected ? '${v2rayStatus.uploadSpeed} B/s' : '0 B/s',
            icon: Icons.north_east_rounded,
            iconColor: const Color(0xFFFFB800),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTelemetryCard(
            title: 'زمان اتصال',
            value: isConnected ? v2rayStatus.duration : '00:00:00',
            icon: Icons.timer_outlined,
            iconColor: const Color(0xFF00F0FF),
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111A30).withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 14),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDashboardToggle({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF0055FF).withOpacity(0.22)
              : const Color(0xFF111A30).withOpacity(0.65),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? const Color(0xFF00F0FF).withOpacity(0.5) : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? const Color(0xFF00F0FF) : Colors.white54, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== تب ۲: مدیریت حرفه‌ای سرورها (NODES) ====================
  Widget _buildNodesTab() {
    final filteredServers = servers.asMap().entries.where((entry) {
      final s = entry.value;
      final matchSearch = s.remark.toLowerCase().contains(searchQuery.toLowerCase());
      final matchProto =
          selectedProtocolFilter == 'ALL' || s.protocol.toUpperCase() == selectedProtocolFilter;
      return matchSearch && matchProto;
    }).toList();

    return Column(
      children: [
        // نوار جستجو و فیلتر پروتکل
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => searchQuery = val),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'جستجوی نام کشور یا سرور...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00F0FF), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF111A30),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final proto in ['ALL', 'VLESS', 'VMESS', 'TROJAN'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(proto, style: const TextStyle(fontSize: 11)),
                          selected: selectedProtocolFilter == proto,
                          selectedColor: const Color(0xFF0055FF),
                          backgroundColor: const Color(0xFF111A30),
                          onSelected: (_) => setState(() => selectedProtocolFilter = proto),
                        ),
                      ),
                    const SizedBox(width: 10),
                    if (servers.isNotEmpty)
                      ActionChip(
                        backgroundColor: Colors.redAccent.withOpacity(0.15),
                        label: const Text(
                          'حذف سرورهای Timeout',
                          style: TextStyle(fontSize: 11, color: Colors.redAccent),
                        ),
                        onPressed: () {
                          setState(() {
                            servers.removeWhere((s) => s.ping == -2);
                            if (selectedIndex >= servers.length) selectedIndex = 0;
                          });
                          _saveData();
                          _showToast('سرورهای بدون پینگ پاکسازی شدند.');
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // لیست سرورها با آنتن سیگنال و منوی امکانات
        Expanded(
          child: filteredServers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dns_outlined, size: 52, color: Colors.white.withOpacity(0.15)),
                      const SizedBox(height: 12),
                      const Text(
                        'هیچ سروری در این بخش وجود ندارد.\nلینک اشتراک یا کانفیگ را کپی کرده و دکمه + بالا را بزنید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.6),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
                  itemCount: filteredServers.length,
                  itemBuilder: (context, idx) {
                    final realIndex = filteredServers[idx].key;
                    final s = filteredServers[idx].value;
                    final isSelected = realIndex == selectedIndex;

                    Color pingColor = const Color(0xFF00FF9D);
                    if (s.ping > 220) pingColor = const Color(0xFFFFB800);
                    if (s.ping <= 0 || s.ping > 550) pingColor = Colors.redAccent;

                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedIndex = realIndex);
                        _saveData();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF17264A)
                              : const Color(0xFF0F1629).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00F0FF)
                                : Colors.white.withOpacity(0.05),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF00F0FF).withOpacity(0.2)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  s.protocol.substring(0, math.min(2, s.protocol.length)).toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: isSelected ? const Color(0xFF00F0FF) : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.remark,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0055FF).withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          s.protocol,
                                          style: const TextStyle(fontSize: 9, color: Color(0xFF00F0FF)),
                                        ),
                                      ),
                                      if (enableFragment) ...[
                                        const SizedBox(width: 6),
                                        const Text('Fragment⚡', style: TextStyle(fontSize: 9, color: Color(0xFFFFB800))),
                                      ]
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // دکمه تست پینگ تکی + آنتن گرافیکی
                            GestureDetector(
                              onTap: () => testSingleServerPing(realIndex),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: s.isTesting
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00F0FF)),
                                      )
                                    : Row(
                                        children: [
                                          _buildSignalBars(s.ping),
                                          const SizedBox(width: 6),
                                          Text(
                                            s.ping > 0 ? '${s.ping}ms' : (s.ping == -2 ? 'Timeout' : 'تست'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: s.ping > 0 ? pingColor : Colors.white38,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
                              color: const Color(0xFF16223F),
                              onSelected: (val) {
                                if (val == 'copy') {
                                  Clipboard.setData(ClipboardData(text: s.uri));
                                  _showToast('لینک کانفیگ کپی شد.');
                                } else if (val == 'delete') {
                                  setState(() {
                                    servers.removeAt(realIndex);
                                    if (selectedIndex >= servers.length) selectedIndex = 0;
                                  });
                                  _saveData();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'copy', child: Text('کپی لینک کانفیگ', style: TextStyle(fontSize: 12))),
                                const PopupMenuItem(value: 'delete', child: Text('حذف سرور', style: TextStyle(fontSize: 12, color: Colors.redAccent))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // آنتن گرافیکی ۴ خط برای نمایش کیفیت پینگ
  Widget _buildSignalBars(int ping) {
    int activeBars = 0;
    Color barColor = Colors.white24;
    if (ping > 0 && ping < 150) {
      activeBars = 4;
      barColor = const Color(0xFF00FF9D);
    } else if (ping >= 150 && ping < 280) {
      activeBars = 3;
      barColor = const Color(0xFF00F0FF);
    } else if (ping >= 280 && ping < 500) {
      activeBars = 2;
      barColor = const Color(0xFFFFB800);
    } else if (ping >= 500) {
      activeBars = 1;
      barColor = Colors.redAccent;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 3,
          height: 5.0 + (i * 3.0),
          decoration: BoxDecoration(
            color: i < activeBars ? barColor : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  // ==================== تب ۳: سپر ضد فیلترینگ (CORE SHIELD) ====================
  Widget _buildShieldSettingsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      children: [
        const Text(
          'سپر ضد فیلترینگ و مهندسی ترافیک',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00F0FF)),
        ),
        const SizedBox(height: 4),
        const Text(
          'تنظیمات این بخش مستقیماً روی هسته Xray اعمال می‌شوند تا شدیدترین محدودیت‌های شبکه را دور بزنند.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 16),

        // کارت ۱: تنظیمات TLS Fragment
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10192E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تکه‌تکه کردن پکت‌ها (TLS Fragment)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('دور زدن فیلترینگ SNI در اپراتورهای همراه اول و ایرانسل', style: TextStyle(fontSize: 11, color: Colors.white54)),
                activeColor: const Color(0xFF00F0FF),
                value: enableFragment,
                onChanged: (v) {
                  setState(() => enableFragment = v);
                  _saveData();
                },
              ),
              if (enableFragment) ...[
                const Divider(color: Colors.white10),
                const Text('پروفایل اپراتور:', style: TextStyle(fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    {'title': 'همراه اول / ایرانسل', 'len': '10-20', 'int': '10-20'},
                    {'title': 'فیلترینگ شدید (5-10)', 'len': '5-10', 'int': '5-10'},
                    {'title': 'اینترنت خانگی ADSL', 'len': '50-100', 'int': '10-20'},
                  ].map((p) {
                    final isSel = fragmentLength == p['len'];
                    return ChoiceChip(
                      label: Text(p['title']!, style: const TextStyle(fontSize: 11)),
                      selected: isSel,
                      selectedColor: const Color(0xFF0055FF),
                      onSelected: (_) {
                        setState(() {
                          fragmentPreset = p['title']!;
                          fragmentLength = p['len']!;
                          fragmentInterval = p['int']!;
                        });
                        _saveData();
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // کارت ۲: انتخاب DNS امن
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10192E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.dns_rounded, color: Color(0xFF00F0FF), size: 20),
                  SizedBox(width: 8),
                  Text('سرور DNS ضد تحریم و سریع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  {'name': 'Cloudflare (1.1.1.1)', 'dns': '1.1.1.1'},
                  {'name': 'Google (8.8.8.8)', 'dns': '8.8.8.8'},
                  {'name': 'Quad9 Security (9.9.9.9)', 'dns': '9.9.9.9'},
                ].map((d) {
                  final active = selectedDns == d['dns'];
                  return ChoiceChip(
                    label: Text(d['name']!, style: const TextStyle(fontSize: 11)),
                    selected: active,
                    selectedColor: const Color(0xFF0055FF),
                    onSelected: (_) {
                      setState(() => selectedDns = d['dns']!);
                      _saveData();
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // کارت ۳: مسیریابی و مالتی‌پلکسینگ
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10192E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('مسیریابی هوشمند داخلی (Split Tunneling)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('عبور مستقیم ترافیک داخلی برای جلوگیری از کند شدن بانک‌ها و سایت‌های ایرانی', style: TextStyle(fontSize: 11, color: Colors.white54)),
                activeColor: const Color(0xFF00F0FF),
                value: bypassLocal,
                onChanged: (v) {
                  setState(() => bypassLocal = v);
                  _saveData();
                },
              ),
              const Divider(color: Colors.white10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('فناوری Multiplex (کاهش پینگ گیمینگ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('ارسال همزمان چند درخواست در یک اتصال TCP واحد', style: TextStyle(fontSize: 11, color: Colors.white54)),
                activeColor: const Color(0xFF00F0FF),
                value: muxEnabled,
                onChanged: (v) {
                  setState(() => muxEnabled = v);
                  _saveData();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== تب ۴: رادار آی‌پی و لاگ هسته (RADAR & LOGS) ====================
  Widget _buildRadarLogsTab(bool isConnected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // کارت بررسی آی‌پی و لوکیشن
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF172546), Color(0xFF0E162B)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('آی‌پی و موقعیت فعلی شما:', style: TextStyle(fontSize: 11, color: Colors.white54)),
                    const SizedBox(height: 4),
                    Text(detectedIp, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00F0FF))),
                    const SizedBox(height: 2),
                    Text(detectedCountry, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0055FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: checkRealIp,
                  icon: isCheckingIp
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.radar_rounded, size: 18),
                  label: const Text('بررسی IP', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ترمینال زنده هسته (Xray Live Logs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              GestureDetector(
                onTap: () => setState(() => coreLogs.clear()),
                child: const Text('پاک کردن لاگ', style: TextStyle(fontSize: 11, color: Color(0xFF00F0FF))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ترمینال لاگ‌ها
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF050811),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: coreLogs.isEmpty
                  ? const Center(child: Text('هیچ رویدادی ثبت نشده است.', style: TextStyle(color: Colors.white24, fontSize: 12)))
                  : ListView.builder(
                      itemCount: coreLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            coreLogs[index],
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Color(0xFF00FF9D),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== نوار ناوبری شناور شیشه‌ای پایین صفحه ====================
  Widget _buildFloatingGlassDock() {
    final items = [
      {'icon': Icons.dashboard_rounded, 'label': 'داشبورد'},
      {'icon': Icons.dns_rounded, 'label': 'سرورها'},
      {'icon': Icons.shield_rounded, 'label': 'سپر هسته'},
      {'icon': Icons.terminal_rounded, 'label': 'رادار و لاگ'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10182E).withOpacity(0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final isSelected = currentTab == index;
                return GestureDetector(
                  onTap: () => setState(() => currentTab = index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0055FF).withOpacity(0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: const Color(0xFF00F0FF).withOpacity(0.4))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          items[index]['icon'] as IconData,
                          size: 21,
                          color: isSelected ? const Color(0xFF00F0FF) : Colors.white54,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Text(
                            items[index]['label'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
