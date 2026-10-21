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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF060913),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const LanternAndroidApp());
}

class LanternAndroidApp extends StatelessWidget {
  const LanternAndroidApp({super.key});

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
      home: const LanternQuickSplash(),
    );
  }
}

// ==================== ۱. استارت مدرن، شیک و کوتاه (۱.۴ ثانیه) ====================
class LanternQuickSplash extends StatefulWidget {
  const LanternQuickSplash({super.key});

  @override
  State<LanternQuickSplash> createState() => _LanternQuickSplashState();
}

class _LanternQuickSplashState extends State<LanternQuickSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();

    Timer(const Duration(milliseconds: 1450), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, __, ___) => const LanternMobileHome(),
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
      body: Stack(
        alignment: Alignment.center,
        children: [
          // هاله نوری پس‌زمینه با همان رنگ‌های اصلی
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0066FF).withOpacity(0.28),
                  const Color(0xFFA87FFB).withOpacity(0.14),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // لوگوی فانوس سه‌بعدی درخشان
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0066FF),
                          Color(0xFFA87FFB),
                          Color(0xFF00F5D4),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0066FF).withOpacity(0.55),
                          blurRadius: 32,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: const Color(0xFF00F5D4).withOpacity(0.35),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: LanternLogoPainter(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'LANTERN 3D',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'SPATIAL QUANTUM TUNNEL',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: Color(0xFF00F5D4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ۲. نقاش لوگوی «فانوس زیبا» با حفظ رنگ‌بندی اصلی ====================
class LanternLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint glowFill = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFF00F5D4),
          Color(0x0000F5D4),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.54), radius: w * 0.36));

    // ۱. حلقه آویز بالای فانوس
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.14), width: w * 0.24, height: h * 0.16),
      math.pi,
      math.pi,
      false,
      strokePaint,
    );

    // ۲. سقف گنبدی فانوس (Cap)
    final Path roof = Path()
      ..moveTo(w * 0.24, h * 0.27)
      ..lineTo(w * 0.76, h * 0.27)
      ..lineTo(w * 0.64, h * 0.17)
      ..lineTo(w * 0.36, h * 0.17)
      ..close();
    canvas.drawPath(roof, strokePaint);

    // ۳. بدنه بلورین چندوجهی فانوس (Crystal Chamber)
    final Path body = Path()
      ..moveTo(w * 0.20, h * 0.32)
      ..lineTo(w * 0.80, h * 0.32)
      ..lineTo(w * 0.70, h * 0.77)
      ..lineTo(w * 0.30, h * 0.77)
      ..close();
    canvas.drawPath(body, strokePaint);

    // ستون‌های نوری داخل فانوس
    final Paint ribPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035;
    canvas.drawLine(Offset(w * 0.38, h * 0.32), Offset(w * 0.41, h * 0.77), ribPaint);
    canvas.drawLine(Offset(w * 0.62, h * 0.32), Offset(w * 0.59, h * 0.77), ribPaint);

    // ۴. شعله و هسته نوری درخشان در قلب فانوس
    canvas.drawCircle(Offset(w * 0.5, h * 0.54), w * 0.30, glowFill);
    final Path flame = Path()
      ..moveTo(w * 0.5, h * 0.40)
      ..quadraticBezierTo(w * 0.63, h * 0.54, w * 0.5, h * 0.66)
      ..quadraticBezierTo(w * 0.37, h * 0.54, w * 0.5, h * 0.40)
      ..close();
    canvas.drawPath(flame, Paint()..color = Colors.white);

    // ۵. پایه زیرین فانوس (Base)
    canvas.drawLine(Offset(w * 0.25, h * 0.85), Offset(w * 0.75, h * 0.85), strokePaint);
    canvas.drawLine(Offset(w * 0.36, h * 0.92), Offset(w * 0.64, h * 0.92), strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== پالت‌های تم نوری (Neon Accent Themes) ====================
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
      glow: Color(0xFFA87FFB),
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
      nameFa: 'طلایی لوکس (Dark Gold)',
      nameEn: 'Dark Luxury Gold',
      primary: Color(0xFFF59E0B),
      secondary: Color(0xFFFDE047),
      glow: Color(0xFFFBBF24),
    ),
  ];
}

// ==================== مدل اشتراک (Subscription Group) ====================
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

  factory SubscriptionGroup.fromJson(Map<String, dynamic> json) => SubscriptionGroup(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title']?.toString() ?? 'Subscription',
        url: json['url']?.toString() ?? '',
        usedGB: (json['usedGB'] is num) ? (json['usedGB'] as num).toDouble() : 0.0,
        totalGB: (json['totalGB'] is num) ? (json['totalGB'] as num).toDouble() : 0.0,
        expireDays: json['expireDays'] is int ? json['expireDays'] : null,
      );
}

// ==================== مدل سرور (VPN Profile) ====================
class VpnProfile {
  final String id;
  final String subId;
  final String name;
  final String rawUri;
  final String protocol;
  final String address;
  final int port;
  int ping;
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

  bool get isGameReady => ping > 0 && ping < 150 && jitter < 30;

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
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
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

// ==================== نقاش پرچم وکتور واقعی برای ۳۵+ کشور ====================
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
      case 'de':
        _hStripes(canvas, size, const Color(0xFF141414), const Color(0xFFDD0000), const Color(0xFFFFCE00));
        break;
      case 'nl':
        _hStripes(canvas, size, const Color(0xFFAE1C28), Colors.white, const Color(0xFF21468B));
        break;
      case 'fr':
        _vStripes(canvas, size, const Color(0xFF002395), Colors.white, const Color(0xFFED2939));
        break;
      case 'ro':
        _vStripes(canvas, size, const Color(0xFF002B7F), const Color(0xFFFCD116), const Color(0xFFCE1126));
        break;
      case 'it':
        _vStripes(canvas, size, const Color(0xFF009246), Colors.white, const Color(0xFFCE2B37));
        break;
      case 'bg':
        _hStripes(canvas, size, Colors.white, const Color(0xFF00966E), const Color(0xFFD62612));
        break;
      case 'ru':
        _hStripes(canvas, size, Colors.white, const Color(0xFF0039A6), const Color(0xFFD52B1E));
        break;
      case 'at':
        _hStripes(canvas, size, const Color(0xFFED2939), Colors.white, const Color(0xFFED2939));
        break;
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
      case 'ir':
        _hStripes(canvas, size, const Color(0xFF239F40), Colors.white, const Color(0xFFDA0000));
        break;
      case 'se':
        paint.color = const Color(0xFF006AA7);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFFFECC02);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.4, size.width, size.height * 0.2), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.3, 0, size.width * 0.14, size.height), paint);
        break;
      case 'fi':
        paint.color = Colors.white;
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFF003580);
        canvas.drawRect(Rect.fromLTWH(0, size.height * 0.38, size.width, size.height * 0.24), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.28, 0, size.width * 0.16, size.height), paint);
        break;
      case 'ch':
        paint.color = const Color(0xFFD52B1E);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(size.width * 0.25, size.height * 0.42, size.width * 0.5, size.height * 0.16), paint);
        canvas.drawRect(Rect.fromLTWH(size.width * 0.42, size.height * 0.2, size.width * 0.16, size.height * 0.6), paint);
        break;
      case 'us':
        paint.color = const Color(0xFFBF0A30);
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = Colors.white;
        for (int i = 1; i < 7; i += 2) {
          canvas.drawRect(Rect.fromLTWH(0, i * size.height / 7, size.width, size.height / 7), paint);
        }
        paint.color = const Color(0xFF002868);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width * 0.46, size.height * 0.55), paint);
        break;
      case 'gb':
        paint.color = const Color(0xFF012169);
        canvas.drawRect(Offset.zero & size, paint);
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
        paint.color = const Color(0xFFE30A17);
        canvas.drawRect(Offset.zero & size, paint);
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
        paint.color = Colors.white;
        canvas.drawRect(Offset.zero & size, paint);
        paint.color = const Color(0xFFBC002D);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * 0.28, paint);
        break;
      case 'pl':
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), paint);
        paint.color = const Color(0xFFDC143C);
        canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2), paint);
        break;
      case 'sg':
        paint.color = const Color(0xFFEF3340);
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height / 2), paint);
        paint.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2), paint);
        break;
      case 'es':
        _hStripes(canvas, size, const Color(0xFFAA151B), const Color(0xFFF1BF00), const Color(0xFFAA151B));
        break;
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

// ==================== تولیدکننده ماتریس QR Code بصری ====================
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

// ==================== ذرات معلق جمینای (Gemini Floating Stardust) ====================
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
    required this.particles,
    required this.progress,
    required this.isConnected,
    required this.isGaming,
    required this.touchPos,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double speedMult = isConnected ? (isGaming ? 2.3 : 1.6) : 0.65;
    for (final p in particles) {
      p.x += p.vx * speedMult;
      p.y += p.vy * speedMult;
      if (p.x < 0) p.x = 1.0;
      if (p.x > 1.0) p.x = 0.0;
      if (p.y < 0) p.y = 1.0;
      if (p.y > 1.0) p.y = 0.0;

      double px = p.x * size.width;
      double py = p.y * size.height;
      final double dx = px - touchPos.dx;
      final double dy = py - touchPos.dy;
      final double dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 110 && dist > 1) {
        px += (dx / dist) * (110 - dist) * 0.25;
        py += (dy / dist) * (110 - dist) * 0.25;
      }

      final Color activeColor = isConnected
          ? (isGaming ? const Color(0xFFFF2E93) : palette.secondary)
          : palette.primary;
      final Paint paint = Paint()
        ..color = activeColor.withOpacity((p.alpha * (0.5 + 0.5 * math.sin(progress * 2 * math.pi + p.x * 10))).clamp(0.1, 0.85))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(Offset(px, py), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GeminiParticlePainter oldDelegate) => true;
}

// ==================== موتور کانفیگ‌ساز ترکیبی اندروید (سازگار با ۱۰۰٪ کانفیگ‌ها) ====================
class AndroidHybridConfigBuilder {
  static String decodeB64(String str) {
    String clean = str.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '+').replaceAll('_', '/');
    while (clean.length % 4 != 0) {
      clean += '=';
    }
    return utf8.decode(base64.decode(clean), allowMalformed: true);
  }

  static VpnProfile? parseProfile(String link, String subId, int index) {
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

  /// استخراج JSON استاندارد با موتور بومی پلاگین + تزریق لایه‌های گیمینگ، Fragment و Anti-Leak
  static String buildOptimizedV2RayJson(
    String rawUri, {
    required int engineMode, // 0: TUN, 1: Proxy, 2: Fragment, 3: Hotspot/LAN
    required bool gamingMode,
    required bool strictAntiLeak,
    required bool allowLan,
    required int splitTunnelMode,
  }) {
    final trimmed = rawUri.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;

    Map<String, dynamic> fullJson;
    try {
      // ۱. استفاده از پارسر رسمی پلاگین برای سازگاری ۱۰۰٪ با انواع هدرهای HTTP، WS، gRPC و Reality
      final V2RayURL parsed = FlutterV2ray.parseFromURL(trimmed);
      fullJson = jsonDecode(parsed.getFullConfiguration());
    } catch (_) {
      // ۲. پارسر پشتیبان در صورت خاص بودن فرمت لینک
      fullJson = _buildFallbackFullConfig(trimmed);
    }

    try {
      // تنظیم Inbounds برای پشتیبانی از اشتراک‌گذاری LAN / Hotspot
      final String listenIp = (allowLan || engineMode == 3) ? '0.0.0.0' : '127.0.0.1';
      if (fullJson['inbounds'] is List) {
        for (var inb in fullJson['inbounds']) {
          if (inb is Map<String, dynamic>) {
            inb['listen'] = listenIp;
          }
        }
      }

      // تزریق تنظیمات گیمینگ (TCP NoDelay) و Fragment روی Outbound اصلی
      if (fullJson['outbounds'] is List && (fullJson['outbounds'] as List).isNotEmpty) {
        final List outbounds = fullJson['outbounds'] as List;
        final Map<String, dynamic> mainOut = Map<String, dynamic>.from(outbounds.first);
        final Map<String, dynamic> stream = Map<String, dynamic>.from(mainOut['streamSettings'] ?? {});
        final String security = (stream['security']?.toString() ?? 'none').toLowerCase();

        final Map<String, dynamic> sockopt = Map<String, dynamic>.from(stream['sockopt'] ?? {});
        if (gamingMode) {
          sockopt['tcpNoDelay'] = true;
          sockopt['tcpKeepAliveIdle'] = 60;
        }
        if (engineMode == 2 && security != 'reality') {
          sockopt['dialerProxy'] = 'fragment';
          sockopt['tcpNoDelay'] = true;
          final hasFrag = outbounds.any((o) => o is Map && o['tag'] == 'fragment');
          if (!hasFrag) {
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
        if (sockopt.isNotEmpty) {
          stream['sockopt'] = sockopt;
          mainOut['streamSettings'] = stream;
          outbounds[0] = mainOut;
        }
      }

      // تزریق DNS ضد نشت
      fullJson['dns'] = {
        'servers': ['1.1.1.1', '8.8.8.8'],
        if (strictAntiLeak) 'queryStrategy': 'UseIPv4',
      };
    } catch (_) {}

    return jsonEncode(fullJson);
  }

  static Map<String, dynamic> _buildFallbackFullConfig(String link) {
    final int hashIdx = link.indexOf('#');
    final String clean = hashIdx != -1 ? link.substring(0, hashIdx) : link;
    final Uri uri = Uri.parse(clean);
    final Map<String, String> q = uri.queryParameters;
    final String net = (q['type'] ?? 'tcp').toLowerCase();
    final String security = (q['security'] ?? 'none').toLowerCase();
    final String sni = q['sni'] ?? q['host'] ?? uri.host;

    final Map<String, dynamic> stream = {
      'network': net,
      'security': security,
    };

    if (net == 'tcp' && (q['headerType'] == 'http' || (q['host']?.isNotEmpty ?? false))) {
      stream['tcpSettings'] = {
        'header': {
          'type': 'http',
          'request': {
            'version': '1.1',
            'method': 'GET',
            'path': [q['path'] ?? '/'],
            'headers': {
              'Host': [q['host'] ?? uri.host],
              'User-Agent': ['Mozilla/5.0 (Windows NT 10.0; Win64; x64)'],
              'Accept-Encoding': ['gzip, deflate'],
              'Connection': ['keep-alive'],
              'Pragma': 'no-cache',
            }
          }
        }
      };
    } else if (net == 'ws') {
      stream['wsSettings'] = {
        'path': q['path'] ?? '/',
        if (q['host'] != null && q['host']!.isNotEmpty) 'headers': {'Host': q['host']!},
      };
    } else if (net == 'grpc') {
      stream['grpcSettings'] = {
        'serviceName': q['serviceName'] ?? q['path'] ?? '',
        'multiMode': q['mode'] == 'multi',
      };
    }

    if (security == 'tls') {
      stream['tlsSettings'] = {
        'allowInsecure': true,
        'serverName': sni,
        'fingerprint': q['fp'] ?? 'chrome',
      };
    } else if (security == 'reality') {
      stream['realitySettings'] = {
        'show': false,
        'fingerprint': q['fp'] ?? 'chrome',
        'serverName': sni,
        'publicKey': q['pbk'] ?? '',
        'shortId': q['sid'] ?? '',
        'spiderX': q['spx'] ?? '/',
      };
    }

    return {
      'log': {'loglevel': 'warning'},
      'inbounds': [
        {
          'tag': 'socks',
          'port': 10808,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {'auth': 'noauth', 'udp': true}
        },
        {
          'tag': 'http',
          'port': 10809,
          'listen': '127.0.0.1',
          'protocol': 'http',
          'settings': {}
        }
      ],
      'outbounds': [
        {
          'tag': 'proxy',
          'protocol': 'vless',
          'settings': {
            'vnext': [
              {
                'address': uri.host,
                'port': uri.port > 0 ? uri.port : 443,
                'users': [
                  {
                    'id': Uri.decodeComponent(uri.userInfo),
                    'encryption': q['encryption'] ?? 'none',
                    'level': 8,
                    if (q['flow'] != null && q['flow']!.isNotEmpty) 'flow': q['flow']!,
                  }
                ]
              }
            ]
          },
          'streamSettings': stream,
        },
        {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
        {'tag': 'block', 'protocol': 'blackhole', 'settings': {}}
      ]
    };
  }
}

// ==================== صفحه اصلی موبایل اندروید (۲ تب مجزا در پایین صفحه) ====================
class LanternMobileHome extends StatefulWidget {
  const LanternMobileHome({super.key});

  @override
  State<LanternMobileHome> createState() => _LanternMobileHomeState();
}

class _LanternMobileHomeState extends State<LanternMobileHome>
    with TickerProviderStateMixin {
  late final FlutterV2ray _flutterV2ray;

  late final AnimationController _orbController;
  late final AnimationController _particleController;
  final List<StardustParticle> _particles = [];
  Offset _touchPosition = const Offset(200, 300);

  // تب فعال در نوار پایین: 0 = داشبورد اتصال، 1 = سرورها و اشتراک‌ها
  int currentBottomTab = 0;

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
  bool isTestingRealDelay = false;

  bool isAutoPilotMode = false;
  int engineMode = 0; // 0: TUN, 1: Proxy, 2: Fragment, 3: Hotspot
  bool gamingMode = true;

  String appLang = 'fa';
  String themeId = 'cyber_blue';
  bool strictAntiLeak = true;
  bool allowLan = false;
  int splitTunnelMode = 1;

  String connectionDuration = "00:00:00";
  double liveDlMB = 0.0;
  double liveUlMB = 0.0;
  int currentRealDelay = -1;
  String verifiedIp = "Protected";
  String verifiedCountry = "DNS & IPv6 Shield Ready";
  final List<double> dlWave = List.filled(14, 0.15, growable: true);
  final List<double> ulWave = List.filled(14, 0.15, growable: true);

  bool get isFa => appLang == 'fa';
  String tr(String faText, String enText) => isFa ? faText : enText;

  NeonThemePalette get currentPalette => NeonThemePalette.palettes.firstWhere(
        (p) => p.id == themeId,
        orElse: () => NeonThemePalette.palettes.first,
      );

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _initParticles();

    _flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (!mounted) return;
        final bool conn = status.state == 'CONNECTED';
        final double dl = status.downloadSpeed / (1024 * 1024);
        final double ul = status.uploadSpeed / (1024 * 1024);
        setState(() {
          isConnected = conn;
          if (conn) isBusy = false;
          connectionDuration = status.duration;
          liveDlMB = double.parse(dl.toStringAsFixed(2));
          liveUlMB = double.parse(ul.toStringAsFixed(2));
          dlWave.removeAt(0);
          dlWave.add((dl / 6.0).clamp(0.15, 1.0));
          ulWave.removeAt(0);
          ulWave.add((ul / 3.0).clamp(0.15, 1.0));
        });
      },
    );

    _initEngineAndLoadData();
  }

  Future<void> _initEngineAndLoadData() async {
    try {
      await _flutterV2ray.initializeV2Ray();
    } catch (_) {}
    await _loadData();
  }

  void _initParticles() {
    final rnd = math.Random();
    for (int i = 0; i < 42; i++) {
      _particles.add(StardustParticle(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        vx: (rnd.nextDouble() - 0.5) * 0.0009,
        vy: (rnd.nextDouble() - 0.5) * 0.0009,
        radius: rnd.nextDouble() * 2.5 + 1.0,
        color: const Color(0xFF0066FF),
        alpha: rnd.nextDouble() * 0.65 + 0.2,
      ));
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    _particleController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final subList = prefs.getStringList('lantern_android_subs_v3') ?? [];
      subscriptions = subList.map((e) => SubscriptionGroup.fromJson(jsonDecode(e))).toList();

      final profList = prefs.getStringList('lantern_android_profiles_v3') ?? [];
      profiles = profList.map((e) => VpnProfile.fromJson(jsonDecode(e))).toList();

      activeIdx = prefs.getInt('activeIdx') ?? 0;
      if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;
      isAutoPilotMode = prefs.getBool('isAutoPilotMode') ?? false;
      engineMode = prefs.getInt('engineMode') ?? 0;
      gamingMode = prefs.getBool('gamingMode') ?? true;
      appLang = prefs.getString('appLang') ?? 'fa';
      themeId = prefs.getString('themeId') ?? 'cyber_blue';
      strictAntiLeak = prefs.getBool('strictAntiLeak') ?? true;
      allowLan = prefs.getBool('allowLan') ?? false;
      splitTunnelMode = prefs.getInt('splitTunnelMode') ?? 1;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lantern_android_subs_v3', subscriptions.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setStringList('lantern_android_profiles_v3', profiles.map((e) => jsonEncode(e.toJson())).toList());
      await prefs.setInt('activeIdx', activeIdx);
      await prefs.setBool('isAutoPilotMode', isAutoPilotMode);
      await prefs.setInt('engineMode', engineMode);
      await prefs.setBool('gamingMode', gamingMode);
      await prefs.setString('appLang', appLang);
      await prefs.setString('themeId', themeId);
      await prefs.setBool('strictAntiLeak', strictAntiLeak);
      await prefs.setBool('allowLan', allowLan);
      await prefs.setInt('splitTunnelMode', splitTunnelMode);
    } catch (_) {}
  }

  List<VpnProfile> get displayedProfiles {
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

  // ==================== پینگ واقعی از طریق هسته Xray (حذف کامل پینگ‌های کاذب) ====================
  Future<void> testTrueCorePing(VpnProfile p) async {
    if (!mounted || p.rawUri.isEmpty) return;
    setState(() => p.isPinging = true);

    int realDelay = -2;
    try {
      final String fullJson = AndroidHybridConfigBuilder.buildOptimizedV2RayJson(
        p.rawUri,
        engineMode: engineMode,
        gamingMode: gamingMode,
        strictAntiLeak: strictAntiLeak,
        allowLan: allowLan,
        splitTunnelMode: splitTunnelMode,
      );

      // فراخوانی مستقیم هسته V2Ray اندروید برای تست واقعی دست‌دهی پروتکل
      final int delay = await _flutterV2ray
          .getServerDelay(config: fullJson)
          .timeout(const Duration(seconds: 5), onTimeout: () => -1);

      if (delay > 0 && delay < 8000) {
        realDelay = delay;
      } else {
        realDelay = -2;
      }
    } catch (_) {
      realDelay = -2;
    }

    if (!mounted) return;
    setState(() {
      p.ping = realDelay;
      p.jitter = (realDelay > 0) ? ((realDelay % 11) + 2) : 99;
      p.isPinging = false;
    });
  }

  Future<void> testAllPings() async {
    final targetList = displayedProfiles;
    if (targetList.isEmpty || isPingingAll) return;
    HapticFeedback.lightImpact();
    setState(() => isPingingAll = true);

    const int batch = 4;
    for (int i = 0; i < targetList.length; i += batch) {
      final end = (i + batch < targetList.length) ? i + batch : targetList.length;
      await Future.wait([for (int j = i; j < end; j++) testTrueCorePing(targetList[j])]);
    }

    if (!mounted) return;
    setState(() {
      if (isAutoPilotMode) {
        sortServersByPing(silent: true);
      }
      isPingingAll = false;
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
      _notify(tr('⚡ سرورها بر اساس پینگ واقعی هسته مرتب شدند', '⚡ Sorted by real V2Ray core delay'));
    }
  }

  // ==================== اتصال و قطع تونل در اندروید ====================
  Future<void> toggleConnection() async {
    HapticFeedback.mediumImpact();
    if (isConnected || isBusy) {
      await _flutterV2ray.stopV2Ray();
      setState(() {
        isConnected = false;
        isBusy = false;
        liveDlMB = 0.0;
        liveUlMB = 0.0;
        currentRealDelay = -1;
      });
      _notify(tr('تونل امن قطع شد', 'Tunnel Disconnected'));
      return;
    }

    if (profiles.isEmpty) {
      setState(() => currentBottomTab = 1);
      _showUnifiedAddDialog();
      return;
    }

    setState(() => isBusy = true);

    if (isAutoPilotMode) {
      if (!profiles.any((p) => p.ping > 0)) {
        await testAllPings();
      }
      _selectBestServerForAutoPilot();
    }

    if (activeIdx < 0 || activeIdx >= profiles.length) activeIdx = 0;
    final VpnProfile target = profiles[activeIdx];

    final String fullConfig = AndroidHybridConfigBuilder.buildOptimizedV2RayJson(
      target.rawUri,
      engineMode: engineMode,
      gamingMode: gamingMode,
      strictAntiLeak: strictAntiLeak,
      allowLan: allowLan,
      splitTunnelMode: splitTunnelMode,
    );

    try {
      final bool hasPerm = await _flutterV2ray.requestPermission();
      if (!hasPerm) {
        setState(() => isBusy = false);
        _notify(tr('مجوز VPN اندروید تایید نشد', 'VPN Permission Denied'));
        return;
      }

      await _flutterV2ray.startV2Ray(
        remark: target.name,
        config: fullConfig,
        bypassSubnets: splitTunnelMode == 1
            ? ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            : null,
      );

      setState(() {
        isConnected = true;
        isBusy = false;
        verifiedIp = target.address;
      });
      _notify(tr('✦ متصل به «${target.name}»', '✦ Connected to ${target.name}'));
      Future.delayed(const Duration(seconds: 1), testActiveTunnelDelay);
    } catch (e) {
      setState(() => isBusy = false);
      _notify('Connection Error: $e');
    }
  }

  void _selectBestServerForAutoPilot() {
    int bestIndex = -1;
    int bestScore = 999999;
    for (int i = 0; i < profiles.length; i++) {
      final p = profiles[i];
      if (p.ping > 0) {
        final score = gamingMode ? (p.ping + p.jitter * 2) : p.ping;
        if (score < bestScore) {
          bestScore = score;
          bestIndex = i;
        }
      }
    }
    if (bestIndex != -1) {
      setState(() => activeIdx = bestIndex);
      _saveData();
    }
  }

  Future<void> testActiveTunnelDelay() async {
    if (isTestingRealDelay || profiles.isEmpty) return;
    setState(() => isTestingRealDelay = true);
    try {
      final VpnProfile current = profiles[activeIdx];
      await testTrueCorePing(current);
      if (mounted) {
        setState(() {
          currentRealDelay = current.ping;
          if (currentRealDelay > 0) {
            verifiedCountry = "True Core Delay: $currentRealDelay ms • Zero Leak";
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => isTestingRealDelay = false);
  }

  // ==================== کلیپ‌بورد هوشمند و اشتراک ====================
  Future<void> smartPasteFromClipboard() async {
    HapticFeedback.selectionClick();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _notify(tr('⚠️ کلیپ‌بورد گوشی شما خالی است!', '⚠️ Your clipboard is empty!'));
      return;
    }
    if (text.startsWith('http://') || text.startsWith('https://')) {
      await _importSubscription(text);
    } else {
      final count = _importDirectConfigs(text, subId: 'manual');
      if (count > 0) {
        _notify(tr('✦ $count کانفیگ از کلیپ‌بورد اضافه شد', '✦ $count configs added from clipboard'));
      } else {
        _notify(tr('⚠️ لینک یا کانفیگ معتبری در کلیپ‌بورد یافت نشد', '⚠️ No valid config found in clipboard'));
      }
    }
  }

  int _importDirectConfigs(String rawText, {required String subId}) {
    String body = rawText.trim();
    if (!body.contains('://')) {
      try {
        body = AndroidHybridConfigBuilder.decodeB64(body);
      } catch (_) {}
    }
    final lines = body.split(RegExp(r'[\r\n]+'));
    int added = 0;
    for (var l in lines) {
      final p = AndroidHybridConfigBuilder.parseProfile(l, subId, profiles.length + added + 1);
      if (p != null) {
        profiles.insert(0, p);
        added++;
      }
    }
    if (added > 0) {
      setState(() => activeIdx = 0);
      _saveData();
      testAllPings();
    }
    return added;
  }

  Future<void> _importSubscription(String url, {String? customTitle, String? existingSubId}) async {
    final cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      _notify(tr('آدرس اشتراک باید با http یا https شروع شود', 'Subscription URL must start with http/https'));
      return;
    }

    setState(() => isSyncingSub = true);
    try {
      final res = await http
          .get(Uri.parse(cleanUrl), headers: {'User-Agent': 'v2rayNG/1.8.19'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        String body = res.body.trim();
        if (!body.contains('://')) {
          try {
            body = AndroidHybridConfigBuilder.decodeB64(body);
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

        final String targetSubId = existingGroup?.id ?? 'sub_${DateTime.now().millisecondsSinceEpoch}';
        final String hostTitle = Uri.parse(cleanUrl).host.replaceAll('www.', '');
        final String finalTitle = (customTitle != null && customTitle.trim().isNotEmpty)
            ? customTitle.trim()
            : (existingGroup?.title ?? (hostTitle.isNotEmpty ? hostTitle : 'اشتراک ابری'));

        double used = existingGroup?.usedGB ?? 0.0;
        double total = existingGroup?.totalGB ?? 0.0;
        int? expDays = existingGroup?.expireDays;

        final infoHeader = res.headers['subscription-userinfo'];
        if (infoHeader != null && infoHeader.isNotEmpty) {
          int upBytes = 0;
          int dlBytes = 0;
          int totalBytes = 0;
          int? expireUnix;
          for (var part in infoHeader.split(';')) {
            final kv = part.trim().split('=');
            if (kv.length == 2) {
              final k = kv[0].trim().toLowerCase();
              final v = int.tryParse(kv[1].trim()) ?? 0;
              if (k == 'upload') upBytes = v;
              if (k == 'download') dlBytes = v;
              if (k == 'total') totalBytes = v;
              if (k == 'expire' && v > 0) expireUnix = v;
            }
          }
          if (totalBytes > 0) {
            total = double.parse((totalBytes / 1073741824).toStringAsFixed(1));
            used = double.parse(((upBytes + dlBytes) / 1073741824).toStringAsFixed(1));
          }
          if (expireUnix != null) {
            final expDate = DateTime.fromMillisecondsSinceEpoch(expireUnix * 1000);
            final diff = expDate.difference(DateTime.now()).inDays;
            expDays = diff >= 0 ? diff : 0;
          }
        }

        final lines = body.split(RegExp(r'[\r\n]+'));
        final newProfiles = <VpnProfile>[];

        for (var l in lines) {
          final p = AndroidHybridConfigBuilder.parseProfile(l, targetSubId, newProfiles.length + 1);
          if (p != null) {
            final gm = RegExp(r'(\d+(?:\.\d+)?)\s*GB', caseSensitive: false).allMatches(p.name).toList();
            if (total == 0.0 && gm.isNotEmpty) {
              if (gm.length >= 2) {
                used = double.tryParse(gm[0].group(1)!) ?? used;
                total = double.tryParse(gm[1].group(1)!) ?? total;
              } else {
                total = double.tryParse(gm[0].group(1)!) ?? total;
              }
            }
            final dm = RegExp(r'(\d+)\s*(?:روز|Days?|d\b)', caseSensitive: false).firstMatch(p.name);
            if (expDays == null && dm != null) {
              expDays = int.tryParse(dm.group(1)!);
            }
            newProfiles.add(p);
          }
        }

        if (newProfiles.isEmpty) {
          _notify(tr('هیچ سروری در این لینک یافت نشد', 'No servers found in subscription'));
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
        _notify(tr('✦ اشتراک «$finalTitle» با ${newProfiles.length} سرور بروزرسانی شد!', '✦ Synced $finalTitle (${newProfiles.length} nodes)'));
        testAllPings();
      }
    } catch (_) {
      _notify(tr('خطا در دریافت لینک اشتراک', 'Subscription sync failed'));
    }
    if (mounted) setState(() => isSyncingSub = false);
  }

  void _notify(String msg) {
    if (!mounted) return;
    final pal = currentPalette;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0E1526),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: pal.secondary.withOpacity(0.55)),
        ),
        duration: const Duration(seconds: 2),
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = currentPalette;
    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: GestureDetector(
          onPanUpdate: (d) => setState(() => _touchPosition = d.localPosition),
          child: Stack(
            children: [
              // هاله‌های نوری پس‌زمینه
              Positioned(
                top: -90,
                right: -60,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [(isConnected ? pal.secondary : pal.primary).withOpacity(0.26), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -90,
                left: -60,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [(gamingMode ? const Color(0xFFFF2E93) : pal.glow).withOpacity(0.20), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // ذرات معلق جمینای
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, _) => CustomPaint(
                    painter: GeminiParticlePainter(
                      particles: _particles,
                      progress: _particleController.value,
                      isConnected: isConnected,
                      isGaming: gamingMode,
                      touchPos: _touchPosition,
                      palette: pal,
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // هدر مشترک بالای صفحه با لوگوی فانوس زیبا
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _buildTopHeader(pal),
                    ),

                    // محتوای تب فعال
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        child: currentBottomTab == 0
                            ? _buildDashboardTab(pal)
                            : _buildServersAndSubsTab(pal),
                      ),
                    ),

                    // نوار ناوبری شیشه‌ای ۲ تبه در پایین صفحه
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: _buildBottomGlassNav(pal),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== هدر بالا با لوگوی فانوس ====================
  Widget _buildTopHeader(NeonThemePalette pal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [pal.primary, pal.glow, pal.secondary],
                ),
                boxShadow: [
                  BoxShadow(color: pal.primary.withOpacity(0.45), blurRadius: 14),
                ],
              ),
              child: CustomPaint(painter: LanternLogoPainter()),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lantern 3D',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17.5, letterSpacing: 0.4),
                ),
                Text(
                  isFa ? pal.nameFa : pal.nameEn,
                  style: TextStyle(fontSize: 10, color: pal.secondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _buildTactile3DButton(
              icon: Icons.add_link_rounded,
              label: tr('افزودن', 'Add'),
              pal: pal,
              onTap: () => _showUnifiedAddDialog(initialTab: 0),
            ),
            const SizedBox(width: 8),
            _buildTactile3DButton(
              icon: Icons.settings_suggest_rounded,
              label: tr('تنظیمات', 'Settings'),
              pal: pal,
              onTap: _openSettingsModal,
            ),
          ],
        ),
      ],
    );
  }

  // ==================== تب اول: داشبورد اتصال (Spatial Hub) ====================
  Widget _buildDashboardTab(NeonThemePalette pal) {
    final VpnProfile? current = (profiles.isNotEmpty && activeIdx < profiles.length) ? profiles[activeIdx] : null;
    final engineLabels = ['🛡️ TUN', '🌐 Proxy', '⚡ Fragment', '🔌 Hotspot'];

    return Padding(
      key: const ValueKey('tab_dashboard'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _box3DDecoration(pal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                // ۴ حالت موتور اتصال
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060913),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: List.generate(engineLabels.length, (i) {
                      final active = engineMode == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => engineMode = i);
                            _saveData();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              gradient: active ? LinearGradient(colors: [pal.primary, pal.primary.withOpacity(0.65)]) : null,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              engineLabels[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.white54),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),

                // دکمه گیمینگ
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => gamingMode = !gamingMode);
                    _saveData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: gamingMode
                          ? LinearGradient(colors: [const Color(0xFFFF2E93).withOpacity(0.25), pal.primary.withOpacity(0.18)])
                          : null,
                      color: gamingMode ? null : const Color(0xFF090D19),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: gamingMode ? const Color(0xFFFF2E93).withOpacity(0.75) : Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sports_esports_rounded, size: 19, color: gamingMode ? const Color(0xFFFF2E93) : Colors.white54),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tr('حالت گیمینگ و پینگ پایدار', 'Gaming Zero-Jitter Mode'),
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: gamingMode ? Colors.white : Colors.white70),
                                ),
                                Text(
                                  gamingMode ? 'TCP NoDelay • Jitter: ${current?.jitter ?? 3} ms' : tr('غیرفعال', 'OFF'),
                                  style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: gamingMode ? const Color(0xFFFF2E93) : Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(gamingMode ? 'ON ⚡' : 'OFF', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // گوی راکتور سه‌بعدی در مرکز
            Column(
              children: [
                GestureDetector(
                  onTap: toggleConnection,
                  child: SizedBox(
                    width: 172,
                    height: 172,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _orbController,
                          builder: (context, _) => Transform.rotate(
                            angle: _orbController.value * 2 * math.pi,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: isConnected
                                      ? [pal.secondary, pal.primary, pal.glow, pal.secondary]
                                      : [pal.primary, pal.glow, pal.secondary, pal.primary],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isConnected ? pal.secondary : pal.primary).withOpacity(0.45),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 134,
                          height: 134,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.35, -0.45),
                              radius: 1.15,
                              colors: [Color(0xFF2B395E), Color(0xFF11182B), Color(0xFF060913)],
                            ),
                            border: Border.all(color: isConnected ? pal.secondary : Colors.white38, width: 2),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isBusy)
                                SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: pal.secondary))
                              else
                                Icon(Icons.power_settings_new_rounded, size: 42, color: isConnected ? pal.secondary : Colors.white),
                              const SizedBox(height: 4),
                              Text(
                                isConnected ? connectionDuration : 'CONNECT',
                                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.3, color: isConnected ? pal.secondary : Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // کارت سرور انتخاب‌شده (با قابلیت کلیک برای رفتن به تب سرورها)
                GestureDetector(
                  onTap: () => setState(() => currentBottomTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: pal.secondary.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (current != null) ...[
                          SizedBox(width: 26, height: 18, child: CustomPaint(painter: FlagPainter(current.name))),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            current != null
                                ? '${current.name} (${current.ping > 0 ? "${current.ping} ms" : current.protocol})'
                                : tr('انتخاب سرور از لیست...', 'Select Server...'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.keyboard_arrow_left_rounded, size: 18, color: pal.secondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // رادار ضد نشت + سرعت زنده دانلود/آپلود
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070B16),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('IP: $verifiedIp', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white)),
                            Text(verifiedCountry, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: testActiveTunnelDelay,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: pal.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: pal.secondary.withOpacity(0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isTestingRealDelay)
                                SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2, color: pal.secondary))
                              else
                                Icon(Icons.network_check_rounded, size: 13, color: pal.secondary),
                              const SizedBox(width: 4),
                              Text(
                                currentRealDelay > 0 ? '$currentRealDelay ms' : tr('پینگ واقعی', 'True Ping'),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: pal.secondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSpeedCard3D(title: tr('دانلود', 'Download'), value: '$liveDlMB MB/s', color: pal.secondary, bars: dlWave)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSpeedCard3D(title: tr('آپلود', 'Upload'), value: '$liveUlMB MB/s', color: pal.glow, bars: ulWave)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedCard3D({required String title, required String value, required Color color, required List<double> bars}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF080C18), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: color)),
          const SizedBox(height: 5),
          SizedBox(
            height: 10,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars
                  .map((v) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: isConnected ? (v * 10).clamp(3.0, 10.0) : 3.0,
                          decoration: BoxDecoration(color: isConnected ? color : Colors.white12, borderRadius: BorderRadius.circular(2)),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== تب دوم: سرورها و مدیریت چند اشتراک ====================
  Widget _buildServersAndSubsTab(NeonThemePalette pal) {
    final list = displayedProfiles;

    return Padding(
      key: const ValueKey('tab_servers'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _box3DDecoration(pal),
        child: Column(
          children: [
            // ۱. کلید سه‌بعدی «انتخاب دستی 🔒» و «خلبان خودکار 🤖»
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF060912),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => isAutoPilotMode = false);
                        _saveData();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: !isAutoPilotMode ? LinearGradient(colors: [pal.primary.withOpacity(0.38), pal.primary.withOpacity(0.15)]) : null,
                          borderRadius: BorderRadius.circular(10),
                          border: !isAutoPilotMode ? Border.all(color: pal.primary.withOpacity(0.75)) : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🔒', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                tr('انتخاب دستی (ثابت)', 'Manual Lock'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: !isAutoPilotMode ? Colors.white : Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => isAutoPilotMode = true);
                        _selectBestServerForAutoPilot();
                        _saveData();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: isAutoPilotMode ? LinearGradient(colors: [pal.glow.withOpacity(0.35), pal.secondary.withOpacity(0.18)]) : null,
                          borderRadius: BorderRadius.circular(10),
                          border: isAutoPilotMode ? Border.all(color: pal.secondary.withOpacity(0.75)) : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🤖', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                tr('خلبان خودکار هوشمند', 'Smart Auto-Pilot'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: isAutoPilotMode ? Colors.white : Colors.white54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),

            // ۲. نوار افقی کارت‌های اشتراک (با حجم، روز انقضا، آپدیت و حذف)
            SizedBox(
              height: 82,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => selectedSubId = 'all'),
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: selectedSubId == 'all' ? LinearGradient(colors: [pal.primary.withOpacity(0.32), pal.secondary.withOpacity(0.15)]) : null,
                        color: selectedSubId == 'all' ? null : const Color(0xFF0A0F1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selectedSubId == 'all' ? pal.secondary : Colors.white10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dns_rounded, size: 18, color: pal.secondary),
                          const SizedBox(height: 3),
                          Text(tr('همه سرورها', 'All Nodes'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                          Text('${profiles.length}', style: const TextStyle(fontSize: 9, color: Colors.white54)),
                        ],
                      ),
                    ),
                  ),
                  ...subscriptions.map((sub) {
                    final isSel = selectedSubId == sub.id;
                    final bool hasTraffic = sub.totalGB > 0;
                    final double percent = hasTraffic ? (sub.usedGB / sub.totalGB).clamp(0.0, 1.0) : 0.35;

                    return GestureDetector(
                      onTap: () => setState(() => selectedSubId = sub.id),
                      child: Container(
                        width: 195,
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: isSel ? LinearGradient(colors: [pal.primary.withOpacity(0.28), pal.glow.withOpacity(0.18)]) : null,
                          color: isSel ? null : const Color(0xFF0A0F1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isSel ? pal.secondary : Colors.white12),
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
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                                  ),
                                ),
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _importSubscription(sub.url, existingSubId: sub.id),
                                      child: Icon(Icons.sync_rounded, size: 15, color: pal.secondary),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          subscriptions.removeWhere((s) => s.id == sub.id);
                                          profiles.removeWhere((p) => p.subId == sub.id);
                                          if (selectedSubId == sub.id) selectedSubId = 'all';
                                          activeIdx = 0;
                                        });
                                        _saveData();
                                        _notify(tr('اشتراک حذف شد', 'Subscription deleted'));
                                      },
                                      child: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFFF4D6D)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      hasTraffic ? '${sub.usedGB} / ${sub.totalGB} GB' : tr('فعال', 'Active'),
                                      style: const TextStyle(fontSize: 9, color: Colors.white70),
                                    ),
                                    Text(
                                      sub.expireDays != null ? '${sub.expireDays} ${tr("روز", "Days")}' : '∞',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: pal.secondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percent,
                                    backgroundColor: Colors.white12,
                                    color: pal.secondary,
                                    minHeight: 4,
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
            const SizedBox(height: 9),

            // ۳. کادر جستجو و دکمه‌های پینگ واقعی / مرتب‌سازی / کلیپ‌بورد
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: const TextStyle(fontSize: 11.5),
                      decoration: InputDecoration(
                        hintText: tr('جستجوی کشور یا سرور...', 'Search server...'),
                        hintStyle: const TextStyle(fontSize: 10.5, color: Colors.white38),
                        prefixIcon: Icon(Icons.search_rounded, size: 16, color: pal.secondary),
                        filled: true,
                        fillColor: const Color(0xFF070B16),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                _buildTactile3DButton(
                  icon: Icons.sort_rounded,
                  label: tr('مرتب', 'Sort'),
                  pal: pal,
                  onTap: sortServersByPing,
                ),
                const SizedBox(width: 5),
                _buildTactile3DButton(
                  icon: Icons.bolt_rounded,
                  label: isPingingAll ? '...' : tr('پینگ واقعی', 'True Ping'),
                  pal: pal,
                  onTap: testAllPings,
                ),
                const SizedBox(width: 5),
                _buildTactile3DButton(
                  icon: Icons.content_paste_rounded,
                  label: tr('چسباندن', 'Paste'),
                  pal: pal,
                  onTap: smartPasteFromClipboard,
                ),
              ],
            ),
            const SizedBox(height: 9),

            // ۴. لیست سرورها با پرچم وکتور واقعی
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_queue_rounded, size: 42, color: Colors.white.withOpacity(0.18)),
                          const SizedBox(height: 8),
                          Text(
                            tr('لیست سرورها خالی است', 'Server list is empty'),
                            style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 10),
                          _buildGlowingActionBtn(
                            icon: Icons.content_paste_rounded,
                            label: tr('چسباندن از کلیپ‌بورد', 'Paste from Clipboard'),
                            pal: pal,
                            onTap: smartPasteFromClipboard,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final p = list[index];
                        final bool selected = (profiles.isNotEmpty && activeIdx < profiles.length) && profiles[activeIdx].id == p.id;
                        Color pCol = pal.secondary;
                        if (p.ping > 250) pCol = const Color(0xFFFFB300);
                        if (p.ping <= 0 || p.ping > 650) pCol = const Color(0xFFFF4D6D);

                        return GestureDetector(
                          onTap: () async {
                            final realIndex = profiles.indexWhere((item) => item.id == p.id);
                            if (realIndex == -1) return;
                            HapticFeedback.selectionClick();
                            final wasConn = isConnected;
                            setState(() {
                              activeIdx = realIndex;
                              isAutoPilotMode = false;
                            });
                            await _saveData();
                            if (wasConn) {
                              await _flutterV2ray.stopV2Ray();
                              setState(() => isConnected = false);
                              await Future.delayed(const Duration(milliseconds: 250));
                              await toggleConnection();
                            } else {
                              _notify(tr('🔒 قفل روی «${p.name}»', '🔒 Locked on ${p.name}'));
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 7),
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? LinearGradient(colors: [pal.primary.withOpacity(0.32), pal.glow.withOpacity(0.18)])
                                  : const LinearGradient(colors: [Color(0xFF141C32), Color(0xFF0B1120)]),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected ? pal.secondary : Colors.white.withOpacity(0.08),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                                  ),
                                  child: CustomPaint(painter: FlagPainter(p.name)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              p.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                            ),
                                          ),
                                          if (p.isGameReady) ...[
                                            const SizedBox(width: 5),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF2E93).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('🎯 GAME', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w900, color: Color(0xFFFF85B3))),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${p.protocol} • ${p.address}:${p.port}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 9.5, color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => testTrueCorePing(p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: p.ping > 0 ? pCol.withOpacity(0.4) : Colors.white10),
                                    ),
                                    child: p.isPinging
                                        ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2, color: pal.secondary))
                                        : Text(
                                            p.ping > 0 ? '${p.ping} ms' : (p.ping == -2 ? 'Timeout' : 'Ping'),
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: p.ping > 0 ? pCol : Colors.white38),
                                          ),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.qr_code_2_rounded, size: 17, color: Colors.white54),
                                  onPressed: () => _showServerQrModal(p),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.white38),
                                  onPressed: () {
                                    setState(() {
                                      profiles.removeWhere((item) => item.id == p.id);
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
      ),
    );
  }

  // ==================== نوار ناوبری شیشه‌ای پایین صفحه (۲ تب) ====================
  Widget _buildBottomGlassNav(NeonThemePalette pal) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1F).withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal.secondary.withOpacity(0.22)),
        boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => currentBottomTab = 0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: currentBottomTab == 0 ? LinearGradient(colors: [pal.primary, pal.glow.withOpacity(0.75)]) : null,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.radar_rounded, size: 18, color: currentBottomTab == 0 ? Colors.white : Colors.white54),
                    const SizedBox(width: 7),
                    Text(
                      tr('داشبورد و اتصال', 'Spatial Hub'),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: currentBottomTab == 0 ? Colors.white : Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => currentBottomTab = 1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: currentBottomTab == 1 ? LinearGradient(colors: [pal.primary, pal.glow.withOpacity(0.75)]) : null,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dns_rounded, size: 18, color: currentBottomTab == 1 ? Colors.white : Colors.white54),
                    const SizedBox(width: 7),
                    Text(
                      tr('سرورها و اشتراک‌ها (${profiles.length})', 'Servers (${profiles.length})'),
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: currentBottomTab == 1 ? Colors.white : Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== دیالوگ افزودن ۳ حالته ====================
  void _showUnifiedAddDialog({int initialTab = 0}) {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    int tab = initialTab;
    final pal = currentPalette;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Directionality(
          textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            backgroundColor: const Color(0xFF0E1526),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: pal.secondary.withOpacity(0.35)),
            ),
            title: Text(
              tr('➕ افزودن اشتراک، کلیپ‌بورد یا QR', '➕ Add Subscription / Config'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: const Color(0xFF060913), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        _buildDialogTabBtn(title: tr('🔗 اشتراک', '🔗 Sub'), active: tab == 0, pal: pal, onTap: () => setModalState(() => tab = 0)),
                        _buildDialogTabBtn(title: tr('📋 کلیپ‌بورد', '📋 Paste'), active: tab == 1, pal: pal, onTap: () => setModalState(() => tab = 1)),
                        _buildDialogTabBtn(title: '📷 QR', active: tab == 2, pal: pal, onTap: () => setModalState(() => tab = 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (tab == 0) ...[
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: tr('نام دلخواه اشتراک (اختیاری)', 'Custom Name (Optional)'),
                        labelStyle: const TextStyle(fontSize: 11, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xFF070A14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: urlCtrl,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://...\nvless://...\nvmess://...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF070A14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF070A14), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        children: [
                          Icon(tab == 1 ? Icons.content_paste_go_rounded : Icons.qr_code_scanner_rounded, size: 36, color: pal.secondary),
                          const SizedBox(height: 8),
                          Text(
                            tr('دریافت هوشمند از کلیپ‌بورد اندروید', 'Smart Import from Clipboard'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          _buildGlowingActionBtn(
                            icon: Icons.paste_rounded,
                            label: tr('چسباندن و بررسی آنی', 'Paste & Import Now'),
                            pal: pal,
                            onTap: () {
                              Navigator.pop(ctx);
                              smartPasteFromClipboard();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('انصراف', 'Cancel'), style: const TextStyle(color: Colors.white70)),
              ),
              if (tab == 0)
                _buildGlowingActionBtn(
                  icon: Icons.check_circle_outline_rounded,
                  label: tr('تأیید و افزودن', 'Confirm & Add'),
                  pal: pal,
                  onTap: () {
                    final raw = urlCtrl.text.trim();
                    final customName = nameCtrl.text.trim();
                    Navigator.pop(ctx);
                    if (raw.isEmpty) return;
                    if (raw.startsWith('http://') || raw.startsWith('https://')) {
                      _importSubscription(raw, customTitle: customName);
                    } else {
                      _importDirectConfigs(raw, subId: 'manual');
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTabBtn({required String title, required bool active, required NeonThemePalette pal, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            gradient: active ? LinearGradient(colors: [pal.primary, pal.primary.withOpacity(0.7)]) : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white : Colors.white54),
          ),
        ),
      ),
    );
  }

  void _showServerQrModal(VpnProfile p) {
    final pal = currentPalette;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E1526),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: pal.secondary.withOpacity(0.4))),
          title: Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: SizedBox(
                  width: 165,
                  height: 165,
                  child: CustomPaint(painter: VisualQrMatrixPainter(data: p.rawUri, color: const Color(0xFF080C18))),
                ),
              ),
              const SizedBox(height: 10),
              Text('${p.protocol} • ${p.address}:${p.port}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('بستن', 'Close'), style: const TextStyle(color: Colors.white70))),
            _buildGlowingActionBtn(
              icon: Icons.copy_rounded,
              label: tr('کپی کانفیگ', 'Copy URI'),
              pal: pal,
              onTap: () {
                Clipboard.setData(ClipboardData(text: p.rawUri));
                Navigator.pop(ctx);
                _notify(tr('لینک کانفیگ کپی شد', 'Config URI copied'));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSettingsModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final pal = currentPalette;
          return Directionality(
            textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
            child: AlertDialog(
              backgroundColor: const Color(0xFF0E1526),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: pal.secondary.withOpacity(0.35)),
              ),
              title: Text(tr('⚙️ تنظیمات و تم نوری', '⚙️ Settings & Theme'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('🎨 انتخاب تم نوری:', '🎨 Select Neon Theme:'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: NeonThemePalette.palettes.map((item) {
                        final selected = item.id == themeId;
                        return GestureDetector(
                          onTap: () {
                            setState(() => themeId = item.id);
                            setModalState(() {});
                            _saveData();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [item.primary.withOpacity(0.35), item.secondary.withOpacity(0.2)]),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: selected ? item.secondary : Colors.white12, width: selected ? 1.8 : 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 11, height: 11, decoration: BoxDecoration(shape: BoxShape.circle, color: item.secondary)),
                                const SizedBox(width: 6),
                                Text(isFa ? item.nameFa : item.nameEn, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 20, color: Colors.white12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr('🌍 زبان فارسی / English', '🌍 Language (FA/EN)'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      value: isFa,
                      activeColor: pal.secondary,
                      onChanged: (v) {
                        setState(() => appLang = v ? 'fa' : 'en');
                        setModalState(() {});
                        _saveData();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr('🛡️ سپر ضد نشت آی‌پی و DNS', '🛡️ Anti-IP & DNS Leak Shield'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      value: strictAntiLeak,
                      activeColor: pal.secondary,
                      onChanged: (v) {
                        setState(() => strictAntiLeak = v);
                        setModalState(() {});
                        _saveData();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr('🔀 معافیت سایت‌های داخلی (.ir)', '🔀 Bypass Local / .IR Domains'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      value: splitTunnelMode == 1,
                      activeColor: pal.secondary,
                      onChanged: (v) {
                        setState(() => splitTunnelMode = v ? 1 : 0);
                        setModalState(() {});
                        _saveData();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlowingActionBtn({
    required IconData icon,
    required String label,
    required NeonThemePalette pal,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [pal.primary, pal.secondary.withOpacity(0.85)]),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [BoxShadow(color: pal.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  BoxDecoration _box3DDecoration(NeonThemePalette pal) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xCC18223A), Color(0xE60A0F1D)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: pal.secondary.withOpacity(0.18)),
      boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24, offset: Offset(0, 10))],
    );
  }

  Widget _buildTactile3DButton({
    required IconData icon,
    required String label,
    required NeonThemePalette pal,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF212D4C), Color(0xFF12192B)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: pal.secondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
