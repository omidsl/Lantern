import 'dart:convert';
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
    ),
  );
  runApp(const LanternVpnApp());
}

class LanternVpnApp extends StatelessWidget {
  const LanternVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        primaryColor: const Color(0xFF0066FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0066FF),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF131B2E),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class ServerNode {
  final String remark;
  final String uri;
  final String protocol;
  int ping;

  ServerNode({
    required this.remark,
    required this.uri,
    required this.protocol,
    this.ping = -1,
  });

  Map<String, dynamic> toJson() => {
        'remark': remark,
        'uri': uri,
        'protocol': protocol,
        'ping': ping,
      };

  factory ServerNode.fromJson(Map<String, dynamic> json) => ServerNode(
        remark: json['remark'],
        uri: json['uri'],
        protocol: json['protocol'],
        ping: json['ping'] ?? -1,
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final FlutterV2ray flutterV2ray;
  V2RayStatus v2rayStatus = V2RayStatus();

  List<ServerNode> servers = [];
  int selectedIndex = 0;

  bool bypassIran = true;
  bool isTestingPing = false;

  // اطلاعات اشتراک به سبک Happ
  String subTitle = "اشتراک لنترن (آماده دریافت لینک)";
  double usedGB = 0.0;
  double totalGB = 0.0;
  int expireDays = 0;

  @override
  void initState() {
    super.initState();
    flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (mounted) {
          setState(() => v2rayStatus = status);
        }
      },
    );
    _initV2ray();
    _loadSavedData();
  }

  Future<void> _initV2ray() async {
    await flutterV2ray.initializeV2Ray();
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
      subTitle = prefs.getString('subTitle') ?? "Lantern VIP Client";
      usedGB = prefs.getDouble('usedGB') ?? 0.0;
      totalGB = prefs.getDouble('totalGB') ?? 0.0;
      expireDays = prefs.getInt('expireDays') ?? 0;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = servers.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList('servers', encoded);
    await prefs.setInt('selectedIndex', selectedIndex);
    await prefs.setString('subTitle', subTitle);
    await prefs.setDouble('usedGB', usedGB);
    await prefs.setDouble('totalGB', totalGB);
    await prefs.setInt('expireDays', expireDays);
  }

  String _detectProtocol(String uri) {
    final lower = uri.toLowerCase();
    if (lower.startsWith('vless://')) return 'VLESS';
    if (lower.startsWith('vmess://')) return 'VMess';
    if (lower.startsWith('trojan://')) return 'Trojan';
    if (lower.startsWith('ss://')) return 'Shadowsocks';
    return 'Xray';
  }

  Future<void> importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      _showMsg('کلیپ‌بورد خالی است! ابتدا لینک کانفیگ یا اشتراک را کپی کنید.');
      return;
    }

    final text = data.text!.trim();

    if (text.startsWith('http://') || text.startsWith('https://')) {
      _showMsg('در حال دریافت اطلاعات اشتراک و سرورها...');
      await _fetchSubscription(text);
    } else {
      _parseAndAddLinks(text);
    }
  }

  Future<void> _fetchSubscription(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
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
        _showMsg('خطا در دریافت لینک اشتراک: کد ${response.statusCode}');
      }
    } catch (e) {
      _showMsg('خطا در ارتباط با سرور اشتراک.');
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
              remark: parsed.remark.isNotEmpty ? parsed.remark : 'سرور ${servers.length + 1}',
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
      _showMsg('$added کانفیگ با موفقیت به لنترن اضافه شد!');
      testAllPings();
    } else {
      _showMsg('لینک معتبری پیدا نشد.');
    }
  }

  Future<void> toggleConnection() async {
    if (v2rayStatus.state == 'CONNECTED') {
      await flutterV2ray.stopV2Ray();
      return;
    }

    if (servers.isEmpty) {
      _showMsg('ابتدا یک کانفیگ یا لینک اشتراک با دکمه + بالای صفحه اضافه کنید.');
      return;
    }

    try {
      final currentServer = servers[selectedIndex];
      final parser = FlutterV2ray.parseFromURL(currentServer.uri);

      if (await flutterV2ray.requestPermission()) {
        await flutterV2ray.startV2Ray(
          remark: parser.remark,
          config: parser.getFullConfiguration(),
          bypassSubnets: bypassIran ? FlutterV2ray.defaultBypassSubnets() : null,
        );
      } else {
        _showMsg('مجوز ساخت VPN در گوشی تایید نشد.');
      }
    } catch (e) {
      _showMsg('خطا در اتصال به این کانفیگ.');
    }
  }

  Future<void> testAllPings() async {
    if (servers.isEmpty || isTestingPing) return;
    setState(() => isTestingPing = true);

    for (int i = 0; i < servers.length; i++) {
      try {
        final parser = FlutterV2ray.parseFromURL(servers[i].uri);
        final delay = await flutterV2ray.getServerDelay(config: parser.getFullConfiguration());
        if (mounted) {
          setState(() => servers[i].ping = delay);
        }
      } catch (_) {
        if (mounted) {
          setState(() => servers[i].ping = -1);
        }
      }
    }

    setState(() {
      servers.sort((a, b) {
        if (a.ping <= 0) return 1;
        if (b.ping <= 0) return -1;
        return a.ping.compareTo(b.ping);
      });
      selectedIndex = 0;
      isTestingPing = false;
    });
    _saveData();
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF16223A),
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = v2rayStatus.state == 'CONNECTED';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0066FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.wb_incandescent_rounded, color: Color(0xFF00E5FF), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('LANTERN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 18)),
            const Text('PRO', style: TextStyle(fontWeight: FontWeight.w300, color: Color(0xFF00E5FF), letterSpacing: 1.5, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تست پینگ واقعی و انتخاب سریع‌ترین سرور',
            icon: isTestingPing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)))
                : const Icon(Icons.speed_rounded, color: Colors.white70),
            onPressed: testAllPings,
          ),
          IconButton(
            tooltip: 'افزودن کانفیگ یا لینک اشتراک از کلیپ‌بورد',
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF00E5FF), size: 26),
            onPressed: importFromClipboard,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSubscriptionCard(),
          const SizedBox(height: 15),
          _buildConnectionSection(isConnected),
          const SizedBox(height: 15),
          _buildQuickToggles(),
          const SizedBox(height: 15),
          Expanded(child: _buildServerList()),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    double progress = totalGB > 0 ? (usedGB / totalGB).clamp(0.0, 1.0) : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16223A), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFF00E5FF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subTitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              if (expireDays > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$expireDays روز باقی‌مانده',
                    style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalGB > 0 ? 'مصرف شده: $usedGB GB' : 'برای افزودن اشتراک دکمه + بالا را بزنید',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              if (totalGB > 0)
                Text(
                  'کل حجم: $totalGB GB',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSection(bool isConnected) {
    Color activeColor = isConnected ? const Color(0xFF00E5FF) : const Color(0xFF0066FF);

    return Column(
      children: [
        GestureDetector(
          onTap: toggleConnection,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF131B2E),
              border: Border.all(
                color: activeColor.withOpacity(isConnected ? 0.9 : 0.35),
                width: isConnected ? 4 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withOpacity(isConnected ? 0.35 : 0.1),
                  blurRadius: isConnected ? 35 : 15,
                  spreadRadius: isConnected ? 6 : 1,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 50,
                color: isConnected ? const Color(0xFF00E5FF) : Colors.white70,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isConnected ? 'لنترن متصل است (${v2rayStatus.duration})' : 'قطع (برای اتصال ضربه بزنید)',
          style: TextStyle(
            color: isConnected ? const Color(0xFF00E5FF) : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        if (isConnected) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.arrow_downward_rounded, color: Colors.greenAccent, size: 14),
              const SizedBox(width: 4),
              Text('${v2rayStatus.downloadSpeed} B/s', style: const TextStyle(fontSize: 11, color: Colors.white70)),
              const SizedBox(width: 18),
              const Icon(Icons.arrow_upward_rounded, color: Colors.orangeAccent, size: 14),
              const SizedBox(width: 4),
              Text('${v2rayStatus.uploadSpeed} B/s', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ]
      ],
    );
  }

  Widget _buildQuickToggles() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildChip(
            label: 'مسیریابی مستقیم داخلی',
            icon: Icons.alt_route_rounded,
            selected: bypassIran,
            onTap: () => setState(() => bypassIran = !bypassIran),
          ),
          const SizedBox(width: 10),
          _buildChip(
            label: 'مرتب‌سازی هوشمند پینگ',
            icon: Icons.bolt_rounded,
            selected: isTestingPing,
            onTap: testAllPings,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0066FF).withOpacity(0.25) : const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF00E5FF).withOpacity(0.6) : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: selected ? const Color(0xFF00E5FF) : Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111726),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سرورها (${servers.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                ),
                if (servers.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() => servers.clear());
                      _saveData();
                    },
                    child: const Text('پاک کردن همه', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: servers.isEmpty
                ? const Center(
                    child: Text(
                      'هیچ کانفیگی در لنترن وجود ندارد.\nلینک VLESS/VMess یا سابسکریپشن را کپی کنید\nو دکمه + بالای صفحه را بزنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    itemCount: servers.length,
                    itemBuilder: (context, index) {
                      final s = servers[index];
                      final isSelected = index == selectedIndex;

                      Color pingColor = Colors.greenAccent;
                      if (s.ping > 250) pingColor = Colors.orangeAccent;
                      if (s.ping <= 0 || s.ping > 600) pingColor = Colors.redAccent;

                      return GestureDetector(
                        onTap: () {
                          setState(() => selectedIndex = index);
                          _saveData();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1A2540) : const Color(0xFF0D121F),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0066FF) : Colors.white.withOpacity(0.04),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.remark,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.protocol,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF00E5FF)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                s.ping > 0 ? '${s.ping} ms' : (s.ping == -1 ? '---' : 'Timeout'),
                                style: TextStyle(
                                  color: s.ping > 0 ? pingColor : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
