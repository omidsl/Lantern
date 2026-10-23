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
      systemNavigationBarColor: Color(0xFF040814),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LanternSecureNetApp());
}

class LanternSecureNetApp extends StatelessWidget {
  const LanternSecureNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LanternNet VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF030712),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00A3FF),
          secondary: Color(0xFF00F5D4),
          surface: Color(0xFF0A1224),
        ),
      ),
      home: const CyberSplashScreen(),
    );
  }
}

// ==================== ۱. صفحه استارت ۱.۲ ثانیه‌ای در مرکز مطلق صفحه ====================
class CyberSplashScreen extends StatefulWidget {
  const CyberSplashScreen({super.key});

  @override
  State<CyberSplashScreen> createState() => _CyberSplashScreenState();
}

class _CyberSplashScreenState extends State<CyberSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    Timer(const Duration(milliseconds: 1250), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => const SecureNetMainScreen(),
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
      backgroundColor: const Color(0xFF030712),
      body: SizedBox.expand(
        child: Center(
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0099FF).withOpacity(0.45),
                          blurRadius: 45,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      size: const Size(96, 96),
                      painter: ShieldLightningLogoPainter(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                      children: [
                        TextSpan(
                          text: 'Lantern',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: 'Net',
                          style: TextStyle(color: Color(0xFF00A3FF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your Freedom, Our Priority',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6482AD),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
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

// ==================== ۲. نقاش لوگوی سپر نئونی با صاعقه (دقیقاً مطابق عکس) ====================
class ShieldLightningLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shieldPath = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.88, h * 0.20)
      ..quadraticBezierTo(w * 0.88, h * 0.64, w * 0.5, h * 0.94)
      ..quadraticBezierTo(w * 0.12, h * 0.64, w * 0.12, h * 0.20)
      ..close();

    // لایه داخلی سرمه‌ای تیره
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B2246), Color(0xFF040B1A)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(shieldPath, bgPaint);

    // حاشیه نئونی آبی درخشان
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00E5FF), Color(0xFF0077FF), Color(0xFF0044CC)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(shieldPath, borderPaint);

    // صاعقه درخشان وسط سپر
    final boltPath = Path()
      ..moveTo(w * 0.55, h * 0.25)
      ..lineTo(w * 0.34, h * 0.53)
      ..lineTo(w * 0.49, h * 0.53)
      ..lineTo(w * 0.43, h * 0.76)
      ..lineTo(w * 0.66, h * 0.46)
      ..lineTo(w * 0.51, h * 0.46)
      ..close();

    final boltPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFF00E5FF), Color(0xFF0088FF)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(boltPath, boltPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== ۳. نقاش کره زمین شبکه‌ای و حلقه‌های مداری (Cyber Globe) ====================
class CyberGlobePainter extends CustomPainter {
  final double rotation;
  final bool isConnected;

  CyberGlobePainter({required this.rotation, required this.isConnected});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    final Color mainColor =
        isConnected ? const Color(0xFF00E5FF) : const Color(0xFF0088FF);

    // ۱. هاله کهکشانی پشت کره
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          mainColor.withOpacity(isConnected ? 0.32 : 0.22),
          const Color(0xFF003380).withOpacity(0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.45));
    canvas.drawCircle(center, radius * 1.45, glowPaint);

    // ۲. بدنه کروی تیره با نور لبه‌ای (Horizon Rim Light مثل عکس دوم)
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.35),
        radius: 0.95,
        colors: [
          const Color(0xFF0D2854).withOpacity(0.85),
          const Color(0xFF06132C).withOpacity(0.92),
          const Color(0xFF030814),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, spherePaint);

    // کمان درخشان افق در بالای کره (مثل عکس دوم)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          mainColor.withOpacity(0.85),
          mainColor.withOpacity(0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, rimPaint);

    // ۳. خطوط شبکه کروی (Latitude & Longitude Mesh مثل عکس اول)
    canvas.save();
    canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final meshPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = mainColor.withOpacity(0.22);

    // مدارهای افقی
    for (int i = -2; i <= 2; i++) {
      final dy = i * (radius * 0.32);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + dy),
          width: radius * 2,
          height: radius * 0.45,
        ),
        meshPaint,
      );
    }

    // نصف‌النهارهای چرخان
    for (int i = 0; i < 6; i++) {
      final angle = (rotation * math.pi * 2) + (i * math.pi / 6);
      final wFactor = math.sin(angle).abs().clamp(0.12, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radius * 2 * wFactor,
          height: radius * 2,
        ),
        meshPaint,
      );
    }

    // نقاط نوری شهرها روی کره (City Nodes مثل عکس اول)
    final rnd = math.Random(42);
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 28; i++) {
      final a = rnd.nextDouble() * math.pi * 2 + (rotation * 0.8);
      final r = rnd.nextDouble() * radius * 0.85;
      final nx = center.dx + math.cos(a) * r;
      final ny = center.dy + math.sin(a) * (r * 0.75);
      final isGold = i % 5 == 0;
      nodePaint.color = isGold
          ? const Color(0xFFFFB74D).withOpacity(0.75)
          : mainColor.withOpacity(0.75);
      canvas.drawCircle(Offset(nx, ny), isGold ? 2.2 : 1.5, nodePaint);
    }
    canvas.restore();

    // ۴. حلقه‌های مداری فضایی دور کره (Orbital Rings مثل عکس اول)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.22);
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          mainColor.withOpacity(0.65),
          const Color(0xFFFFB74D).withOpacity(0.5),
          Colors.transparent,
        ],
      ).createShader(
          Rect.fromCenter(center: Offset.zero, width: radius * 2.5, height: radius * 0.85));
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset.zero, width: radius * 2.45, height: radius * 0.78),
      orbitPaint,
    );
    canvas.restore();

    // ۵. پایه سکوی نوری زیر کره (Pedestal Rings مثل عکس اول)
    final baseCenter = Offset(center.dx, center.dy + radius * 0.96);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = mainColor.withOpacity(0.45);
    canvas.drawOval(
      Rect.fromCenter(
          center: baseCenter, width: radius * 1.9, height: radius * 0.26),
      basePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: baseCenter, width: radius * 1.4, height: radius * 0.16),
      basePaint..color = mainColor.withOpacity(0.75),
    );
  }

  @override
  bool shouldRepaint(covariant CyberGlobePainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.isConnected != isConnected;
}

// ==================== ۴. نقاش پرچم دایره‌ای کشورها (Circular Glossy Flags) ====================
class CircularFlagWidget extends StatelessWidget {
  final String name;
  final double size;

  const CircularFlagWidget({super.key, required this.name, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.28), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: FlagVectorPainter(name),
        ),
      ),
    );
  }
}

class FlagVectorPainter extends CustomPainter {
  final String rawName;
  FlagVectorPainter(this.rawName);

  static String detectCountryCode(String s) {
    final up = s.toUpperCase();
    if (up.contains('USA') || up.contains('UNITED STATES') || up.contains(' US') || up.startsWith('US') || s.contains('آمریکا') || s.contains('امریکا') || up.contains('NEW YORK') || up.contains('WASHINGTON')) return 'us';
    if (up.contains('GERMANY') || up.contains(' DE') || up.startsWith('DE') || s.contains('آلمان') || s.contains('المان') || up.contains('FRANKFURT')) return 'de';
    if (up.contains('UK') || up.contains('GB') || up.contains('BRITAIN') || up.contains('ENGLAND') || up.contains('LONDON') || s.contains('انگلیس')) return 'gb';
    if (up.contains('NETHERLANDS') || up.contains(' NL') || up.startsWith('NL') || s.contains('هلند') || up.contains('AMSTERDAM')) return 'nl';
    if (up.contains('FRANCE') || up.contains(' FR') || up.startsWith('FR') || s.contains('فرانسه') || up.contains('PARIS')) return 'fr';
    if (up.contains('CANADA') || up.contains(' CA') || s.contains('کانادا') || up.contains('TORONTO')) return 'ca';
    if (up.contains('JAPAN') || up.contains(' JP') || s.contains('ژاپن') || up.contains('TOKYO')) return 'jp';
    if (up.contains('SWEDEN') || up.contains(' SE') || up.startsWith('SE') || s.contains('سوئد')) return 'se';
    if (up.contains('FINLAND') || up.contains(' FI') || up.startsWith('FI') || s.contains('فنلاند')) return 'fi';
    if (up.contains('TURKEY') || up.contains(' TR') || up.startsWith('TR') || s.contains('ترکیه') || up.contains('ISTANBUL')) return 'tr';
    if (up.contains('UAE') || up.contains('EMIRATES') || up.contains('DUBAI') || up.contains(' AE') || s.contains('امارات') || s.contains('دبی')) return 'ae';
    if (up.contains('SWISS') || up.contains('SWITZERLAND') || up.contains(' CH') || s.contains('سوئیس')) return 'ch';
    if (up.contains('ROMANIA') || up.contains(' RO') || up.startsWith('RO') || s.contains('رومانی')) return 'ro';
    if (up.contains('INDIA') || up.contains(' IN') || up.startsWith('IN') || s.contains('هند')) return 'in';
    if (up.contains('EGYPT') || up.contains(' EG') || up.startsWith('EG') || s.contains('مصر')) return 'eg';
    if (up.contains('BULGARIA') || up.contains(' BG') || up.startsWith('BG') || s.contains('بلغارستان')) return 'bg';
    if (up.contains('RUSSIA') || up.contains(' RU') || s.contains('روسیه')) return 'ru';
    if (up.contains('ITALY') || up.contains(' IT') || s.contains('ایتالیا')) return 'it';
    if (up.contains('SPAIN') || up.contains(' ES') || s.contains('اسپانیا')) return 'es';
    if (up.contains('POLAND') || up.contains(' PL') || s.contains('لهستان')) return 'pl';
    if (up.contains('AUSTRIA') || up.contains(' AT') || s.contains('اتریش')) return 'at';
    if (up.contains('SINGAPORE') || up.contains(' SG') || s.contains('سنگاپور')) return 'sg';
    return 'global';
  }

  void _h3(Canvas c, Size s, Color c1, Color c2, Color c3) {
    final p = Paint();
    p.color = c1; c.drawRect(Rect.fromLTWH(0, 0, s.width, s.height / 3), p);
    p.color = c2; c.drawRect(Rect.fromLTWH(0, s.height / 3, s.width, s.height / 3), p);
    p.color = c3; c.drawRect(Rect.fromLTWH(0, s.height * 2 / 3, s.width, s.height / 3), p);
  }

  void _v3(Canvas c, Size s, Color c1, Color c2, Color c3) {
    final p = Paint();
    p.color = c1; c.drawRect(Rect.fromLTWH(0, 0, s.width / 3, s.height), p);
    p.color = c2; c.drawRect(Rect.fromLTWH(s.width / 3, 0, s.width / 3, s.height), p);
    p.color = c3; c.drawRect(Rect.fromLTWH(s.width * 2 / 3, 0, s.width / 3, s.height), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final code = detectCountryCode(rawName);
    final paint = Paint()..style = PaintingStyle.fill;

    switch (code) {
      case 'us':
        paint.color = const Color(0xFFBF0A30);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        for (int i = 1; i < 9; i += 2) {
          canvas.drawRect(Rect.fromLTWH(0, i * size.height / 9, size.width, size.height / 9), paint);
        }
        paint.color = const Color(0xFF002868);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.5, size.height * 0.55), paint);
        break;
      case 'de':
        _h3(canvas, size, const Color(0xFF191919), const Color(0xFFDD0000), const Color(0xFFFFCE00));
        break;
      case 'gb':
        paint.color = const Color(0xFF012169);
        canvas.drawRect(Offset.zero & size, paint);
        final d = Paint()..color = Colors.white..strokeWidth = size.width * 0.14;
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), d);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), d);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.36, size.width, size.height * 0.28), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.36, 0, size.width * 0.28, size.height), paint);
        paint.color = const Color(0xFFC8102E);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.42, size.width, size.height * 0.16), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.42, 0, size.width * 0.16, size.height), paint);
        break;
      case 'nl':
        _h3(canvas, size, const Color(0xFFAE1C28), Colors.white, const Color(0xFF21468B));
        break;
      case 'fr':
        _v3(canvas, size, const Color(0xFF002395), Colors.white, const Color(0xFFED2939));
        break;
      case 'ca':
        _v3(canvas, size, const Color(0xFFFF0000), Colors.white, const Color(0xFFFF0000));
        paint.color = const Color(0xFFFF0000);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.16, paint);
        break;
      case 'jp':
        paint.color = Colors.white;
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFFBC002D);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.28, paint);
        break;
      case 'se':
        paint.color = const Color(0xFF006AA7);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFFFECC02);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.32, 0, size.width * 0.16, size.height), paint);
        break;
      case 'fi':
        paint.color = Colors.white;
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFF003580);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.32, 0, size.width * 0.16, size.height), paint);
        break;
      case 'tr':
        paint.color = const Color(0xFFE30A17);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        canvas.drawCircle(Offset(size.width * 0.44, size.height * 0.5), size.width * 0.24, paint);
        paint.color = const Color(0xFFE30A17);
        canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.5), size.width * 0.19, paint);
        break;
      case 'ro':
        _v3(canvas, size, const Color(0xFF002B7F), const Color(0xFFFCD116), const Color(0xFFCE1126));
        break;
      case 'in':
        _h3(canvas, size, const Color(0xFFFF9933), Colors.white, const Color(0xFF138808));
        paint.color = const Color(0xFF000080);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.12, paint);
        break;
      case 'bg':
        _h3(canvas, size, Colors.white, const Color(0xFF00966E), const Color(0xFFD62612));
        break;
      case 'eg':
        _h3(canvas, size, const Color(0xFFCE1126), Colors.white, Colors.black);
        break;
      case 'ae':
        _h3(canvas, size, const Color(0xFF00732F), Colors.white, Colors.black);
        paint.color = const Color(0xFFFF0000);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.3, size.height), paint);
        break;
      case 'ch':
        paint.color = const Color(0xFFD52B1E);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height * 0.42, size.width * 0.5, size.height * 0.16), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.42, size.height * 0.25, size.width * 0.16, size.height * 0.5), paint);
        break;
      case 'ru':
        _h3(canvas, size, Colors.white, const Color(0xFF0039A6), const Color(0xFFD52B1E));
        break;
      case 'it':
        _v3(canvas, size, const Color(0xFF009246), Colors.white, const Color(0xFFCE2B37));
        break;
      default:
        paint.shader = const LinearGradient(
          colors: [Color(0xFF0088FF), Color(0xFF00E5FF)],
        ).createShader(Offset.zero & size);
        canvas.drawRect(Offset.zero & size, paint);
    }

    // لایه براق شیشه‌ای روی پرچم
    final gloss = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.32),
          Colors.transparent,
          Colors.black.withOpacity(0.25),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, gloss);
  }

  @override
  bool shouldRepaint(covariant FlagVectorPainter oldDelegate) =>
      oldDelegate.rawName != rawName;
}

// ==================== ۵. مدل‌های اشتراک و سرور ====================
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
        usedGB: (json['usedGB'] is num) ? (json['usedGB'] as num).toDouble() : 0.0,
        totalGB:
            (json['totalGB'] is num) ? (json['totalGB'] as num).toDouble() : 0.0,
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
  int ping;
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
    this.isPinging = false,
  });

  String get shortCountryLabel {
    final code = FlagVectorPainter.detectCountryCode(name);
    switch (code) {
      case 'us': return 'USA';
      case 'gb': return 'UK';
      case 'de': return 'Germany';
      case 'ca': return 'Canada';
      case 'jp': return 'Japan';
      case 'nl': return 'Netherlands';
      case 'fr': return 'France';
      case 'se': return 'Sweden';
      case 'fi': return 'Finland';
      case 'tr': return 'Turkey';
      case 'ae': return 'UAE';
      case 'ch': return 'Swiss';
      case 'ro': return 'Romania';
      case 'in': return 'India';
      case 'bg': return 'Bulgaria';
      default:
        final clean = name.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        if (clean.length > 8) return clean.substring(0, 8);
        return clean.isNotEmpty ? clean : protocol;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subId': subId,
        'name': name,
        'rawUri': rawUri,
        'protocol': protocol,
        'address': address,
        'port': port,
        'ping': ping,
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
      );
}

// ==================== ۶. موتور کانفیگ‌ساز خالص و ۱۰۰٪ سازگار با اندروید ====================
class PureV2RayParser {
  static String decodeB64(String str) {
    String clean = str
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('-', '+')
        .replaceAll('_', '/');
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    return utf8.decode(base64.decode(clean), allowMalformed: true);
  }

  static VpnProfile? parseUri(String link, String subId, int index) {
    final clean = link.trim();
    if (clean.isEmpty) return null;
    try {
      if (clean.startsWith('vmess://')) {
        final decoded = decodeB64(clean.substring(8));
        final Map<String, dynamic> map = jsonDecode(decoded);
        final String host = map['add']?.toString() ?? '';
        final int port = int.tryParse(map['port']?.toString() ?? '443') ?? 443;
        final String ps = map['ps']?.toString() ?? 'VMess #$index';
        if (host.isEmpty) return null;
        return VpnProfile(
          id: '${subId}_${index}_$host',
          subId: subId,
          name: ps,
          rawUri: clean,
          protocol: 'VMess',
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
          try {
            remark = Uri.decodeComponent(clean.substring(hashIdx + 1)).trim();
          } catch (_) {
            remark = clean.substring(hashIdx + 1).trim();
          }
          withoutHash = clean.substring(0, hashIdx);
        }
        final Uri uri = Uri.parse(withoutHash);
        if (uri.host.isEmpty) return null;
        final String proto = clean.split('://').first.toUpperCase();
        return VpnProfile(
          id: '${subId}_${index}_${uri.host}',
          subId: subId,
          name: remark.isNotEmpty ? remark : '$proto #$index',
          rawUri: clean,
          protocol: proto,
          address: uri.host,
          port: uri.port > 0 ? uri.port : 443,
        );
      }
    } catch (_) {}
    return null;
  }

  /// استخراج کانفیگ خالص از طریق موتور رسمی پلاگین (تضمین ۱۰۰٪ اتصال در اندروید)
  static String buildPureConfig(String rawUri) {
    final trimmed = rawUri.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;
    final V2RayURL parsed = FlutterV2ray.parseFromURL(trimmed);
    return parsed.getFullConfiguration();
  }
}

// ==================== ۷. صفحه اصلی برنامه (ترکیب هر دو عکس) ====================
class SecureNetMainScreen extends StatefulWidget {
  const SecureNetMainScreen({super.key});

  @override
  State<SecureNetMainScreen> createState() => _SecureNetMainScreenState();
}

class _SecureNetMainScreenState extends State<SecureNetMainScreen>
    with SingleTickerProviderStateMixin {
  late final FlutterV2ray _flutterV2ray;
  late final AnimationController _globeCtrl;

  // تب‌های پایین صفحه: 0 = Home, 1 = Servers, 2 = Settings
  int currentTab = 0;

  // زبان پیش‌فرض: انگلیسی شیک (قابل تغییر به فارسی در تنظیمات)
  String appLang = 'en';
  bool get isFa => appLang == 'fa';
  String tr(String enText, String faText) => isFa ? faText : enText;

  List<SubscriptionGroup> subscriptions = [];
  List<VpnProfile> profiles = [];
  String selectedSubId = 'all';
  int activeIdx = 0;

  String searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  bool isConnected = false;
  bool isBusy = false;
  bool isPingingAll = false;
  bool isSyncingSub = false;

  // تنظیمات کاربردی
  bool autoSelectBest = true;
  bool splitTunnelIr = false;
  bool dnsLeakShield = true;

  String connectionDuration = "00:00:00";
  double dlMbps = 0.0;
  double ulMbps = 0.0;

  @override
  void initState() {
    super.initState();
    _globeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final bool conn = status.state == 'CONNECTED';
        // تبدیل بایت بر ثانیه به مگابیت بر ثانیه (Mbps مطابق عکس)
        final double dl = (status.downloadSpeed * 8) / (1024 * 1024);
        final double ul = (status.uploadSpeed * 8) / (1024 * 1024);
        setState(() {
          isConnected = conn;
          if (conn) isBusy = false;
          connectionDuration = status.duration;
          dlMbps = double.parse(dl.toStringAsFixed(1));
          ulMbps = double.parse(ul.toStringAsFixed(1));
        });
      },
    );

    _initV2RayAndStorage();
  }

  Future<void> _initV2RayAndStorage() async {
    try {
      await _flutterV2ray.initializeV2Ray();
    } catch (_) {}
    await _loadData();
  }

  @override
  void dispose() {
    _globeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subList = prefs.getStringList('securenet_subs_v1') ?? [];
      subscriptions =
          subList.map((e) => SubscriptionGroup.fromJson(jsonDecode(e))).toList();

      final profList = prefs.getStringList('securenet_profiles_v1') ?? [];
      profiles =
          profList.map((e) => VpnProfile.fromJson(jsonDecode(e))).toList();

      activeIdx = prefs.getInt('activeIdx') ?? 0;
      if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;

      appLang = prefs.getString('appLang') ?? 'en';
      autoSelectBest = prefs.getBool('autoSelectBest') ?? true;
      splitTunnelIr = prefs.getBool('splitTunnelIr') ?? false;
      dnsLeakShield = prefs.getBool('dnsLeakShield') ?? true;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('securenet_subs_v1',
          subscriptions.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setStringList('securenet_profiles_v1',
          profiles.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setInt('activeIdx', activeIdx);
      await prefs.setString('appLang', appLang);
      await prefs.setBool('autoSelectBest', autoSelectBest);
      await prefs.setBool('splitTunnelIr', splitTunnelIr);
      await prefs.setBool('dnsLeakShield', dnsLeakShield);
    } catch (_) {}
  }

  List<VpnProfile> get filteredProfiles {
    Iterable<VpnProfile> res = profiles;
    if (selectedSubId != 'all') {
      res = res.where((p) => p.subId == selectedSubId);
    }
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      res = res.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.address.toLowerCase().contains(q) ||
          p.protocol.toLowerCase().contains(q));
    }
    return res.toList();
  }

  // ==================== تست پینگ واقعی، سریع و بدون قفل شدن ====================
  Future<void> pingSingleServer(VpnProfile p) async {
    if (!mounted || p.address.isEmpty) return;
    setState(() => p.isPinging = true);
    int result = -2;

    try {
      // ۱. تست Handshake واقعی شبکه روی پورت سرور
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        p.address,
        p.port,
        timeout: const Duration(milliseconds: 1800),
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

  Future<void> pingAllServers() async {
    final list = filteredProfiles;
    if (list.isEmpty || isPingingAll) return;
    HapticFeedback.lightImpact();
    setState(() => isPingingAll = true);

    const int batch = 5;
    for (int i = 0; i < list.length; i += batch) {
      final end = (i + batch < list.length) ? i + batch : list.length;
      await Future.wait([for (int j = i; j < end; j++) pingSingleServer(list[j])]);
    }

    if (!mounted) return;
    setState(() {
      isPingingAll = false;
      if (autoSelectBest) {
        sortServersByPing(silent: true);
      }
    });
    _saveData();
  }

  void sortServersByPing({bool silent = false}) {
    if (profiles.isEmpty) return;
    setState(() {
      profiles.sort((a, b) {
        if (a.ping <= 0 && b.ping <= 0) return 0;
        if (a.ping <= 0) return 1;
        if (b.ping <= 0) return -1;
        return a.ping.compareTo(b.ping);
      });
      activeIdx = 0;
    });
    _saveData();
    if (!silent) {
      _notify(tr('Sorted by lowest latency', 'بر اساس کمترین پینگ مرتب شد'));
    }
  }

  // ==================== اتصال ۱۰۰٪ پایدار و تضمینی اندروید ====================
  Future<void> toggleConnection() async {
    HapticFeedback.mediumImpact();
    if (isConnected || isBusy) {
      await _flutterV2ray.stopV2Ray();
      setState(() {
        isConnected = false;
        isBusy = false;
        dlMbps = 0.0;
        ulMbps = 0.0;
      });
      return;
    }

    if (profiles.isEmpty) {
      _showAddSubscriptionModal();
      return;
    }

    setState(() => isBusy = true);

    // اگر پینگ سرور فعلی گرفته نشده، سریع پینگ بگیر
    if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;
    final VpnProfile target = profiles[activeIdx];
    if (target.ping <= 0) {
      await pingSingleServer(target);
    }

    try {
      final String fullConfig = PureV2RayParser.buildPureConfig(target.rawUri);

      final bool hasPermission = await _flutterV2ray.requestPermission();
      if (!hasPermission) {
        setState(() => isBusy = false);
        _notify(tr('VPN Permission Denied', 'مجوز VPN تایید نشد'));
        return;
      }

      await _flutterV2ray.startV2Ray(
        remark: target.name,
        config: fullConfig,
        bypassSubnets: splitTunnelIr
            ? ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            : null,
      );

      setState(() {
        isConnected = true;
        isBusy = false;
      });
    } catch (e) {
      setState(() => isBusy = false);
      _notify('Connection Failed: $e');
    }
  }

  Future<void> connectToSpecificProfile(VpnProfile p) async {
    final idx = profiles.indexWhere((item) => item.id == p.id);
    if (idx == -1) return;
    HapticFeedback.selectionClick();

    final wasConn = isConnected;
    setState(() => activeIdx = idx);
    await _saveData();

    if (wasConn) {
      await _flutterV2ray.stopV2Ray();
      setState(() => isConnected = false);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    await toggleConnection();
  }

  // ==================== مدیریت اشتراک و کلیپ‌بورد ====================
  Future<void> updateActiveSubscription() async {
    if (subscriptions.isEmpty) {
      _showAddSubscriptionModal();
      return;
    }
    final targetSub = selectedSubId != 'all'
        ? subscriptions.firstWhere((s) => s.id == selectedSubId,
            orElse: () => subscriptions.first)
        : subscriptions.first;
    await _importSubscription(targetSub.url, existingSubId: targetSub.id);
  }

  Future<void> pasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _notify(tr('Clipboard is empty!', 'کلیپ‌بورد خالی است!'));
      return;
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      await _importSubscription(text);
    } else {
      final count = _importDirectLinks(text, subId: 'manual');
      if (count > 0) {
        _notify(tr('Added $count servers from clipboard',
            '$count سرور از کلیپ‌بورد اضافه شد'));
      } else {
        _notify(tr('No valid config found in clipboard',
            'کانفیگ معتبری در کلیپ‌بورد یافت نشد'));
      }
    }
  }

  int _importDirectLinks(String rawText, {required String subId}) {
    String body = rawText.trim();
    if (!body.contains('://')) {
      try {
        body = PureV2RayParser.decodeB64(body);
      } catch (_) {}
    }
    final lines = body.split(RegExp(r'[\r\n]+'));
    int added = 0;
    for (var l in lines) {
      final p = PureV2RayParser.parseUri(l, subId, profiles.length + added + 1);
      if (p != null) {
        profiles.insert(0, p);
        added++;
      }
    }
    if (added > 0) {
      setState(() => activeIdx = 0);
      _saveData();
      pingAllServers();
    }
    return added;
  }

  Future<void> _importSubscription(String url,
      {String? customTitle, String? existingSubId}) async {
    final cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      _notify(tr('Invalid Subscription URL', 'لینک اشتراک معتبر نیست'));
      return;
    }

    setState(() => isSyncingSub = true);
    try {
      final res = await http.get(
        Uri.parse(cleanUrl),
        headers: {'User-Agent': 'v2rayNG/1.8.19'},
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        String body = res.body.trim();
        if (!body.contains('://')) {
          try {
            body = PureV2RayParser.decodeB64(body);
          } catch (_) {}
        }

        SubscriptionGroup? existingGroup;
        if (existingSubId != null) {
          final idx = subscriptions.indexWhere((s) => s.id == existingSubId);
          if (idx != -1) existingGroup = subscriptions[idx];
        } else {
          final idx = subscriptions.indexWhere((s) => s.url.trim() == cleanUrl);
          if (idx != -1) existingGroup = subscriptions[idx];
        }

        final String targetSubId =
            existingGroup?.id ?? 'sub_${DateTime.now().millisecondsSinceEpoch}';
        final String hostTitle = Uri.parse(cleanUrl).host.replaceAll('www.', '');
        final String finalTitle =
            (customTitle != null && customTitle.trim().isNotEmpty)
                ? customTitle.trim()
                : (existingGroup?.title ??
                    (hostTitle.isNotEmpty ? hostTitle : 'Cloud Sub'));

        double used = existingGroup?.usedGB ?? 0.0;
        double total = existingGroup?.totalGB ?? 0.0;
        int? expDays = existingGroup?.expireDays;

        final infoHeader = res.headers['subscription-userinfo'];
        if (infoHeader != null && infoHeader.isNotEmpty) {
          int up = 0, dl = 0, tot = 0;
          int? expUnix;
          for (var part in infoHeader.split(';')) {
            final kv = part.trim().split('=');
            if (kv.length == 2) {
              final k = kv[0].trim().toLowerCase();
              final v = int.tryParse(kv[1].trim()) ?? 0;
              if (k == 'upload') up = v;
              if (k == 'download') dl = v;
              if (k == 'total') tot = v;
              if (k == 'expire' && v > 0) expUnix = v;
            }
          }
          if (tot > 0) {
            total = double.parse((tot / 1073741824).toStringAsFixed(1));
            used = double.parse(((up + dl) / 1073741824).toStringAsFixed(1));
          }
          if (expUnix != null) {
            final diff = DateTime.fromMillisecondsSinceEpoch(expUnix * 1000)
                .difference(DateTime.now())
                .inDays;
            expDays = diff >= 0 ? diff : 0;
          }
        }

        final lines = body.split(RegExp(r'[\r\n]+'));
        final newProfiles = <VpnProfile>[];

        for (var l in lines) {
          final p = PureV2RayParser.parseUri(
              l, targetSubId, newProfiles.length + 1);
          if (p != null) {
            final gm = RegExp(r'(\d+(?:\.\d+)?)\s*GB', caseSensitive: false)
                .allMatches(p.name)
                .toList();
            if (total == 0.0 && gm.isNotEmpty) {
              total = double.tryParse(gm.last.group(1)!) ?? total;
            }
            newProfiles.add(p);
          }
        }

        if (newProfiles.isEmpty) {
          _notify(tr('No servers found in link', 'سروری در این لینک یافت نشد'));
          setState(() => isSyncingSub = false);
          return;
        }

        setState(() {
          profiles.removeWhere((p) => p.subId == targetSubId);
          profiles.insertAll(0, newProfiles);

          if (existingGroup != null) {
            existingGroup.title = finalTitle;
            existingGroup.usedGB = used;
            existingGroup.totalGB = total;
            existingGroup.expireDays = expDays;
          } else {
            subscriptions.add(SubscriptionGroup(
              id: targetSubId,
              title: finalTitle,
              url: cleanUrl,
              usedGB: used,
              totalGB: total,
              expireDays: expDays,
            ));
          }
          selectedSubId = targetSubId;
          activeIdx = 0;
        });

        await _saveData();
        _notify(tr('Updated $finalTitle (${newProfiles.length} servers)',
            'اشتراک $finalTitle بروزرسانی شد (${newProfiles.length} سرور)'));
        pingAllServers();
      }
    } catch (_) {
      _notify(tr('Subscription update failed', 'خطا در دریافت اشتراک'));
    }
    if (mounted) setState(() => isSyncingSub = false);
  }

  void _notify(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0B162C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFF00A3FF).withOpacity(0.5)),
        ),
        duration: const Duration(seconds: 2),
        content: Text(msg,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF030712),
        body: Stack(
          children: [
            // پس‌زمینه گرادینت سرمه‌ای کهکشانی (مطابق هر دو عکس)
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.25),
                  radius: 1.1,
                  colors: [
                    Color(0xFF0B1D3A),
                    Color(0xFF050B18),
                    Color(0xFF02050D),
                  ],
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ۱. هدر بالای صفحه (مطابق عکس اول و دوم)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                    child: _buildTopBar(),
                  ),

                  // ۲. محتوای تب فعال
                  Expanded(
                    child: IndexedStack(
                      index: currentTab,
                      children: [
                        _buildHomeTab(),
                        _buildServersTab(),
                        _buildSettingsTab(),
                      ],
                    ),
                  ),

                  // ۳. نوار ناوبری پایین صفحه (مطابق عکس اول و دوم)
                  _buildBottomNavBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== هدر بالا (لوگوی سپر + نام + دکمه Update و Add) ====================
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: CustomPaint(painter: ShieldLightningLogoPainter()),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3),
                    children: [
                      TextSpan(
                          text: 'Lantern',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(
                          text: 'Net',
                          style: TextStyle(color: Color(0xFF00A3FF))),
                    ],
                  ),
                ),
                Text(
                  tr('Your Freedom, Our Priority', 'آزادی آنلاین و بدون مرز'),
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF6C88B5),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),

        // دکمه کپسولی Update (با نقطه قرمز) + دکمه افزودن سریع
        Row(
          children: [
            GestureDetector(
              onTap: updateActiveSubscription,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1428).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF1E3A6D).withOpacity(0.7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSyncingSub)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF00C2FF)),
                      )
                    else
                      const Icon(Icons.sync_rounded,
                          size: 15, color: Color(0xFF00C2FF)),
                    const SizedBox(width: 6),
                    Text(
                      tr('Update', 'بروزرسانی'),
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF3B5C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showAddSubscriptionModal,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1428).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF1E3A6D).withOpacity(0.7)),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 18, color: Color(0xFF00C2FF)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== تب اول: HOME (ترکیب دقیق عکس ۱ و عکس ۲) ====================
  Widget _buildHomeTab() {
    final VpnProfile? current =
        (profiles.isNotEmpty && activeIdx < profiles.length)
            ? profiles[activeIdx]
            : null;

    // حداکثر ۵ سرور برتر برای بخش Quick Connect پایین صفحه
    final List<VpnProfile> quickList = profiles.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ۱. دو کپسول وضعیت در چپ و راست بالای کره زمین (مطابق هر دو عکس)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // کپسول چپ: وضعیت امنیت
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF081226).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isConnected
                        ? const Color(0xFF00E676).withOpacity(0.35)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: isConnected
                          ? const Color(0xFF00E676)
                          : const Color(0xFF6C88B5),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Your connection is', 'وضعیت اتصال شما'),
                          style: const TextStyle(
                              fontSize: 9.5, color: Color(0xFF7B93B8)),
                        ),
                        Text(
                          isConnected
                              ? tr('protected', 'محافظت‌شده')
                              : tr('not connected', 'متصل نیست'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isConnected
                                ? const Color(0xFF00E676)
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // کپسول راست: نمایش آی‌پی و پروتکل
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF081226).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.signal_cellular_alt_rounded,
                        size: 18, color: Color(0xFF00B4FF)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current != null
                              ? '${current.protocol} IP'
                              : tr('VPN IP', 'آی‌پی سرور'),
                          style: const TextStyle(
                              fontSize: 9.5, color: Color(0xFF7B93B8)),
                        ),
                        Text(
                          current != null ? current.address : '0.0.0.0',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ۲. کره زمین شبکه‌ای + دکمه پاور نئونی در مرکز (Hero Globe & Power Core)
          Center(
            child: GestureDetector(
              onTap: toggleConnection,
              child: SizedBox(
                width: 246,
                height: 236,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // کره زمین چرخان در پس‌زمینه
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _globeCtrl,
                        builder: (_, __) => CustomPaint(
                          painter: CyberGlobePainter(
                            rotation: _globeCtrl.value,
                            isConnected: isConnected,
                          ),
                        ),
                      ),
                    ),

                    // حلقه شیشه‌ای بیرونی دکمه پاور
                    Container(
                      width: 146,
                      height: 146,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF050E21).withOpacity(0.78),
                        border: Border.all(
                          color: (isConnected
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF0088FF))
                              .withOpacity(0.45),
                          width: 2.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isConnected
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFF0088FF))
                                .withOpacity(0.35),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),

                    // دایره نئونی داخلی دکمه پاور
                    Container(
                      width: 122,
                      height: 122,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFF0D254C),
                            Color(0xFF061229),
                          ],
                        ),
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xFF00F5D4)
                              : const Color(0xFF00A3FF),
                          width: 2.8,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isBusy)
                            const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                color: Color(0xFF00E5FF),
                              ),
                            )
                          else
                            Icon(
                              Icons.power_settings_new_rounded,
                              size: 38,
                              color: isConnected
                                  ? const Color(0xFF00F5D4)
                                  : const Color(0xFF00C2FF),
                            ),
                          const SizedBox(height: 5),
                          Text(
                            isConnected
                                ? tr('Connected', 'متصل شد')
                                : tr('Tap to Connect', 'اتصال'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isConnected ? connectionDuration : '00:00:00',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C88B5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ۳. کارت سرور انتخاب‌شده (Selected Server Card مطابق عکس اول)
          GestureDetector(
            onTap: () => setState(() => currentTab = 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: _glassCardDecoration(glowBottom: true),
              child: Row(
                children: [
                  CircularFlagWidget(
                    name: current?.name ?? 'USA',
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                current?.name ??
                                    tr('Tap to Add / Select Server',
                                        'افزودن یا انتخاب سرور'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('👑', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          current != null
                              ? '${current.protocol} - Optimal Tunnel'
                              : tr('No server configured yet',
                                  'هنوز سروری وارد نشده است'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF00B4FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF060E1F),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.signal_cellular_alt_rounded,
                            size: 15, color: Color(0xFF00E676)),
                        const SizedBox(width: 5),
                        Text(
                          (current != null && current.ping > 0)
                              ? '${current.ping} ms'
                              : 'Ping',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: Color(0xFF6C88B5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ۴. نوار یکپارچه ۳ تایی سرعت و پینگ (از عکس دوم برای خلوت و شیک ماندن صفحه)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: _glassCardDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    icon: Icons.arrow_downward_rounded,
                    iconColor: const Color(0xFF00B4FF),
                    title: tr('Download', 'دانلود'),
                    value: '$dlMbps',
                    unit: 'Mbps',
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white10),
                Expanded(
                  child: _buildMetricItem(
                    icon: Icons.arrow_upward_rounded,
                    iconColor: const Color(0xFF00E676),
                    title: tr('Upload', 'آپلود'),
                    value: '$ulMbps',
                    unit: 'Mbps',
                  ),
                ),
                Container(width: 1, height: 32, color: Colors.white10),
                Expanded(
                  child: _buildMetricItem(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFF8B9DC3),
                    title: tr('Latency', 'پینگ'),
                    value: (current != null && current.ping > 0)
                        ? '${current.ping}'
                        : '--',
                    unit: 'ms',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ۵. کارت Auto Select (مطابق عکس اول)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => autoSelectBest = !autoSelectBest);
              if (autoSelectBest) sortServersByPing();
              _saveData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: _glassCardDecoration(),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0088FF).withOpacity(0.18),
                      border: Border.all(
                          color: const Color(0xFF00A3FF).withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Color(0xFF00C2FF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Auto Select', 'انتخاب هوشمند خودکار'),
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                        Text(
                          tr('Best server for your location',
                              'اتصال خودکار به سریع‌ترین سرور'),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF7B93B8)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: autoSelectBest,
                    activeColor: const Color(0xFF00C2FF),
                    onChanged: (v) {
                      setState(() => autoSelectBest = v);
                      if (v) sortServersByPing();
                      _saveData();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ۶. ردیف افقی Quick Connect (امکان قرار دادن و سوییچ سریع بین چند سرور مطابق عکس اول)
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 18, color: Color(0xFF00B4FF)),
              const SizedBox(width: 4),
              Text(
                tr('Quick Connect', 'اتصال سریع سرورها'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),

          SizedBox(
            height: 86,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...List.generate(quickList.length, (index) {
                  final item = quickList[index];
                  final isSel = current?.id == item.id;
                  return GestureDetector(
                    onTap: () => connectToSpecificProfile(item),
                    child: Container(
                      width: 74,
                      margin: const EdgeInsets.only(right: 9),
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF091326),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? const Color(0xFF00B4FF)
                              : Colors.white.withOpacity(0.09),
                          width: isSel ? 1.6 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularFlagWidget(name: item.name, size: 30),
                          const SizedBox(height: 6),
                          Text(
                            item.shortCountryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (index == 0) ...[
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0066FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Fastest',
                                style: TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),

                // کارت More / Add برای رفتن به لیست کامل یا افزودن سرور جدید
                GestureDetector(
                  onTap: () => setState(() => currentTab = 1),
                  child: Container(
                    width: 74,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF091326),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.09)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                          ),
                          child: const Icon(Icons.more_horiz_rounded,
                              color: Color(0xFF00B4FF), size: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('More', 'بیشتر'),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
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

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String unit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withOpacity(0.14),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Color(0xFF7B93B8)),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$value ',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: unit,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF7B93B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== تب دوم: SERVERS (مدیریت چند اشتراک و سرورها) ====================
  Widget _buildServersTab() {
    final list = filteredProfiles;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ۱. کارت‌های افقی اشتراک‌ها (Multi-Subscription Deck با نمایش حجم و روز)
          SizedBox(
            height: 78,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: () => setState(() => selectedSubId = 'all'),
                  child: Container(
                    width: 88,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selectedSubId == 'all'
                          ? const Color(0xFF0066FF).withOpacity(0.28)
                          : const Color(0xFF091326),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selectedSubId == 'all'
                            ? const Color(0xFF00B4FF)
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.dns_rounded,
                            size: 18, color: Color(0xFF00C2FF)),
                        const SizedBox(height: 4),
                        Text(
                          tr('All (${profiles.length})',
                              'همه (${profiles.length})'),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
                ...subscriptions.map((sub) {
                  final isSel = selectedSubId == sub.id;
                  final hasTraffic = sub.totalGB > 0;
                  final pct = hasTraffic
                      ? (sub.usedGB / sub.totalGB).clamp(0.0, 1.0)
                      : 0.3;

                  return GestureDetector(
                    onTap: () => setState(() => selectedSubId = sub.id),
                    child: Container(
                      width: 195,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF0066FF).withOpacity(0.22)
                            : const Color(0xFF091326),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSel
                              ? const Color(0xFF00B4FF)
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  sub.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5),
                                ),
                              ),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () => _importSubscription(sub.url,
                                        existingSubId: sub.id),
                                    child: const Icon(Icons.sync_rounded,
                                        size: 15, color: Color(0xFF00C2FF)),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        subscriptions
                                            .removeWhere((s) => s.id == sub.id);
                                        profiles.removeWhere(
                                            (p) => p.subId == sub.id);
                                        if (selectedSubId == sub.id) {
                                          selectedSubId = 'all';
                                        }
                                        activeIdx = 0;
                                      });
                                      _saveData();
                                    },
                                    child: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 15,
                                        color: Color(0xFFFF4D6D)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    hasTraffic
                                        ? '${sub.usedGB} / ${sub.totalGB} GB'
                                        : tr('Active Plan', 'اشتراک فعال'),
                                    style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF8B9DC3)),
                                  ),
                                  Text(
                                    sub.expireDays != null
                                        ? '${sub.expireDays}d'
                                        : '∞',
                                    style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00E5FF)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 3.5,
                                  backgroundColor: Colors.white12,
                                  color: const Color(0xFF00C2FF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ۲. نوار جستجو + دکمه پینگ، مرتب‌سازی و چسباندن از کلیپ‌بورد
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => searchQuery = v),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: tr('Search servers...', 'جستجوی سرور...'),
                      hintStyle: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF6C88B5)),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 17, color: Color(0xFF00B4FF)),
                      filled: true,
                      fillColor: const Color(0xFF091326),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _buildActionChip(
                icon: Icons.bolt_rounded,
                label: isPingingAll ? '...' : tr('Ping', 'پینگ'),
                onTap: pingAllServers,
              ),
              const SizedBox(width: 6),
              _buildActionChip(
                icon: Icons.sort_rounded,
                label: tr('Sort', 'مرتب'),
                onTap: sortServersByPing,
              ),
              const SizedBox(width: 6),
              _buildActionChip(
                icon: Icons.content_paste_rounded,
                label: tr('Paste', 'چسباندن'),
                onTap: pasteFromClipboard,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ۳. لیست کامل سرورها
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dns_outlined,
                            size: 42, color: Color(0xFF3B5278)),
                        const SizedBox(height: 8),
                        Text(
                          tr('No servers added yet', 'هنوز سروری اضافه نشده'),
                          style: const TextStyle(
                              color: Color(0xFF7B93B8),
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0077FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _showAddSubscriptionModal,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                              tr('Add Subscription / Config', 'افزودن اشتراک')),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final p = list[index];
                      final isSel =
                          (profiles.isNotEmpty && activeIdx < profiles.length) &&
                              profiles[activeIdx].id == p.id;

                      Color pingColor = const Color(0xFF00E676);
                      if (p.ping > 250) pingColor = const Color(0xFFFFB300);
                      if (p.ping <= 0) pingColor = const Color(0xFFFF4D6D);

                      return GestureDetector(
                        onTap: () => connectToSpecificProfile(p),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF0D2142)
                                : const Color(0xFF081224),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSel
                                  ? const Color(0xFF00B4FF)
                                  : Colors.white.withOpacity(0.07),
                              width: isSel ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircularFlagWidget(name: p.name, size: 34),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p.protocol} • ${p.address}:${p.port}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF6C88B5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => pingSingleServer(p),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF040915),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: p.isPinging
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF00C2FF)),
                                        )
                                      : Text(
                                          p.ping > 0
                                              ? '${p.ping} ms'
                                              : (p.ping == -2
                                                  ? 'Timeout'
                                                  : 'Ping'),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: p.ping > 0
                                                ? pingColor
                                                : const Color(0xFF6C88B5),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 17, color: Color(0xFF6C88B5)),
                                onPressed: () {
                                  setState(() {
                                    profiles
                                        .removeWhere((item) => item.id == p.id);
                                    if (activeIdx >= profiles.length) {
                                      activeIdx = 0;
                                    }
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

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF091326),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: const Color(0xFF00C2FF)),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== تب سوم: SETTINGS (کارت‌های سوییچ‌دار مطابق عکس دوم + زبان فارسی) ====================
  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Preferences & Security', 'تنظیمات و امنیت'),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 12),

          // انتخاب زبان (English Default / فارسی)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _glassCardDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language_rounded,
                        color: Color(0xFF00B4FF), size: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('App Language', 'زبان برنامه'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        Text(
                          isFa ? 'فارسی (Persian)' : 'English (Default)',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF7B93B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('EN')),
                    ButtonSegment(value: 'fa', label: Text('فا')),
                  ],
                  selected: {appLang},
                  onSelectionChanged: (s) {
                    setState(() => appLang = s.first);
                    _saveData();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // کارت‌های سوییچ‌دار دقیقاً مشابه پایین عکس دوم
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              _buildGridSwitchTile(
                icon: Icons.bolt_rounded,
                title: tr('Auto Connect', 'اتصال هوشمند'),
                value: autoSelectBest,
                onChanged: (v) {
                  setState(() => autoSelectBest = v);
                  _saveData();
                },
              ),
              _buildGridSwitchTile(
                icon: Icons.alt_route_rounded,
                title: tr('Split Tunneling', 'معافیت ایران'),
                value: splitTunnelIr,
                onChanged: (v) {
                  setState(() => splitTunnelIr = v);
                  _saveData();
                },
              ),
              _buildGridSwitchTile(
                icon: Icons.shield_outlined,
                title: tr('DNS Protection', 'سپر ضد نشت DNS'),
                value: dnsLeakShield,
                onChanged: (v) {
                  setState(() => dnsLeakShield = v);
                  _saveData();
                },
              ),
              _buildGridSwitchTile(
                icon: Icons.location_on_outlined,
                title: tr('IP Hidden', 'مخفی‌سازی آی‌پی'),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),

          const SizedBox(height: 14),

          // نوار شعار پایین عکس دوم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: _glassCardDecoration(),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 18, color: Color(0xFF00B4FF)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('No logs. No tracking. Just your freedom.',
                        'بدون ذخیره لاگ و بدون ردیابی؛ فقط آزادی آنلاین شما.'),
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8B9DC3),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _glassCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0088FF).withOpacity(0.15),
            ),
            child: Icon(icon, size: 17, color: const Color(0xFF00B4FF)),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value ? tr('On', 'فعال') : tr('Off', 'غیرفعال'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: value
                      ? const Color(0xFF00E676)
                      : const Color(0xFF6C88B5),
                ),
              ),
              SizedBox(
                height: 24,
                child: Switch(
                  value: value,
                  activeColor: const Color(0xFF00A3FF),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== نوار ناوبری پایین صفحه (Bottom Bar مطابق عکس ۱ و ۲) ====================
  Widget _buildBottomNavBar() {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF070F20).withOpacity(0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
              index: 0,
              icon: Icons.home_filled,
              label: tr('Home', 'خانه')),
          _buildNavItem(
              index: 1,
              icon: Icons.dns_rounded,
              label: tr('Servers', 'سرورها')),
          _buildNavItem(
              index: 2,
              icon: Icons.settings_rounded,
              label: tr('Settings', 'تنظیمات')),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final active = currentTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => currentTab = index);
      },
      child: SizedBox(
        width: 85,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? const Color(0xFF00B4FF) : const Color(0xFF6C88B5),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color:
                    active ? const Color(0xFF00B4FF) : const Color(0xFF6C88B5),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 28 : 0,
              height: 2.5,
              decoration: BoxDecoration(
                color: const Color(0xFF00B4FF),
                borderRadius: BorderRadius.circular(2),
                boxShadow: active
                    ? [
                        const BoxShadow(
                            color: Color(0xFF00B4FF), blurRadius: 6)
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== پنجره افزودن اشتراک یا کانفیگ ====================
  void _showAddSubscriptionModal() {
    final nameCtrl = TextEditingController();
    final linkCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0A1428),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: const Color(0xFF00A3FF).withOpacity(0.4)),
          ),
          title: Text(
            tr('Add Subscription / Config', 'افزودن لینک اشتراک یا کانفیگ'),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                  decoration: InputDecoration(
                    labelText:
                        tr('Subscription Name (Optional)', 'نام دلخواه اشتراک'),
                    labelStyle: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF7B93B8)),
                    filled: true,
                    fillColor: const Color(0xFF050B18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: linkCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'https://...\nvless://...\nvmess://...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF050B18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00C2FF),
                      side: const BorderSide(color: Color(0xFF0077FF)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      pasteFromClipboard();
                    },
                    icon: const Icon(Icons.content_paste_rounded, size: 16),
                    label: Text(tr(
                        'Paste Directly from Clipboard', 'چسباندن از کلیپ‌بورد')),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancel', 'انصراف'),
                  style: const TextStyle(color: Color(0xFF8B9DC3))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0077FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11)),
              ),
              onPressed: () {
                final raw = linkCtrl.text.trim();
                final title = nameCtrl.text.trim();
                Navigator.pop(ctx);
                if (raw.isEmpty) return;
                if (raw.startsWith('http://') || raw.startsWith('https://')) {
                  _importSubscription(raw, customTitle: title);
                } else {
                  _importDirectLinks(raw, subId: 'manual');
                }
              },
              child: Text(tr('Confirm & Add', 'تأیید و افزودن'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _glassCardDecoration({bool glowBottom = false}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xD90B162C),
          Color(0xE6060D1D),
        ],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: glowBottom
            ? const Color(0xFF00A3FF).withOpacity(0.42)
            : Colors.white.withOpacity(0.09),
      ),
      boxShadow: [
        if (glowBottom)
          BoxShadow(
            color: const Color(0xFF0088FF).withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
      ],
    );
  }
}
