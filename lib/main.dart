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
      systemNavigationBarColor: Color(0xFF040711),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LanternProAndroidApp());
}

class LanternProAndroidApp extends StatelessWidget {
  const LanternProAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lantern 3D Spatial VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF040711),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0066FF),
          secondary: Color(0xFF00F5D4),
          surface: Color(0xFF0D1322),
        ),
      ),
      home: const CenteredQuickSplash(),
    );
  }
}

// ==================== ۱. استارت سریع و دقیقاً در مرکز صفحه ====================
class CenteredQuickSplash extends StatefulWidget {
  const CenteredQuickSplash({super.key});

  @override
  State<CenteredQuickSplash> createState() => _CenteredQuickSplashState();
}

class _CenteredQuickSplashState extends State<CenteredQuickSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    Timer(const Duration(milliseconds: 1150), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => const LanternSinglePageScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040711),
      body: SizedBox.expand(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0066FF), Color(0xFF00F5D4)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0066FF).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lantern 3D',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Android Luxury Edition',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF00F5D4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== ۲. پالت‌های تم نوری ====================
class NeonThemePalette {
  final String id;
  final String nameFa;
  final String nameEn;
  final Color primary;
  final Color secondary;
  final Color glow;

  const NeonThemePalette({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.primary,
    required this.secondary,
    required this.glow,
  });

  static const List<NeonThemePalette> palettes = [
    NeonThemePalette(
      id: 'cyber_blue',
      nameFa: 'آبی سایبری (Cyber Blue)',
      nameEn: 'Cyber Blue',
      primary: Color(0xFF0066FF),
      secondary: Color(0xFF00F5D4),
      glow: Color(0xFF38BDF8),
    ),
    NeonThemePalette(
      id: 'arcane_purple',
      nameFa: 'بنفش آرکین (Arcane Purple)',
      nameEn: 'Arcane Purple',
      primary: Color(0xFF8B5CF6),
      secondary: Color(0xFFEC4899),
      glow: Color(0xFFC084FC),
    ),
    NeonThemePalette(
      id: 'emerald_neon',
      nameFa: 'سبز زمردی (Emerald Neon)',
      nameEn: 'Emerald Neon',
      primary: Color(0xFF10B981),
      secondary: Color(0xFF00F5D4),
      glow: Color(0xFF34D399),
    ),
    NeonThemePalette(
      id: 'dark_gold',
      nameFa: 'طلایی لوکس (Dark Luxury Gold)',
      nameEn: 'Dark Luxury Gold',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFFDE047),
      glow: Color(0xFFFBBF24),
    ),
  ];
}

// ==================== ۳. مدل‌های اشتراک و سرور ====================
class SubscriptionGroup {
  final String id;
  String title;
  final String url;
  double usedGB;
  double totalGB;
  int? expireDays;

  SubscriptionGroup({
    required this.id,
    required this.title,
    required this.url,
    this.usedGB = 0.0,
    this.totalGB = 0.0,
    this.expireDays,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'usedGB': usedGB,
        'totalGB': totalGB,
        'expireDays': expireDays,
      };

  factory SubscriptionGroup.fromJson(Map<String, dynamic> json) =>
      SubscriptionGroup(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? 'Subscription',
        url: json['url']?.toString() ?? '',
        usedGB:
            (json['usedGB'] is num) ? (json['usedGB'] as num).toDouble() : 0.0,
        totalGB: (json['totalGB'] is num)
            ? (json['totalGB'] as num).toDouble()
            : 0.0,
        expireDays: json['expireDays'] is int ? json['expireDays'] : null,
      );
}

class VpnProfile {
  final String id;
  final String subId;
  final String name;
  final String rawUri;
  final String protocol;
  final String address;
  final int port;
  int ping; // -1: تست نشده | -2: خطا/تایم‌اوت | >0: پینگ معتبر
  int jitter;
  bool isPinging;

  VpnProfile({
    required this.id,
    required this.subId,
    required this.name,
    required this.rawUri,
    required this.protocol,
    required this.address,
    required this.port,
    this.ping = -1,
    this.jitter = 3,
    this.isPinging = false,
  });

  bool get isGameReady => ping > 0 && ping < 150;

  Map<String, dynamic> toJson() => {
        'id': id,
        'subId': subId,
        'name': name,
        'rawUri': rawUri,
        'protocol': protocol,
        'address': address,
        'port': port,
        'ping': ping,
        'jitter': jitter,
      };

  factory VpnProfile.fromJson(Map<String, dynamic> json) => VpnProfile(
        id: json['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        subId: json['subId']?.toString() ?? 'manual',
        name: json['name']?.toString() ?? 'Server',
        rawUri: json['rawUri']?.toString() ?? '',
        protocol: json['protocol']?.toString() ?? 'VLESS',
        address: json['address']?.toString() ?? '',
        port: int.tryParse(json['port']?.toString() ?? '443') ?? 443,
        ping: json['ping'] is int ? json['ping'] : -1,
        jitter: json['jitter'] is int ? json['jitter'] : 3,
      );
}

// ==================== ۴. نقاش پرچم وکتور واقعی برای ۳۵+ کشور ====================
class FlagPainter extends CustomPainter {
  final String rawName;
  FlagPainter(this.rawName);

  String _detectCode(String s) {
    final up = s.toUpperCase();
    if (up.contains('GERMANY') || up.contains(' DE') || up.startsWith('DE') || s.contains('آلمان') || s.contains('المان') || up.contains('FRANKFURT')) return 'de';
    if (up.contains('USA') || up.contains('UNITED STATES') || up.contains(' US') || up.startsWith('US') || s.contains('آمریکا') || s.contains('امریکا') || up.contains('WASHINGTON')) return 'us';
    if (up.contains('NETHERLANDS') || up.contains(' NL') || up.startsWith('NL') || s.contains('هلند') || up.contains('AMSTERDAM')) return 'nl';
    if (up.contains('FRANCE') || up.contains(' FR') || up.startsWith('FR') || s.contains('فرانسه') || up.contains('PARIS')) return 'fr';
    if (up.contains('SWEDEN') || up.contains(' SE') || up.startsWith('SE') || s.contains('سوئد')) return 'se';
    if (up.contains('FINLAND') || up.contains(' FI') || up.startsWith('FI') || s.contains('فنلاند') || up.contains('HELSINKI')) return 'fi';
    if (up.contains('UK') || up.contains('GB') || up.contains('BRITAIN') || up.contains('ENGLAND') || up.contains('LONDON') || s.contains('انگلیس')) return 'gb';
    if (up.contains('ROMANIA') || up.contains(' RO') || up.startsWith('RO') || s.contains('رومانی')) return 'ro';
    if (up.contains('INDIA') || up.contains(' IN') || up.startsWith('IN') || s.contains('هند')) return 'in';
    if (up.contains('EGYPT') || up.contains(' EG') || up.startsWith('EG') || s.contains('مصر')) return 'eg';
    if (up.contains('BULGARIA') || up.contains(' BG') || up.startsWith('BG') || s.contains('بلغارستان')) return 'bg';
    if (up.contains('TURKEY') || up.contains(' TR') || up.startsWith('TR') || s.contains('ترکیه') || up.contains('ISTANBUL')) return 'tr';
    if (up.contains('UAE') || up.contains('EMIRATES') || up.contains('DUBAI') || up.contains(' AE') || s.contains('امارات') || s.contains('دبی')) return 'ae';
    if (up.contains('SWISS') || up.contains('SWITZERLAND') || up.contains(' CH') || s.contains('سوئیس')) return 'ch';
    if (up.contains('CANADA') || up.contains(' CA') || s.contains('کانادا')) return 'ca';
    if (up.contains('RUSSIA') || up.contains(' RU') || s.contains('روسیه') || up.contains('MOSCOW')) return 'ru';
    if (up.contains('ITALY') || up.contains(' IT') || s.contains('ایتالیا')) return 'it';
    if (up.contains('SPAIN') || up.contains(' ES') || s.contains('اسپانیا')) return 'es';
    if (up.contains('POLAND') || up.contains(' PL') || s.contains('لهستان')) return 'pl';
    if (up.contains('AUSTRIA') || up.contains(' AT') || s.contains('اتریش')) return 'at';
    if (up.contains('JAPAN') || up.contains(' JP') || s.contains('ژاپن') || up.contains('TOKYO')) return 'jp';
    if (up.contains('SINGAPORE') || up.contains(' SG') || s.contains('سنگاپور')) return 'sg';
    if (up.contains('IRAN') || up.contains(' IR') || s.contains('ایران') || s.contains('ملی')) return 'ir';
    return 'global';
  }

  void _hStripes(Canvas c, Size s, Color c1, Color c2, Color c3) {
    final p = Paint();
    p.color = c1; c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height / 3), p);
    p.color = c2; c.drawRect(Rect.fromLTWH(0, s.height / 3, s.width, s.height / 3), p);
    p.color = c3; c.drawRect(Rect.fromLTWH(0, s.height * 2 / 3, s.width, s.height / 3), p);
  }

  void _vStripes(Canvas c, Size s, Color c1, Color c2, Color c3) {
    final p = Paint();
    p.color = c1; c.drawRect(Rect.fromLTWH(0, 0, s.width / 3, s.height), p);
    p.color = c2; c.drawRect(Rect.fromLTWH(s.width / 3, 0, s.width / 3, s.height), p);
    p.color = c3; c.drawRect(Rect.fromLTWH(s.width * 2 / 3, 0, s.width / 3, s.height), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(5));
    canvas.clipRRect(rrect);
    final code = _detectCode(rawName);
    final paint = Paint()..style = PaintingStyle.fill;

    switch (code) {
      case 'de': _hStripes(canvas, size, const Color(0xFF141414), const Color(0xFFDD0000), const Color(0xFFFFCE00)); break;
      case 'nl': _hStripes(canvas, size, const Color(0xFFAE1C28), Colors.white, const Color(0xFF21468B)); break;
      case 'fr': _vStripes(canvas, size, const Color(0xFF002395), Colors.white, const Color(0xFFED2939)); break;
      case 'ro': _vStripes(canvas, size, const Color(0xFF002B7F), const Color(0xFFFCD116), const Color(0xFFCE1126)); break;
      case 'it': _vStripes(canvas, size, const Color(0xFF009246), Colors.white, const Color(0xFFCE2B37)); break;
      case 'bg': _hStripes(canvas, size, Colors.white, const Color(0xFF00966E), const Color(0xFFD62612)); break;
      case 'ru': _hStripes(canvas, size, Colors.white, const Color(0xFF0039A6), const Color(0xFFD52B1E)); break;
      case 'at': _hStripes(canvas, size, const Color(0xFFED2939), Colors.white, const Color(0xFFED2939)); break;
      case 'in':
        _hStripes(canvas, size, const Color(0xFFFF9933), Colors.white, const Color(0xFF138808));
        paint.color = const Color(0xFF000080);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.14, paint);
        break;
      case 'eg':
        _hStripes(canvas, size, const Color(0xFFCE1126), Colors.white, const Color(0xFF000000));
        paint.color = const Color(0xFFC09300);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.12, paint);
        break;
      case 'ir': _hStripes(canvas, size, const Color(0xFF239F40), Colors.white, const Color(0xFFDA0000)); break;
      case 'se':
        paint.color = const Color(0xFF006AA7); canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFFFECC02);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.14, size.height), paint);
        break;
      case 'fi':
        paint.color = Colors.white; canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFF003580);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.38, size.width, size.height * 0.24), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.28, 0, size.width * 0.16, size.height), paint);
        break;
      case 'ch':
        paint.color = const Color(0xFFD52B1E); canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height * 0.42, size.width * 0.5, size.height * 0.16), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.42, size.height * 0.2, size.width * 0.16, size.height * 0.6), paint);
        break;
      case 'us':
        paint.color = const Color(0xFFBF0A30); canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        for (int i = 1; i < 7; i += 2) {
          canvas.drawRect(Rect.fromLTWH(0, i * size.height / 7, size.width, size.height / 7), paint);
        }
        paint.color = const Color(0xFF002868);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.46, size.height * 0.55), paint);
        break;
      case 'gb':
        paint.color = const Color(0xFF012169); canvas.drawRect(Offset.zero & size, paint);
        final diag = Paint()..color = Colors.white..strokeWidth = 3.5;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), diag);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), diag);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.35, size.width, size.height * 0.3), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.38, 0, size.width * 0.24, size.height), paint);
        paint.color = const Color(0xFFC8102E);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.41, size.width, size.height * 0.18), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.43, 0, size.width * 0.14, size.height), paint);
        break;
      case 'tr':
        paint.color = const Color(0xFFE30A17); canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.5), size.height * 0.28, paint);
        paint.color = const Color(0xFFE30A17);
        canvas.drawCircle(Offset(size.width * 0.48, size.height * 0.5), size.height * 0.22, paint);
        break;
      case 'ae':
        _hStripes(canvas, size, const Color(0xFF00732F), Colors.white, const Color(0xFF000000));
        paint.color = const Color(0xFFFF0000);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.28, size.height), paint);
        break;
      case 'ca':
        _vStripes(canvas, size, const Color(0xFFFF0000), Colors.white, const Color(0xFFFF0000));
        paint.color = const Color(0xFFFF0000);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.18, paint);
        break;
      case 'jp':
        paint.color = Colors.white; canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFFBC002D);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.28, paint);
        break;
      case 'pl':
        paint.color = Colors.white; canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), paint);
        paint.color = const Color(0xFFDC143C); canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2), paint);
        break;
      case 'sg':
        paint.color = const Color(0xFFEF3340); canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), paint);
        paint.color = Colors.white; canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2), paint);
        break;
      case 'es': _hStripes(canvas, size, const Color(0xFFAA151B), const Color(0xFFF1BF00), const Color(0xFFAA151B)); break;
      default:
        paint.shader = const LinearGradient(colors: [Color(0xFF0066FF), Color(0xFF00F5D4)]).createShader(Offset.zero & size);
        canvas.drawRect(Offset.zero & size, paint);
        final linePaint = Paint()..color = Colors.white.withOpacity(0.55)..style = PaintingStyle.stroke..strokeWidth = 1.1;
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.34, linePaint);
        canvas.drawLine(Offset(size.width * 0.2, size.height / 2), Offset(size.width * 0.8, size.height / 2), linePaint);
    }

    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.32), Colors.transparent, Colors.black.withOpacity(0.25)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, gloss);
  }

  @override
  bool shouldRepaint(covariant FlagPainter oldDelegate) => oldDelegate.rawName != rawName;
}

// ==================== ۵. ماتریس QR Code و ذرات معلق جمینای ====================
class VisualQrMatrixPainter extends CustomPainter {
  final String data;
  final Color color;
  VisualQrMatrixPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const int grid = 21;
    final double cell = size.width / grid;
    final Paint p = Paint()..color = color..style = PaintingStyle.fill;

    void drawFinder(int ox, int oy) {
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          if (r == 0 || r == 6 || c == 0 || c == 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4)) {
            canvas.drawRect(Rect.fromLTWH((ox + c) * cell, (oy + r) * cell, cell, cell), p);
          }
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(grid - 7, 0);
    drawFinder(0, grid - 7);

    final rnd = math.Random(data.hashCode);
    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) {
        final bool inFinder = (r < 8 && c < 8) || (r < 8 && c >= grid - 8) || (r >= grid - 8 && c < 8);
        if (!inFinder && rnd.nextBool()) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(c * cell + 0.5, r * cell + 0.5, cell - 1, cell - 1), const Radius.circular(1.5)),
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StardustParticle {
  double x, y, vx, vy, radius, alpha;
  Color color;
  StardustParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.color,
    required this.alpha,
  });
}

class GeminiParticlePainter extends CustomPainter {
  final List<StardustParticle> particles;
  final double progress;
  final bool isConnected, isGaming;
  final Offset touchPos;
  final NeonThemePalette palette;

  GeminiParticlePainter({
    required this.
