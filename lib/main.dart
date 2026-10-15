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
