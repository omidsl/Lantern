import 'dart:async';
import 'dart:convert';
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
  runApp(const LanternVisionApp());
}

class LanternVisionApp extends StatelessWidget {
  const LanternVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern Vision',
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
      home: const VisionGlassHome(),
    );
  }
}

class ServerItem {
  final String remark;
  final String uri;
  final String protocol;
  int ping;
  bool testing;

  ServerItem({
    required this.remark,
    required this.uri,
    required this.protocol,
    this.ping = -1,
    this.testing = false,
  });

  Map<String, dynamic> toJson() => {
        'remark': remark,
        'uri': uri,
        'protocol': protocol,
        'ping': ping,
      };

  factory ServerItem.fromJson(Map<String, dynamic> json) => ServerItem(
        remark: json['remark']?.toString() ?? 'Server',
        uri: json['uri']?.toString() ?? '',
        protocol: json['protocol']?.toString() ?? 'VLESS',
        ping: json['ping'] is int ? json['ping'] : -1,
      );
}

class VisionGlassHome extends StatefulWidget {
  const VisionGlassHome({super.key});

  @override
  State<VisionGlassHome> createState() => _VisionGlassHomeState();
}

class _VisionGlassHomeState extends State<VisionGlassHome>
    with SingleTickerProviderStateMixin {
  late final FlutterV2ray flutterV2ray;
  V2RayStatus v2rayStatus = V2RayStatus();
  late final AnimationController _auraController;

  List<ServerItem> servers = [];
  String selectedServerUri = "";

  bool isConnecting = false;
  bool isTestingPings = false;
  int? realConnectedDelay;
  Timer? _connectionWatchdog;
  int _verifyGeneration = 0;

  VoidCallback? _sheetUpdater;

  int routingMode = 0;

  final List<double> dlHistory = List.filled(12, 0.15, growable: true);
  final List<double> ulHistory = List.filled(12, 0.15, growable: true);

  String subName = "اشتراک ابری لنترن";
  String savedSubUrl = "";
  double usedGB = 0.0;
  double totalGB = 0.0;
  int? expireTimestamp;

  int get selectedIndex {
    if (servers.isEmpty) return 0;
    final idx = servers.indexWhere((s) => s.uri == selectedServerUri);
    return idx != -1 ? idx : 0;
  }

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
        final wasConnected = v2rayStatus.state == 'CONNECTED';
        final nowConnected = status.state == 'CONNECTED';

        setState(() {
          v2rayStatus = status;
          if (nowConnected || status.state == 'DISCONNECTED') {
            isConnecting = false;
            _connectionWatchdog?.cancel();
          }
          if (nowConnected) {
            final dlBytes = (int.tryParse(status.downloadSpeed.toString()) ?? 0).toDouble();
            final ulBytes = (int.tryParse(status.uploadSpeed.toString()) ?? 0).toDouble();
            dlHistory.removeAt(0);
            dlHistory.add((dlBytes / 1500000).clamp(0.18, 1.0));
            ulHistory.removeAt(0);
            ulHistory.add((ulBytes / 600000).clamp(0.18, 1.0));
          } else {
            realConnectedDelay = null;
          }
        });

        if (!wasConnected && nowConnected) {
          _verifyConnectedInternetWithRetry();
        }
      },
    );
    flutterV2ray.initializeV2Ray();
    _loadData();
  }

  @override
  void dispose() {
    _connectionWatchdog?.cancel();
    _auraController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList('lantern_servers') ?? [];
      final List<ServerItem> loaded = [];
      for (var item in rawList) {
        try {
          final parsed = ServerItem.fromJson(jsonDecode(item));
          if (parsed.uri.isNotEmpty) loaded.add(parsed);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        servers = loaded;
        selectedServerUri = prefs.getString('selectedServerUri') ??
            (servers.isNotEmpty ? servers.first.uri : "");
        subName = prefs.getString('subName') ?? "اشتراک ابری لنترن";
        savedSubUrl = prefs.getString('savedSubUrl') ?? "";
        usedGB = prefs.getDouble('usedGB') ?? 0.0;
        totalGB = prefs.getDouble('totalGB') ?? 0.0;
        expireTimestamp = prefs.getInt('expireTimestamp');
        routingMode = prefs.getInt('routingMode') ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'lantern_servers',
        servers.map((e) => jsonEncode(e.toJson())).toList(),
      );
      await prefs.setString('selectedServerUri', selectedServerUri);
      await prefs.setString('subName', subName);
      await prefs.setString('savedSubUrl', savedSubUrl);
      await prefs.setDouble('usedGB', usedGB);
      await prefs.setDouble('totalGB', totalGB);
      if (expireTimestamp != null) {
        await prefs.setInt('expireTimestamp', expireTimestamp!);
      } else {
        await prefs.remove('expireTimestamp');
      }
      await prefs.setInt('routingMode', routingMode);
    } catch (_) {}
  }

  String _detectFlag(String remark) {
    final up = remark.toUpperCase();
    for (var rune in remark.runes) {
      if (rune >= 0x1F1E6 && rune <= 0x1F1FF) return '🌐';
    }
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
    return '✦';
  }

  String _prepareCleanConfig(String rawJson, {bool useGeoFiles = true}) {
    try {
      final Map<String, dynamic> config = jsonDecode(rawJson);

      config['dns'] ??= {
        'servers': ['1.1.1.1', '8.8.8.8']
      };

      if (config['inbounds'] is List) {
        for (var inbound in config['inbounds']) {
          if (inbound is Map<String, dynamic>) {
            inbound['sniffing'] = {
              'enabled': true,
              'destOverride': ['http', 'tls']
            };
          }
        }
      }

      final List outbounds = (config['outbounds'] ??= <dynamic>[]) as List;
      if (outbounds.isEmpty) return rawJson;

      Map<String, dynamic>? proxyOutbound;
      for (var ob in outbounds) {
        if (ob is Map<String, dynamic> &&
            ob['protocol'] != 'freedom' &&
            ob['protocol'] != 'blackhole') {
          proxyOutbound = ob;
          break;
        }
      }
      proxyOutbound ??= outbounds.first as Map<String, dynamic>;

      if (routingMode == 0 || routingMode == 2) {
        if (!outbounds.any((o) => o is Map && o['tag'] == 'direct')) {
          outbounds.add({
            'tag': 'direct',
            'protocol': 'freedom',
            'settings': {'domainStrategy': 'UseIP'}
          });
        }

        final routing = (config['routing'] ??= <String, dynamic>{}) as Map<String, dynamic>;
        routing['domainStrategy'] = 'IPIfNonMatch';
        final rules = (routing['rules'] ??= <dynamic>[]) as List;

        rules.insert(0, {
          'type': 'field',
          'outboundTag': 'direct',
          'domain': [
            'regexp:.*\\.ir\$',
            'regexp:.*\\.xn--mgba3a4f16a\$',
            'domain:shaparak.ir',
            'domain:bmi.ir',
            'domain:mellat.ir',
            'domain:snapp.ir',
            'domain:digikala.com',
            'domain:aparat.com',
            'domain:divar.ir',
            'domain:torob.com',
            if (useGeoFiles) 'geosite:category-ir',
          ]
        });

        rules.insert(1, {
          'type': 'field',
          'outboundTag': 'direct',
          'ip': [
            '127.0.0.0/8',
            '10.0.0.0/8',
            '172.16.0.0/12',
            '192.168.0.0/16',
            if (useGeoFiles) 'geoip:ir',
          ]
        });
      }

      if (routingMode == 2) {
        final streamSettings =
            (proxyOutbound['streamSettings'] ??= <String, dynamic>{}) as Map<String, dynamic>;
        final existingSockopt =
            (streamSettings['sockopt'] ??= <String, dynamic>{}) as Map<String, dynamic>;
        existingSockopt['dialerProxy'] = 'fragment';
        existingSockopt['tcpNoDelay'] = true;

        if (!outbounds.any((o) => o is Map && o['tag'] == 'fragment')) {
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
      }

      return jsonEncode(config);
    } catch (_) {
      return rawJson;
    }
  }

  Future<void> _verifyConnectedInternetWithRetry() async {
    final int gen = ++_verifyGeneration;
    for (int attempt = 1; attempt <= 3; attempt++) {
      await Future.delayed(Duration(milliseconds: 900 * attempt));
      if (!mounted || gen != _verifyGeneration || v2rayStatus.state != 'CONNECTED') return;

      try {
        final delay = await flutterV2ray
            .getConnectedServerDelay()
            .timeout(const Duration(seconds: 4), onTimeout: () => -1);
        if (!mounted || gen != _verifyGeneration) return;
        if (delay > 0) {
          setState(() => realConnectedDelay = delay);
          return;
        }
      } catch (_) {}
    }

    if (mounted && gen == _verifyGeneration && v2rayStatus.state == 'CONNECTED') {
      setState(() => realConnectedDelay = -1);
    }
  }

  Future<void> _startConnection() async {
    if (servers.isEmpty) {
      _notify('ابتدا لینک اشتراک یا کانفیگ را کپی کرده و دکمه + بالا را بزنید.');
      return;
    }

    final server = servers[selectedIndex];
    selectedServerUri = server.uri;

    setState(() {
      isConnecting = true;
      realConnectedDelay = null;
    });

    _connectionWatchdog?.cancel();
    _connectionWatchdog = Timer(const Duration(seconds: 15), () async {
      if (mounted && isConnecting && v2rayStatus.state != 'CONNECTED') {
        setState(() => isConnecting = false);
        await flutterV2ray.stopV2Ray();
        _notify('زمان اتصال به پایان رسید (Timeout). سرور دیگری را امتحان کنید.');
      }
    });

    try {
      final hasPerm = await flutterV2ray.requestPermission();
      if (!hasPerm) {
        _connectionWatchdog?.cancel();
        if (mounted) setState(() => isConnecting = false);
        _notify('مجوز اتصال VPN در گوشی تایید نشد.');
        return;
      }

      final parsed = FlutterV2ray.parseFromURL(server.uri);
      final cleanConfig = _prepareCleanConfig(parsed.getFullConfiguration(), useGeoFiles: false);

      await flutterV2ray.startV2Ray(
        remark: parsed.remark.isNotEmpty ? parsed.remark : server.remark,
        config: cleanConfig,
        bypassSubnets: null,
      );
    } catch (_) {
      _connectionWatchdog?.cancel();
      if (mounted) setState(() => isConnecting = false);
      _notify('خطا در اجرای این کانفیگ. سرور بعدی را امتحان کنید.');
    }
  }

  Future<void> toggleConnection() async {
    HapticFeedback.mediumImpact();
    if (v2rayStatus.state == 'CONNECTED' || isConnecting) {
      _connectionWatchdog?.cancel();
      setState(() => isConnecting = false);
      await flutterV2ray.stopV2Ray();
      return;
    }
    await _startConnection();
  }

  Future<void> switchToNextHealthyServer() async {
    if (servers.length < 2) return;
    HapticFeedback.selectionClick();

    int nextIdx = (selectedIndex + 1) % servers.length;
    for (int i = 1; i < servers.length; i++) {
      final candidate = (selectedIndex + i) % servers.length;
      if (servers[candidate].ping > 0) {
        nextIdx = candidate;
        break;
      }
    }

    setState(() => selectedServerUri = servers[nextIdx].uri);
    _saveData();

    if (v2rayStatus.state == 'CONNECTED' || isConnecting) {
      await flutterV2ray.stopV2Ray();
      await Future.delayed(const Duration(milliseconds: 450));
    }
    await _startConnection();
  }

  Future<void> pingSingleServer(ServerItem item) async {
    if (!mounted) return;
    setState(() => item.testing = true);
    _sheetUpdater?.call();

    int pingVal = -2;
    try {
      final parser = FlutterV2ray.parseFromURL(item.uri);
      final cfg = _prepareCleanConfig(parser.getFullConfiguration(), useGeoFiles: false);
      pingVal = await flutterV2ray
          .getServerDelay(config: cfg)
          .timeout(const Duration(milliseconds: 4500), onTimeout: () => -2);
    } catch (_) {
      pingVal = -2;
    }

    if (!mounted) return;
    setState(() {
      item.ping = pingVal > 0 ? pingVal : -2;
      item.testing = false;
    });
    _sheetUpdater?.call();
  }

  Future<void> pingAllServers() async {
    if (servers.isEmpty || isTestingPings) return;
    HapticFeedback.lightImpact();
    setState(() => isTestingPings = true);
    _sheetUpdater?.call();

    final snapshot = List<ServerItem>.from(servers);
    const int batch = 5;
    for (int i = 0; i < snapshot.length; i += batch) {
      final end = (i + batch < snapshot.length) ? i + batch : snapshot.length;
      await Future.wait([for (int j = i; j < end; j++) pingSingleServer(snapshot[j])]);
    }

    if (!mounted) return;
    setState(() {
      servers.sort((a, b) {
        if (a.ping <= 0 && b.ping <= 0) return 0;
        if (a.ping <= 0) return 1;
        if (b.ping <= 0) return -1;
        return a.ping.compareTo(b.ping);
      });
      final currentStillHealthy =
          servers.any((s) => s.uri == selectedServerUri && s.ping > 0);
      if (!currentStillHealthy && v2rayStatus.state != 'CONNECTED') {
        final best = servers.firstWhere((s) => s.ping > 0, orElse: () => servers.first);
        selectedServerUri = best.uri;
      }
      isTestingPings = false;
    });
    _sheetUpdater?.call();
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

  String _decodeProfileTitle(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.toLowerCase().startsWith('base64:')) {
      try {
        return _robustBase64Decode(trimmed.substring(7));
      } catch (_) {}
    }
    try {
      return utf8.decode(latin1.encode(trimmed));
    } catch (_) {
      return trimmed;
    }
  }

  Future<void> importClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      _notify('کلیپ‌بورد خالی است!');
      return;
    }

    final text = data.text!.trim();
    if (text.startsWith('http://') || text.startsWith('https://')) {
      _notify('در حال دریافت اطلاعات اشتراک...');
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

        final addedCount = _addRawLinks(body, replace: true);
        if (addedCount > 0) {
          savedSubUrl = url;
          usedGB = 0.0;
          totalGB = 0.0;
          expireTimestamp = null;

          final info = res.headers['subscription-userinfo'];
          if (info != null) _parseUserInfo(info);

          final title = res.headers['profile-title'];
          subName = title != null && title.isNotEmpty
              ? _decodeProfileTitle(title)
              : Uri.parse(url).host;

          _saveData();
        }
      } else {
        _notify('خطا در دریافت لینک اشتراک (کد ${res.statusCode})');
      }
    } catch (_) {
      _notify('عدم دسترسی به سرور اشتراک. اینترنت را بررسی کنید.');
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

  String _formatExpireBadge() {
    if (expireTimestamp == null) return '${servers.length} سرور آماده';
    if (expireTimestamp == 0) return 'نامحدود ∞';
    final expDate = DateTime.fromMillisecondsSinceEpoch(expireTimestamp! * 1000);
    final diffHours = expDate.difference(DateTime.now()).inHours;
    if (diffHours < 0) return 'منقضی شده ⚠️';
    final days = (diffHours / 24).ceil();
    return '$days روز فعال';
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
            remark: p.remark.isNotEmpty
                ? p.remark
                : 'Server #${servers.length + parsedList.length + 1}',
            uri: link,
            protocol: _getProto(link),
          ));
        } catch (_) {}
      }
    }

    if (parsedList.isEmpty) {
      _notify('هیچ کانفیگ معتبری در لینک دریافتی پیدا نشد. سرورهای قبلی حفظ شدند.');
      return 0;
    }

    setState(() {
      if (replace) {
        servers = parsedList;
      } else {
        servers.insertAll(0, parsedList);
      }
      if (selectedServerUri.isEmpty || !servers.any((s) => s.uri == selectedServerUri)) {
        selectedServerUri = servers.first.uri;
      }
    });
    _saveData();
    _notify('✦ ${parsedList.length} سرور آماده شد. در حال تست پینگ واقعی...');
    pingAllServers();
    return parsedList.length;
  }

  String _formatSpeed(dynamic speed) {
    final int bytes = int.tryParse(speed.toString()) ?? 0;
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / 1048576).toStringAsFixed(2)} MB/s';
  }

  void _notify(String msg, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF141829),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: const Color(0xFFA87FFB).withOpacity(0.45)),
        ),
        duration: const Duration(seconds: 3),
        action: action,
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }

  void _openGlassServersSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            _sheetUpdater = () {
              if (context.mounted) setSheetState(() {});
            };
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0F1C).withOpacity(0.88),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(38)),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'سرورهای هوشمند (${servers.length})',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: isTestingPings ? null : () => pingAllServers(),
                                  icon: isTestingPings
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA87FFB)),
                                        )
                                      : const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFA87FFB)),
                                  label: const Text('تست پینگ واقعی', style: TextStyle(color: Color(0xFFA87FFB), fontSize: 12)),
                                ),
                                if (servers.any((s) => s.ping == -2))
                                  IconButton(
                                    tooltip: 'پاکسازی سرورهای بدون پینگ',
                                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18, color: Colors.amberAccent),
                                    onPressed: () {
                                      final backup = List<ServerItem>.from(servers);
                                      setState(() {
                                        servers.removeWhere((s) => s.ping == -2);
                                      });
                                      setSheetState(() {});
                                      _saveData();
                                      _notify(
                                        'سرورهای Timeout پاکسازی شدند.',
                                        action: SnackBarAction(
                                          label: 'بازگردانی',
                                          textColor: const Color(0xFF00F5D4),
                                          onPressed: () {
                                            setState(() => servers = backup);
                                            _sheetUpdater?.call();
                                            _saveData();
                                          },
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      Expanded(
                        child: servers.isEmpty
                            ? const Center(
                                child: Text(
                                  'لیست سرورها خالی است.\nلینک اشتراک یا کانفیگ را کپی کرده و دکمه + را بزنید.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.6),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: servers.length,
                                itemBuilder: (context, index) {
                                  final s = servers[index];
                                  final isSel = s.uri == selectedServerUri;

                                  Color pColor = const Color(0xFF00F5D4);
                                  if (s.ping > 300) pColor = const Color(0xFFFBBF24);
                                  if (s.ping <= 0 || s.ping > 700) pColor = const Color(0xFFF43F5E);

                                  return Dismissible(
                                    key: ValueKey('${s.uri}_$index'),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    ),
                                    onDismissed: (_) {
                                      final removed = s;
                                      setState(() => servers.removeAt(index));
                                      setSheetState(() {});
                                      _saveData();
                                      _notify(
                                        'سرور ${removed.remark} حذف شد.',
                                        action: SnackBarAction(
                                          label: 'بازگردانی',
                                          textColor: const Color(0xFF00F5D4),
                                          onPressed: () {
                                            setState(() => servers.insert(index.clamp(0, servers.length), removed));
                                            _sheetUpdater?.call();
                                            _saveData();
                                          },
                                        ),
                                      );
                                    },
                                    child: GestureDetector(
                                      onTap: () async {
                                        final wasConn = v2rayStatus.state == 'CONNECTED' || isConnecting;
                                        setState(() => selectedServerUri = s.uri);
                                        _saveData();
                                        Navigator.pop(context);
                                        if (wasConn) {
                                          await flutterV2ray.stopV2Ray();
                                          await Future.delayed(const Duration(milliseconds: 450));
                                          await _startConnection();
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                        decoration: BoxDecoration(
                                          gradient: isSel
                                              ? LinearGradient(
                                                  colors: [
                                                    const Color(0xFF4B90FF).withOpacity(0.24),
                                                    const Color(0xFFA87FFB).withOpacity(0.18),
                                                  ],
                                                )
                                              : null,
                                          color: isSel ? null : Colors.white.withOpacity(0.045),
                                          borderRadius: BorderRadius.circular(22),
                                          border: Border.all(
                                            color: isSel
                                                ? const Color(0xFFA87FFB).withOpacity(0.7)
                                                : Colors.white.withOpacity(0.08),
                                            width: isSel ? 1.4 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withOpacity(0.07),
                                                border: Border.all(color: Colors.white.withOpacity(0.14)),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  _detectFlag(s.remark),
                                                  style: const TextStyle(fontSize: 18),
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
                                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '${s.protocol} • بکشید به چپ برای حذف',
                                                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (s.testing)
                                              const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Color(0xFFA87FFB),
                                                ),
                                              )
                                            else ...[
                                              _buildSignalBars(s.ping),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => pingSingleServer(s),
                                                child: Text(
                                                  s.ping > 0 ? '${s.ping} ms' : (s.ping == -2 ? 'Timeout' : 'تست'),
                                                  style: TextStyle(
                                                    color: s.ping > 0 ? pColor : Colors.white38,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
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
            );
          },
        );
      },
    ).whenComplete(() => _sheetUpdater = null);
  }

  Widget _buildSignalBars(int ping) {
    int active = 0;
    Color col = Colors.white24;
    if (ping > 0 && ping < 180) {
      active = 4;
      col = const Color(0xFF00F5D4);
    } else if (ping >= 180 && ping < 320) {
      active = 3;
      col = const Color(0xFF4B90FF);
    } else if (ping >= 320 && ping < 600) {
      active = 2;
      col = const Color(0xFFFBBF24);
    } else if (ping >= 600) {
      active = 1;
      col = const Color(0xFFF43F5E);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 3,
          height: 4.0 + (i * 3.0),
          decoration: BoxDecoration(
            color: i < active ? col : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = v2rayStatus.state == 'CONNECTED';
    final ServerItem? currentServer = servers.isNotEmpty ? servers[selectedIndex] : null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isConnected ? const Color(0xFF00F5D4) : const Color(0xFF4B90FF))
                        .withOpacity(0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.28,
            left: -100,
            child: Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA87FFB).withOpacity(0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: 20,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF6B9D).withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Column(
                          children: [
                            _buildDynamicIsland(isConnected),
                            const SizedBox(height: 10),
                            _buildHeader(),
                            const SizedBox(height: 12),
                            _buildFrostedSubCard(),
                            const SizedBox(height: 10),
                            _buildSegmentedRoutingMode(),
                            const Spacer(),
                            const SizedBox(height: 14),
                            _buildGeminiLivingOrb(isConnected),
                            const SizedBox(height: 14),
                            const Spacer(),
                            _buildSparklineBentoRow(isConnected),
                            const SizedBox(height: 10),
                            _buildServerCapsule(currentServer, isConnected),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
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

  Widget _buildDynamicIsland(bool isConnected) {
    final String text = isConnecting
        ? 'CONNECTING TO XRAY...'
        : (isConnected
            ? 'PROTECTED • ${realConnectedDelay != null && realConnectedDelay! > 0 ? "$realConnectedDelay MS" : "TUNNEL ACTIVE"}'
            : 'XRAY CORE • STANDBY');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF090B14).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected
                  ? const Color(0xFF00F5D4)
                  : (isConnecting ? const Color(0xFFFBBF24) : Colors.white38),
              boxShadow: isConnected
                  ? [const BoxShadow(color: Color(0xFF00F5D4), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: Colors.white70,
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
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4B90FF).withOpacity(0.28),
                      const Color(0xFFA87FFB).withOpacity(0.28),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.20)),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFA87FFB), size: 19),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFC7D2FE), Color(0xFFF472B6)],
                  ).createShader(bounds),
                  child: const Text(
                    'Lantern',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (savedSubUrl.isNotEmpty) ...[
              _buildCircleGlassBtn(
                icon: Icons.sync_rounded,
                onTap: () => _fetchSub(savedSubUrl),
              ),
              const SizedBox(width: 8),
            ],
            _buildCircleGlassBtn(
              icon: isTestingPings ? Icons.hourglass_top_rounded : Icons.bolt_rounded,
              color: const Color(0xFFA87FFB),
              onTap: pingAllServers,
            ),
            const SizedBox(width: 8),
            _buildCircleGlassBtn(
              icon: Icons.add_rounded,
              color: const Color(0xFF4B90FF),
              onTap: importClipboard,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleGlassBtn({
    required IconData icon,
    Color color = Colors.white70,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.09), Colors.white.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
    );
  }

  Widget _buildFrostedSubCard() {
    final double progress = totalGB > 0 ? (usedGB / totalGB).clamp(0.0, 1.0) : 0.35;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFA87FFB), size: 15),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        subName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFA87FFB).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA87FFB).withOpacity(0.38)),
                ),
                child: Text(
                  _formatExpireBadge(),
                  style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5.5,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA87FFB)),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalGB > 0
                    ? 'مصرف شده: $usedGB GB'
                    : (servers.isEmpty ? 'کپی لینک و زدن + برای افزودن اشتراک' : 'مصرف: $usedGB GB'),
                style: const TextStyle(fontSize: 10.5, color: Colors.white60),
              ),
              Text(
                totalGB > 0 ? 'حجم کل: $totalGB GB' : 'حجم: نامحدود ∞',
                style: const TextStyle(fontSize: 10.5, color: Colors.white60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedRoutingMode() {
    final modes = ['هوشمند (ایران)', 'تونل کامل', 'ضد فیلتر ⚡'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.11)),
      ),
      child: Row(
        children: List.generate(modes.length, (i) {
          final active = routingMode == i;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                HapticFeedback.selectionClick();
                setState(() => routingMode = i);
                _saveData();
                if (v2rayStatus.state == 'CONNECTED') {
                  await flutterV2ray.stopV2Ray();
                  await Future.delayed(const Duration(milliseconds: 400));
                  await _startConnection();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withOpacity(0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: active ? Border.all(color: Colors.white.withOpacity(0.18)) : null,
                ),
                child: Text(
                  modes[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildGeminiLivingOrb(bool isConnected) {
    String statusTitle = 'آماده اتصال هوشمند';
    String statusSub = routingMode == 0
        ? 'عبور مستقیم سایت‌های بانکی و دامنه .ir'
        : (routingMode == 1 ? 'عبور ۱۰۰٪ ترافیک از تونل امن' : 'حالت Fragment ضد فیلترینگ فعال است');

    if (isConnecting) {
      statusTitle = 'در حال ایمن‌سازی تونل...';
      statusSub = 'برقراری ارتباط رمزنگاری‌شده با سرور';
    } else if (isConnected) {
      if (realConnectedDelay == -1) {
        statusTitle = 'متصل (بدون پاسخ از اینترنت)';
        statusSub = 'اگر اینترنت کند است، دکمه سوییچ زیر را بزنید';
      } else {
        statusTitle = 'اتصال شما کاملاً امن است';
        statusSub = realConnectedDelay != null
            ? 'پینگ واقعی تونل: $realConnectedDelay ms • بدون نشت DNS'
            : 'در حال سنجش کیفیت خط...';
      }
    }

    return Column(
      children: [
        GestureDetector(
          onTap: toggleConnection,
          child: SizedBox(
            width: 186,
            height: 186,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _auraController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _auraController.value * 2 * math.pi,
                      child: Container(
                        width: 174,
                        height: 174,
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
                              blurRadius: 34,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 154,
                  height: 154,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.35, -0.45),
                      radius: 1.1,
                      colors: [
                        Color(0xFF28314E),
                        Color(0xFF0E1324),
                        Color(0xFF070912),
                      ],
                    ),
                    border: Border.all(
                      color: isConnected
                          ? const Color(0xFF00F5D4).withOpacity(0.75)
                          : Colors.white.withOpacity(0.25),
                      width: 1.6,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isConnecting)
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFFA87FFB),
                          ),
                        )
                      else
                        Icon(
                          Icons.power_settings_new_rounded,
                          size: 48,
                          color: isConnected ? const Color(0xFF00F5D4) : Colors.white,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        isConnecting
                            ? 'HANDSHAKING'
                            : (isConnected ? 'PROTECTED' : 'TAP TO CONNECT'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
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
        const SizedBox(height: 14),
        Text(
          statusTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isConnected ? const Color(0xFF00F5D4) : Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          statusSub,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: Colors.white54),
        ),
        if (isConnected && realConnectedDelay == -1 && servers.length > 1) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4B90FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: switchToNextHealthyServer,
            icon: const Icon(Icons.skip_next_rounded, size: 18),
            label: const Text('سوییچ هوشمند به سرور سالم بعدی', style: TextStyle(fontSize: 12)),
          ),
        ],
      ],
    );
  }

  Widget _buildSparklineBentoRow(bool isConnected) {
    return Row(
      children: [
        Expanded(
          child: _buildBentoWaveCard(
            title: 'دانلود زنده',
            speed: isConnected ? _formatSpeed(v2rayStatus.downloadSpeed) : '0.0 KB/s',
            color: const Color(0xFF00F5D4),
            bars: dlHistory,
            active: isConnected,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildBentoWaveCard(
            title: 'آپلود زنده',
            speed: isConnected ? _formatSpeed(v2rayStatus.uploadSpeed) : '0.0 KB/s',
            color: const Color(0xFFA87FFB),
            bars: ulHistory,
            active: isConnected,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoWaveCard({
    required String title,
    required String speed,
    required Color color,
    required List<double> bars,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
              Icon(
                title.contains('دانلود') ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 13,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            speed,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (i) {
                final double h = active ? (bars[i] * 16).clamp(3.0, 16.0) : 3.5;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    height: h,
                    decoration: BoxDecoration(
                      color: active ? color.withOpacity(0.85) : Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCapsule(ServerItem? currentServer, bool isConnected) {
    return GestureDetector(
      onTap: _openGlassServersSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.09), Colors.white.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Center(
                child: Text(
                  currentServer != null ? _detectFlag(currentServer.remark) : '🌍',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentServer != null ? currentServer.remark : 'انتخاب یا افزودن سرور هوشمند',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    currentServer != null
                        ? '${currentServer.protocol} • زمان: ${isConnected ? v2rayStatus.duration : "00:00:00"}'
                        : 'لینک را کپی کرده و دکمه + بالا را بزنید',
                    style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                  ),
                ],
              ),
            ),
            if (currentServer != null) ...[
              _buildSignalBars(currentServer.ping),
              const SizedBox(width: 8),
              if (currentServer.ping > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5D4).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00F5D4).withOpacity(0.35)),
                  ),
                  child: Text(
                    '${currentServer.ping} ms',
                    style: const TextStyle(
                      color: Color(0xFF00F5D4),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
