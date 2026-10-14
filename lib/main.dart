// ============================================
// Kitabi v0.1 — تطبيق تعليمي للطلاب الليبيين
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

// ============ إعدادات Supabase ============
const String kSupabaseUrl = 'https://vlyfghfoelbbbdljbvcr.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_d4ZrC9cHXb8YvzyvlRkeCA_GOMtyzgt';

// وصول سريع
final supabase = Supabase.instance.client;

// ============ نموذج إحصائيات المستخدم ============
class UserStats {
  static Future<Map<String, int>> get() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'points': prefs.getInt('user_points') ?? 0,
      'level': prefs.getInt('user_level') ?? 1,
      'achievements': prefs.getInt('user_achievements') ?? 0,
    };
  }

  static Future<void> addPoints(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('user_points') ?? 0;
    final newVal = current + amount;
    await prefs.setInt('user_points', newVal);
    final level = (newVal ~/ 100) + 1;
    await prefs.setInt('user_level', level);
    await prefs.setInt('user_achievements', level - 1);
  }
}

// ============ SnackBar مخصص ============
void showKitabiSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      backgroundColor: const Color(0xFF2C2C2E),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.only(left: 30, right: 0, bottom: 95),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      duration: const Duration(seconds: 2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          topRight: Radius.zero,
          bottomRight: Radius.zero,
        ),
      ),
    ),
  );
}

// ============ Main ============
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const KitabiApp());
}

// ============ KitabiApp ============
class KitabiApp extends StatelessWidget {
  const KitabiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitabi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

// ============ Splash Screen ============
// ============ Login Screen (Email) ============
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      showKitabiSnack(context, 'اكتب بريدك الإلكتروني');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      showKitabiSnack(context, 'البريد غير صحيح');
      return;
    }

    setState(() => _sending = true);
    try {
      await supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: email),
        ),
      );
    } catch (e) {
      debugPrint('Send OTP error: $e');
      if (!mounted) return;
      showKitabiSnack(context, 'فشل الإرسال: تحقق من الإيميل');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // أيقونة
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.35),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 30),
              const Center(
                child: Text('KITABI',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Color(0xFF1A1A1A))),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('كتابي — تطبيق تعليمي ليبي',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF555555))),
              ),
              const SizedBox(height: 50),
              const Text('تسجيل الدخول',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 8),
              const Text('أدخل بريدك الإلكتروني وسنرسل لك رمز التحقق',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF555555))),
              const SizedBox(height: 25),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'example@gmail.com',
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: Color(0xFF1565C0)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: Color(0xFF1565C0), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 20),
                            SizedBox(width: 10),
                            Text('إرسال رمز التحقق',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 25),
              // ملاحظة
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF1565C0), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'سيصلك رمز مكوّن من 6 أرقام على بريدك. تحقق من مجلد Spam إذا لم تجده.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF555555),
                            height: 1.5),
                      ),
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
}

// ============ OTP Screen (Verify Code) ============
class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _verifying = false;

  Future<void> _verify() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      showKitabiSnack(context, 'الرمز مكون من 6 أرقام');
      return;
    }

    setState(() => _verifying = true);
    try {
      final response = await supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.email,
      );

      if (response.user == null) {
        if (!mounted) return;
        showKitabiSnack(context, 'الرمز غير صحيح');
        return;
      }

      // نفحص: هل المستخدم مسجل في جدول users؟
      final existing = await supabase
          .from('users')
          .select()
          .eq('email', widget.email)
          .limit(1);

      if (!mounted) return;

      if (existing.isEmpty) {
        // مستخدم جديد → شاشة البيانات
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(userEmail: widget.email),
          ),
        );
      } else {
        // مستخدم مسجل → نحفظ بياناته
        final prefs = await SharedPreferences.getInstance();
        final user = existing[0];
        await prefs.setString('user_name', user['name'] ?? '');
        await prefs.setString('user_grade', user['grade'] ?? '');
        await prefs.setString('user_muraqaba', user['muraqaba'] ?? '');
        await prefs.setString('user_email', widget.email);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } catch (e) {
      debugPrint('Verify error: $e');
      if (!mounted) return;
      showKitabiSnack(context, 'الرمز غير صحيح أو منتهي');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text('تأكيد الرمز',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_outlined,
                      size: 60, color: Color(0xFF1565C0)),
                ),
              ),
              const SizedBox(height: 25),
              const Center(
                child: Text('تحقق من بريدك',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'أرسلنا رمز مكوّن من 6 أرقام إلى:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF555555),
                      height: 1.6),
                ),
              ),
              const SizedBox(height: 35),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 28,
                      letterSpacing: 12),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                        color: Color(0xFF1565C0), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _verifying ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('تحقق',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    try {
                      await supabase.auth.signInWithOtp(
                          email: widget.email,
                          shouldCreateUser: true);
                      if (!mounted) return;
                      showKitabiSnack(context, 'تم إعادة الإرسال');
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة إرسال الرمز'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 1) نفحص جلسة Supabase
    final session = supabase.auth.currentSession;
    if (session == null) {
      // ما فيه جلسة → LoginScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final userEmail = session.user.email ?? '';
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');

    // 2) نفحص الحظر من جدول users
    bool banned = false;
    bool hasProfile = false;
    try {
      final data = await supabase
          .from('users')
          .select('is_banned, name, grade, muraqaba')
          .eq('email', userEmail)
          .limit(1);
      if (data.isNotEmpty) {
        hasProfile = true;
        if (data[0]['is_banned'] == true) banned = true;
        // نحدث SharedPreferences
        await prefs.setString('user_name', data[0]['name'] ?? '');
        await prefs.setString('user_grade', data[0]['grade'] ?? '');
        await prefs.setString('user_muraqaba', data[0]['muraqaba'] ?? '');
        await prefs.setString('user_email', userEmail);
      }
    } catch (e) {
      debugPrint('Check error: $e');
    }

    if (!mounted) return;

    if (banned) {
      await supabase.auth.signOut();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BannedScreen()),
      );
      return;
    }

    if (!hasProfile) {
      // مسجل بالإيميل لكن ما عبّى بياناته
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(userEmail: userEmail),
        ),
      );
      return;
    }

    // مستخدم كامل → HomeShell
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.menu_book_rounded,
                  size: 80, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 30),
            const Text('KITABI',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6)),
            const SizedBox(height: 8),
            const Text('كتابي',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Banned Screen ============
class BannedScreen extends StatelessWidget {
  const BannedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade200, width: 3),
                ),
                child: const Icon(Icons.block, size: 80, color: Colors.red),
              ),
              const SizedBox(height: 30),
              const Text('تم حظر حسابك',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 15),
              const Text(
                  'تم إيقاف حسابك من قبل إدارة التطبيق\nلأسباب تتعلق بمخالفة السياسات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF555555),
                      height: 1.6)),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 14),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1565C0)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('للتواصل مع الإدارة: support@kitabi.ly',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF555555))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة لاحقاً'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF555555),
                    side: const BorderSide(color: Color(0xFFE5E5E5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Register Screen ============
class RegisterScreen extends StatefulWidget {
  final String? userEmail;
  const RegisterScreen({super.key, this.userEmail});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  String? _selectedGrade;
  String? _selectedMuraqaba;
  bool _saving = false;

  final List<String> _grades = [
    'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
    'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
    'أول إعدادي', 'ثاني إعدادي', 'ثالث إعدادي',
    'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي',
  ];

  final List<String> _muraqabat = [
    'مراقبة طرابلس', 'مراقبة بنغازي', 'مراقبة مصراتة',
    'مراقبة الزاوية', 'مراقبة قصر الأخيار', 'مراقبة الخمس',
    'مراقبة زليتن', 'مراقبة سبها', 'مراقبة البيضاء', 'مراقبة درنة',
  ];

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب اسمك');
      return;
    }
    if (_selectedGrade == null) {
      showKitabiSnack(context, 'اختر صفك');
      return;
    }
    if (_selectedMuraqaba == null) {
      showKitabiSnack(context, 'اختر مراقبتك');
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    final email = widget.userEmail ??
        supabase.auth.currentUser?.email ??
        '';
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('user_grade', _selectedGrade!);
    await prefs.setString('user_muraqaba', _selectedMuraqaba!);
    await prefs.setString('user_email', email);

    final currentPts = prefs.getInt('user_points') ?? 0;
    if (currentPts == 0) {
      await prefs.setInt('user_points', 50);
      await prefs.setInt('user_level', 1);
      await prefs.setInt('user_achievements', 0);
    }

    // حفظ في Supabase
    try {
      final existing = await supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .limit(1);
      if (existing.isEmpty) {
        await supabase.from('users').insert({
          'name': _nameController.text.trim(),
          'email': email,
          'grade': _selectedGrade,
          'muraqaba': _selectedMuraqaba,
          'points': 50,
          'level': 1,
          'achievements': 0,
        });
      } else {
        await supabase.from('users').update({
          'name': _nameController.text.trim(),
          'grade': _selectedGrade,
          'muraqaba': _selectedMuraqaba,
        }).eq('email', email);
      }
    } catch (e) {
      debugPrint('Supabase insert error: $e');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.35),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_add_alt_1,
                      size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 25),
              const Center(
                child: Text('مرحباً بك في كتابي',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text('سجل بياناتك لتبدأ رحلتك التعليمية',
                    style: TextStyle(
                        fontSize: 15, color: Color(0xFF555555))),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                decoration: _inputDeco('الاسم الكامل', Icons.person),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: _selectedGrade,
                decoration: _inputDeco('الصف الدراسي', Icons.school),
                items: _grades
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedGrade = v),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: _selectedMuraqaba,
                decoration: _inputDeco('المراقبة', Icons.location_city),
                items: _muraqabat
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedMuraqaba = v),
              ),
              const SizedBox(height: 35),
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('دخول',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Home Shell ============
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(onStartLearning: () => _goToTab(1)),
      const LibraryTab(),
      const NotificationsTab(),
      const AccountTab(),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF5F7FA),
      body: tabs[_index],
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 14),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_outlined, Icons.home, 'الرئيسية'),
              _navItem(1, Icons.menu_book_outlined, Icons.menu_book, 'المكتبة'),
              _navItem(2, Icons.notifications_outlined, Icons.notifications,
                  'الإشعارات'),
              _navItem(3, Icons.person_outline, Icons.person, 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final bool selected = _index == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => _goToTab(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1565C0)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    color: selected ? Colors.white : Colors.white60,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w400,
                    color: selected ? Colors.white : Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ Home Tab ============
class HomeTab extends StatelessWidget {
  final VoidCallback onStartLearning;
  const HomeTab({super.key, required this.onStartLearning});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: MediaQuery.of(context).padding.bottom + 110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_book,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KITABI',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: Color(0xFF1A1A1A))),
                      Text('كتابي',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF555555),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: Color(0xFF1565C0), size: 26),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 18),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.settings_outlined,
                      color: Color(0xFF1565C0), size: 26),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.35),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=1200&q=80',
                      fit: BoxFit.cover,
                      loadingBuilder: (c, child, p) => Container(
                        color: const Color(0xFF1565C0),
                        child: p == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)),
                      ),
                      errorBuilder: (c, e, s) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                        ),
                        child: const Icon(Icons.school,
                            size: 100, color: Colors.white54),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.78),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade600,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('الإصدار 0.1 تجريبي',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          const Text(
                            'التعلم هو مفتاح النجاح',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 8,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'كل أبواب النجاح',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                    color: Colors.black54, blurRadius: 6),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: onStartLearning,
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 24),
                              label: const Text('ابدأ التعلم',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1565C0),
                                elevation: 6,
                                shadowColor: Colors.black45,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
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
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
              children: [
                _quickBtn(context, 'المكتبة', Icons.menu_book_rounded,
                    const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                    onStartLearning),
                _quickBtn(context, 'الدورات', Icons.school_rounded,
                    const LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF26A69A)]),
                    () => showKitabiSnack(context, 'الدورات — قريباً')),
                _quickBtn(context, 'المعلم الذكي', Icons.smart_toy_rounded,
                    const LinearGradient(
                        colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)]),
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TeacherAIScreen()),
                  );
                }),
                _quickBtn(context, 'المنتدى', Icons.forum_rounded,
                    const LinearGradient(
                        colors: [Color(0xFF283593), Color(0xFF3F51B5)]),
                    () => showKitabiSnack(context, 'المنتدى — قريباً')),
                _quickBtn(context, 'الاختبارات', Icons.assignment_rounded,
                    const LinearGradient(
                        colors: [Color(0xFFEF6C00), Color(0xFFFFA726)]),
                    () => showKitabiSnack(context, 'الاختبارات — قريباً')),
                _quickBtn(context, 'ملاحظاتي', Icons.sticky_note_2_rounded,
                    const LinearGradient(
                        colors: [Color(0xFF00838F), Color(0xFF00ACC1)]),
                    () => showKitabiSnack(context, 'ملاحظاتي — قريباً')),
                _quickBtn(context, 'فيديوهات', Icons.play_circle_fill_rounded,
                    const LinearGradient(
                        colors: [Color(0xFFD32F2F), Color(0xFFEF5350)]),
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const VideosScreen()),
                  );
                }),
                _quickBtn(context, 'شيتات وأوراق', Icons.description_rounded,
                    const LinearGradient(
                        colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SheetsScreen()),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('أحدث الدروس',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _lessonCard('الرياضيات — الفصل الأول', 'الأساس والغلاف',
                Icons.calculate_rounded,
                const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)])),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _lessonCard('العلوم الطبيعية', 'مقدمة في الأحياء',
                Icons.science_rounded,
                const LinearGradient(
                    colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)])),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _quickBtn(BuildContext context, String label, IconData icon,
      Gradient grad, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: grad,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: grad.colors.first.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lessonCard(String title, String subtitle, IconData icon,
      Gradient grad) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: grad,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF555555))),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: grad.colors.first.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow_rounded,
                color: grad.colors.first, size: 22),
          ),
        ],
      ),
    );
  }
}

// ============ Library Tab ============
class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  static const Map<String, List<String>> _subjectsByGrade = {
    'أول ابتدائي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب'],
    'ثاني ابتدائي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب'],
    'ثالث ابتدائي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم'],
    'رابع ابتدائي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
    'خامس ابتدائي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
    'سادس ابتدائي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
    'أول إعدادي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
    'ثاني إعدادي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
    'ثالث إعدادي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
    'أولى ثانوي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
    'ثانية ثانوي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
    'ثالثة ثانوي': ['الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية', 'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات'],
  };

  static const Map<String, IconData> _subjectIcons = {
    'الرياضيات': Icons.calculate_rounded,
    'اللغة العربية': Icons.translate_rounded,
    'اللغة الإنجليزية': Icons.language_rounded,
    'التربية الإسلامية': Icons.mosque_rounded,
    'الحاسوب': Icons.computer_rounded,
    'العلوم': Icons.science_rounded,
    'الاجتماعيات': Icons.public_rounded,
  };

  static const Map<String, Color> _subjectColors = {
    'الرياضيات': Color(0xFF1565C0),
    'اللغة العربية': Color(0xFF00897B),
    'اللغة الإنجليزية': Color(0xFF7B1FA2),
    'التربية الإسلامية': Color(0xFF00838F),
    'الحاسوب': Color(0xFF283593),
    'العلوم': Color(0xFFEF6C00),
    'الاجتماعيات': Color(0xFFD32F2F),
  };

  static const List<Map<String, dynamic>> _grades = [
    {'name': 'أول ابتدائي', 'icon': Icons.looks_one, 'color': 0xFF42A5F5, 'locked': false},
    {'name': 'ثاني ابتدائي', 'icon': Icons.looks_two, 'color': 0xFF42A5F5, 'locked': false},
    {'name': 'ثالث ابتدائي', 'icon': Icons.looks_3, 'color': 0xFF26A69A, 'locked': false},
    {'name': 'رابع ابتدائي', 'icon': Icons.looks_4, 'color': 0xFF26A69A, 'locked': false},
    {'name': 'خامس ابتدائي', 'icon': Icons.looks_5, 'color': 0xFF66BB6A, 'locked': false},
    {'name': 'سادس ابتدائي', 'icon': Icons.looks_6, 'color': 0xFF66BB6A, 'locked': false},
    {'name': 'أول إعدادي', 'icon': Icons.school, 'color': 0xFFFFA726, 'locked': false},
    {'name': 'ثاني إعدادي', 'icon': Icons.school, 'color': 0xFFFFA726, 'locked': false},
    {'name': 'ثالث إعدادي', 'icon': Icons.school, 'color': 0xFFEF6C00, 'locked': true},
    {'name': 'أولى ثانوي', 'icon': Icons.workspace_premium, 'color': 0xFF7E57C2, 'locked': true},
    {'name': 'ثانية ثانوي', 'icon': Icons.workspace_premium, 'color': 0xFF5E35B1, 'locked': true},
    {'name': 'ثالثة ثانوي', 'icon': Icons.workspace_premium, 'color': 0xFF4527A0, 'locked': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            bottom: 10,
          ),
          child: const Row(
            children: [
              Icon(Icons.menu_book, color: Color(0xFF1565C0), size: 28),
              SizedBox(width: 10),
              Text('المكتبة',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('اختر صفك الدراسي لعرض المواد',
              style: TextStyle(color: Color(0xFF555555), fontSize: 13)),
        ),
        const SizedBox(height: 15),
        // تبويبين: كتب / شيتات
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('الكتب',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SheetsScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: const Text('الشيتات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF555555),
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 4, 20,
                MediaQuery.of(context).padding.bottom + 110),
            itemCount: _grades.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final g = _grades[i];
              final subjects = _subjectsByGrade[g['name']] ?? <String>[];
              final locked = g['locked'] == true;
              return Opacity(
                opacity: locked ? 0.55 : 1.0,
                child: Container(
                height: 82,
                decoration: BoxDecoration(
                  color: locked ? Colors.grey.shade100 : Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(locked ? 0.03 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () {
                      if (locked) {
                        showKitabiSnack(context,
                            'هذا الصف سيُفتح في الإصدار 0.5');
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GradeSubjectsScreen(
                            gradeName: g['name'],
                            subjects: subjects,
                            icons: _subjectIcons,
                            colors: _subjectColors,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Color(g['color']).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(g['icon'],
                                size: 30, color: Color(g['color'])),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(g['name'],
                                    style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A))),
                                const SizedBox(height: 3),
                                Text('${subjects.length} مواد',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF555555))),
                              ],
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios_new,
                                size: 14, color: Color(0xFF1565C0)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ));
            },
          ),
        ),
      ],
    );
  }
}

// ============ Grade Subjects Screen ============
class GradeSubjectsScreen extends StatelessWidget {
  final String gradeName;
  final List<String> subjects;
  final Map<String, IconData> icons;
  final Map<String, Color> colors;

  const GradeSubjectsScreen({
    super.key,
    required this.gradeName,
    required this.subjects,
    required this.icons,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(gradeName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: subjects.isEmpty
          ? const Center(
              child: Text('لا توجد مواد',
                  style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final s = subjects[i];
                final color = colors[s] ?? const Color(0xFF1565C0);
                final icon = icons[s] ?? Icons.book_rounded;
                return Container(
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubjectBooksScreen(
                              gradeName: gradeName,
                              subjectName: s,
                              subjectColor: color,
                              subjectIcon: icon,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(icon, size: 28, color: color),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(s,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A))),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.arrow_back_ios_new,
                                  size: 13, color: color),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============ Subject Books Screen ============
class SubjectBooksScreen extends StatefulWidget {
  final String gradeName;
  final String subjectName;
  final Color subjectColor;
  final IconData subjectIcon;

  const SubjectBooksScreen({
    super.key,
    required this.gradeName,
    required this.subjectName,
    required this.subjectColor,
    required this.subjectIcon,
  });

  @override
  State<SubjectBooksScreen> createState() => _SubjectBooksScreenState();
}

class _SubjectBooksScreenState extends State<SubjectBooksScreen> {
  List<Map<String, dynamic>> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('books')
          .select()
          .eq('grade', widget.gradeName)
          .eq('subject', widget.subjectName)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _books = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load books error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.subjectName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: widget.subjectColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF1565C0)))
          : _books.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadBooks,
                  color: widget.subjectColor,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _books.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _bookCard(_books[i]),
                  ),
                ),
    );
  }

  Widget _bookCard(Map<String, dynamic> book) {
    final isImages = book['book_type'] == 'images';
    final imagesCount = isImages
        ? (book['image_urls'] as List?)?.length ?? 0
        : 0;
    final customCover = book['cover_url'] as String?;
    final coverUrl = customCover != null && customCover.isNotEmpty
        ? customCover
        : (isImages && imagesCount > 0
            ? (book['image_urls'] as List)[0] as String
            : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookReaderScreen(book: book),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // صورة الغلاف
                Container(
                  width: 70,
                  height: 90,
                  decoration: BoxDecoration(
                    color: widget.subjectColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: coverUrl != null
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              widget.subjectIcon,
                              color: widget.subjectColor,
                              size: 32),
                        )
                      : Icon(widget.subjectIcon,
                          color: widget.subjectColor, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.gradeName,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555)),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.subjectColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isImages
                              ? '📸 $imagesCount صورة'
                              : '📄 PDF',
                          style: TextStyle(
                              fontSize: 11,
                              color: widget.subjectColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: widget.subjectColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_ios_new,
                      size: 14, color: widget.subjectColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: widget.subjectColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.menu_book_outlined,
                size: 60, color: widget.subjectColor),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد كتب لهذه المادة بعد',
              style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
          const SizedBox(height: 8),
          const Text('سيتم إضافة الكتب قريباً',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ============ Book Reader Screen ============
class BookReaderScreen extends StatefulWidget {
  final Map<String, dynamic> book;
  const BookReaderScreen({super.key, required this.book});

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  int _currentPage = 0;
  List<String> _imageUrls = [];
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    if (widget.book['book_type'] == 'images') {
      _imageUrls = List<String>.from(widget.book['image_urls'] ?? []);
    }
    _logRead();
  }

  Future<void> _logRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? 'unknown';
      final bookId = widget.book['id'];

      if (bookId == null) return;

      // نتحقق: هل سبق قرأ هذا الكتاب؟
      final existing = await supabase
          .from('book_reads')
          .select('id')
          .eq('book_id', bookId)
          .eq('user_name', userName)
          .limit(1);

      if (existing.isNotEmpty) {
        // سبق قرأه → لا نسجل
        return;
      }

      // نسجل القراءة الجديدة
      await supabase.from('book_reads').insert({
        'book_id': bookId,
        'user_name': userName,
      });

      // نزيد read_count في books
      final current = widget.book['read_count'] ?? 0;
      await supabase
          .from('books')
          .update({'read_count': (current as int) + 1})
          .eq('id', bookId);
    } catch (e) {
      debugPrint('Log read error: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_imageUrls.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.book['title'] ?? ''),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('لا توجد صفحات')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.book['title'] ?? '',
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_currentPage + 1} / ${_imageUrls.length}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _imageUrls.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    _imageUrls[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, p) => p == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white)),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          size: 80, color: Colors.white54),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // شريط التنقل
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _currentPage > 0
                      ? () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut)
                      : null,
                  icon: const Icon(Icons.arrow_forward,
                      color: Colors.white),
                ),
                Text(
                  'الصفحة ${_currentPage + 1}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                ),
                IconButton(
                  onPressed: _currentPage < _imageUrls.length - 1
                      ? () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut)
                      : null,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ============ Notifications Tab ============
class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});
  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final data = await supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _notifications = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الإشعارات';
        _loading = false;
      });
      debugPrint('Load notifications error: $e');
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
      if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
      return '${d.year}/${d.month}/${d.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            bottom: 10,
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications,
                  color: Color(0xFF1565C0), size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('الإشعارات',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ),
              IconButton(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh,
                    color: Color(0xFF1565C0), size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF1565C0)),
                )
              : _error.isNotEmpty
                  ? _buildError()
                  : _notifications.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _loadNotifications,
                          color: const Color(0xFF1565C0),
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                                20, 8, 20,
                                MediaQuery.of(context).padding.bottom + 110),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) =>
                                _notifCard(_notifications[i]),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _notifCard(Map<String, dynamic> n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign,
                    color: Color(0xFF1565C0), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(n['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(n['body'] ?? '',
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF333333),
                  height: 1.5)),
          const SizedBox(height: 8),
          Text(_formatDate(n['created_at']),
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF888888))),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 15),
              ],
            ),
            child: const Icon(Icons.notifications_off,
                size: 60, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد إشعارات حالياً',
              style: TextStyle(fontSize: 18, color: Color(0xFF555555))),
          const SizedBox(height: 8),
          const Text('ستظهر هنا الإشعارات الجديدة',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 15),
          Text(_error,
              style: const TextStyle(
                  fontSize: 16, color: Color(0xFF555555))),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============ Account Tab ============
class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  String _name = '';
  String _grade = '';
  String _muraqaba = '';
  int _points = 0;
  int _level = 1;
  int _achievements = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await UserStats.get();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('user_name') ?? 'طالب';
      _grade = prefs.getString('user_grade') ?? '';
      _muraqaba = prefs.getString('user_muraqaba') ?? '';
      _points = stats['points'] ?? 0;
      _level = stats['level'] ?? 1;
      _achievements = stats['achievements'] ?? 0;
    });
  }

  Future<void> _logout() async {
    // نسأل المستخدم
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من الحساب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.auth.signOut();
    } catch (e) {
      debugPrint('SignOut error: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Color _avatarColor() {
    if (_name.isEmpty) return const Color(0xFF1565C0);
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF00897B),
      const Color(0xFF7B1FA2),
      const Color(0xFFEF6C00),
      const Color(0xFF283593),
      const Color(0xFFD32F2F),
      const Color(0xFF00838F),
    ];
    return colors[_name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: MediaQuery.of(context).padding.bottom + 110,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_avatarColor(), _avatarColor().withOpacity(0.7)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _avatarColor().withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _name.isNotEmpty ? _name[0] : '؟',
                            style: TextStyle(
                              color: _avatarColor(),
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => showKitabiSnack(
                              context, 'تغيير الصورة — قريباً'),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(_name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_grade.isNotEmpty ? _grade : 'طالب',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _statItem(Icons.local_fire_department, 'النقاط',
                      '$_points', const Color(0xFFFF6B35)),
                  _vDivider(),
                  _statItem(Icons.star, 'المستوى', '$_level',
                      const Color(0xFFFFB300)),
                  _vDivider(),
                  _statItem(Icons.emoji_events, 'الإنجازات',
                      '$_achievements', const Color(0xFF7E57C2)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15),
                ],
              ),
              child: Column(
                children: [
                  _menuItem(Icons.person_outline, 'معلوماتي الشخصية',
                      const Color(0xFF1565C0),
                      () => showKitabiSnack(context, 'معلوماتي — قريباً')),
                  _menuDivider(),
                  _menuItem(Icons.track_changes, 'أهدافي التعليمية',
                      const Color(0xFF66BB6A),
                      () => showKitabiSnack(context, 'أهدافي — قريباً')),
                  _menuDivider(),
                  _menuItem(Icons.notifications_none, 'إشعاراتي',
                      const Color(0xFFFFA726),
                      () => showKitabiSnack(context, 'الإشعارات — قريباً')),
                  _menuDivider(),
                  _menuItem(Icons.dark_mode_outlined,
                      'المظهر (الوضع الليلي)', const Color(0xFF7E57C2), () {
                    showKitabiSnack(context, 'قريباً في الإصدار القادم');
                  }),
                  _menuDivider(),
                  _menuItem(Icons.help_outline, 'المساعدة والدعم',
                      const Color(0xFF26A69A),
                      () => showKitabiSnack(context, 'المساعدة — قريباً')),
                  _menuDivider(),
                  _menuItem(Icons.info_outline, 'عن التطبيق',
                      const Color(0xFF5E35B1), () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'KITABI',
                      applicationVersion: '0.1.0',
                      applicationIcon: const Icon(Icons.menu_book,
                          size: 40, color: Color(0xFF1565C0)),
                      children: const [
                        Text(
                            'تطبيق تعليمي مجاني للطلاب الليبيين.\nجميع الخصائص مجانية بالكامل.'),
                      ],
                    );
                  }),
                  _menuDivider(),
                  _menuItem(Icons.admin_panel_settings, 'غرفة التحكم',
                      const Color(0xFFEF6C00), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ControlRoomScreen()),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('تسجيل خروج',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF555555))),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 40,
        color: const Color(0xFFE5E5E5),
      );

  Widget _menuItem(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1A1A1A))),
      trailing: const Icon(Icons.arrow_back_ios,
          size: 14, color: Color(0xFF555555)),
      onTap: onTap,
    );
  }

  Widget _menuDivider() => const Divider(
      height: 1, indent: 70, endIndent: 15, color: Color(0xFFF0F0F0));
}

// ============ Control Room Screen ============
// ============ Sheets Screen (شيتات وأوراق تعلمية) ============
class SheetsScreen extends StatefulWidget {
  const SheetsScreen({super.key});
  @override
  State<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends State<SheetsScreen> {
  static const List<Map<String, dynamic>> _grades = [
    {'name': 'أول ابتدائي', 'icon': Icons.looks_one},
    {'name': 'ثاني ابتدائي', 'icon': Icons.looks_two},
    {'name': 'ثالث ابتدائي', 'icon': Icons.looks_3},
    {'name': 'رابع ابتدائي', 'icon': Icons.looks_4},
    {'name': 'خامس ابتدائي', 'icon': Icons.looks_5},
    {'name': 'سادس ابتدائي', 'icon': Icons.looks_6},
    {'name': 'أول إعدادي', 'icon': Icons.school},
    {'name': 'ثاني إعدادي', 'icon': Icons.school},
  ];

  static const List<Map<String, dynamic>> _subjects = [
    {'name': 'الرياضيات', 'icon': Icons.calculate_rounded, 'color': 0xFF1565C0},
    {'name': 'اللغة العربية', 'icon': Icons.translate_rounded, 'color': 0xFF00897B},
    {'name': 'اللغة الإنجليزية', 'icon': Icons.language_rounded, 'color': 0xFF7B1FA2},
    {'name': 'التربية الإسلامية', 'icon': Icons.mosque_rounded, 'color': 0xFF00838F},
    {'name': 'الحاسوب', 'icon': Icons.computer_rounded, 'color': 0xFF283593},
    {'name': 'العلوم', 'icon': Icons.science_rounded, 'color': 0xFFEF6C00},
    {'name': 'الاجتماعيات', 'icon': Icons.public_rounded, 'color': 0xFFD32F2F},
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('شيتات وأوراق تعلمية',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF00695C),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'حسب الصف', icon: Icon(Icons.school, size: 18)),
              Tab(text: 'حسب المادة', icon: Icon(Icons.book, size: 18)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildByGrade(),
            _buildBySubject(),
          ],
        ),
      ),
    );
  }

  Widget _buildByGrade() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _grades.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final g = _grades[i];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00695C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(g['icon'],
                  color: const Color(0xFF00695C), size: 28),
            ),
            title: Text(g['name'],
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_back_ios,
                size: 14, color: Color(0xFF555555)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SheetsListScreen(
                    grade: g['name'],
                    subject: null,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBySubject() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: _subjects.length,
      itemBuilder: (_, i) {
        final s = _subjects[i];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SheetsListScreen(
                      grade: null,
                      subject: s['name'],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Color(s['color']).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(s['icon'],
                          color: Color(s['color']), size: 34),
                    ),
                    const SizedBox(height: 10),
                    Text(s['name'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ============ Sheets List Screen ============
class SheetsListScreen extends StatefulWidget {
  final String? grade;
  final String? subject;

  const SheetsListScreen({super.key, this.grade, this.subject});

  @override
  State<SheetsListScreen> createState() => _SheetsListScreenState();
}

class _SheetsListScreenState extends State<SheetsListScreen> {
  List<Map<String, dynamic>> _sheets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSheets();
  }

  Future<void> _loadSheets() async {
    setState(() => _loading = true);
    try {
      var query = supabase
          .from('books')
          .select()
          .eq('category', 'sheets');

      if (widget.grade != null) {
        query = query.eq('grade', widget.grade!);
      }
      if (widget.subject != null) {
        query = query.eq('subject', widget.subject!);
      }

      final data = await query;
      if (!mounted) return;
      setState(() {
        _sheets = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load sheets error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String get _title {
    if (widget.grade != null && widget.subject != null) {
      return '${widget.grade} - ${widget.subject}';
    }
    if (widget.grade != null) return widget.grade!;
    if (widget.subject != null) return widget.subject!;
    return 'شيتات';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00695C)))
          : _sheets.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadSheets,
                  color: const Color(0xFF00695C),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sheets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _sheetCard(_sheets[i]),
                  ),
                ),
    );
  }

  Widget _sheetCard(Map<String, dynamic> sheet) {
    final count = (sheet['image_urls'] as List?)?.length ?? 0;
    final customCover = sheet['cover_url'] as String?;
    final cover = customCover != null && customCover.isNotEmpty
        ? customCover
        : (count > 0 ? (sheet['image_urls'] as List)[0] as String : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookReaderScreen(book: sheet),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: cover != null
                      ? Image.network(cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.description,
                              color: Color(0xFF00695C),
                              size: 32))
                      : const Icon(Icons.description,
                          color: Color(0xFF00695C), size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sheet['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 4),
                      Text('${sheet['grade'] ?? ''} • ${sheet['subject'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF555555))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00695C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('📄 $count ورقة',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF00695C),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 14, color: Color(0xFF00695C)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF00695C).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description_outlined,
                size: 60, color: Color(0xFF00695C)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد شيتات بعد',
              style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
          const SizedBox(height: 8),
          const Text('سيتم إضافة الشيتات قريباً',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ============ Manage Books Screen ============
class ManageBooksScreen extends StatefulWidget {
  const ManageBooksScreen({super.key});
  @override
  State<ManageBooksScreen> createState() => _ManageBooksScreenState();
}

class _ManageBooksScreenState extends State<ManageBooksScreen> {
  List<Map<String, dynamic>> _books = [];
  bool _loading = true;
  String _filter = 'all'; // all / book / sheets

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _loading = true);
    try {
      var query = supabase.from('books').select();
      if (_filter != 'all') {
        query = query.eq('category', _filter);
      }
      final data = await query.order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _books = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load books error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteBook(Map<String, dynamic> book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('تأكيد الحذف',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف كتاب "${book['title']}"؟\n\nسيتم حذف كل الصور نهائياً.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      // 1) نحذف الصور من Storage
      final imageUrls = book['image_urls'] as List? ?? [];
      for (var url in imageUrls) {
        try {
          final uri = Uri.parse(url.toString());
          final pathParts = uri.path.split('/');
          final fileName = pathParts.last;
          await supabase.storage.from('books').remove([fileName]);
        } catch (e) {
          debugPrint('Delete image error: $e');
        }
      }

      // 2) نحذف الكتاب من الجدول
      await supabase.from('books').delete().eq('id', book['id']);

      if (!mounted) return;
      Navigator.pop(context); // نقفل الـ loading
      showKitabiSnack(context, 'تم حذف الكتاب بنجاح');
      _loadBooks();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showKitabiSnack(context, 'فشل الحذف');
      debugPrint('Delete error: $e');
    }
  }

  Future<void> _replaceBook(Map<String, dynamic> book) async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(imageQuality: 85);
      if (images.isEmpty) return;
      if (!mounted) return;

      // نسأل: تبي غلاف جديد؟
      XFile? newCover;
      // نستخدم الحالي إن موجود
      final currentCover = book['cover_url'] as String?;

      // تأكيد
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.swap_horiz, color: Color(0xFF1565C0)),
              SizedBox(width: 10),
              Text('استبدال الصور',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'هل تريد استبدال صور "${book['title']}"؟\n\n'
            'الصور القديمة (${(book['image_urls'] as List?)?.length ?? 0} صورة) ستُحذف، '
            'وسيتم رفع ${images.length} صورة جديدة.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
              child: const Text('استبدال'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // مؤشر تحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      // 1) نحذف الصور القديمة
      final oldUrls = book['image_urls'] as List? ?? [];
      for (var url in oldUrls) {
        try {
          final uri = Uri.parse(url.toString());
          final fileName = uri.path.split('/').last;
          await supabase.storage.from('books').remove([fileName]);
        } catch (e) {
          debugPrint('Delete old image error: $e');
        }
      }

      // 2) نحذف الغلاف القديم إن كان مخصصاً
      if (currentCover != null && currentCover.isNotEmpty) {
        try {
          final uri = Uri.parse(currentCover);
          final fileName = uri.path.split('/').last;
          if (fileName.startsWith('cover_')) {
            await supabase.storage.from('books').remove([fileName]);
          }
        } catch (e) {
          debugPrint('Delete old cover error: $e');
        }
      }

      // 3) نرفع الصور الجديدة
      List<String> newUrls = [];
      int idx = 0;
      for (var img in images) {
        idx++;
        final bytes = await img.readAsBytes();
        final ext = img.path.split('.').last;
        final fileName =
            'book_${DateTime.now().millisecondsSinceEpoch}_${idx}.$ext';

        await supabase.storage.from('books').uploadBinary(fileName, bytes);
        final url =
            supabase.storage.from('books').getPublicUrl(fileName);
        newUrls.add(url);
      }

      // 4) نحدث الجدول
      await supabase.from('books').update({
        'image_urls': newUrls,
        'cover_url': newUrls.first,
        'read_count': 0,
      }).eq('id', book['id']);

      // نحذف قراءات الكتاب القديمة (لأنه كتاب جديد الآن)
      await supabase.from('book_reads').delete().eq('book_id', book['id']);

      if (!mounted) return;
      Navigator.pop(context);
      showKitabiSnack(context, 'تم استبدال الصور بنجاح');
      _loadBooks();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showKitabiSnack(context, 'فشل الاستبدال');
      debugPrint('Replace error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('إدارة الكتب',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // فلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _filterBtn('الكل', 'all'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _filterBtn('كتب', 'book'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _filterBtn('شيتات', 'sheets'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00897B)))
                : _books.isEmpty
                    ? const Center(child: Text('لا توجد كتب'))
                    : RefreshIndicator(
                        onRefresh: _loadBooks,
                        color: const Color(0xFF00897B),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _books.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _bookCard(_books[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _loadBooks();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00897B)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF555555),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            )),
      ),
    );
  }

  Widget _bookCard(Map<String, dynamic> book) {
    final count = (book['image_urls'] as List?)?.length ?? 0;
    final cover = count > 0
        ? (book['image_urls'] as List)[0] as String
        : null;
    final isSheets = book['category'] == 'sheets';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // الغلاف
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: (isSheets
                        ? const Color(0xFF00695C)
                        : const Color(0xFF1565C0))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: cover != null
                  ? Image.network(cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                          isSheets ? Icons.description : Icons.menu_book,
                          color: isSheets
                              ? const Color(0xFF00695C)
                              : const Color(0xFF1565C0),
                          size: 28))
                  : Icon(
                      isSheets ? Icons.description : Icons.menu_book,
                      color: isSheets
                          ? const Color(0xFF00695C)
                          : const Color(0xFF1565C0),
                      size: 28),
            ),
            const SizedBox(width: 12),
            // معلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book['title'] ?? '',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  Text('${book['grade']} • ${book['subject']}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF555555))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isSheets
                                  ? const Color(0xFF00695C)
                                  : const Color(0xFF1565C0))
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            isSheets ? 'شيتات' : 'كتاب',
                            style: TextStyle(
                                fontSize: 10,
                                color: isSheets
                                    ? const Color(0xFF00695C)
                                    : const Color(0xFF1565C0),
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      Text('$count صورة',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF888888))),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                            '📖 ${book['read_count'] ?? 0}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // أزرار
            Column(
              children: [
                IconButton(
                  onPressed: () => _replaceBook(book),
                  icon: const Icon(Icons.swap_horiz,
                      color: Color(0xFF1565C0), size: 22),
                  tooltip: 'استبدال',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () => _deleteBook(book),
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 22),
                  tooltip: 'حذف',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Teacher AI Screen ============
// ============ Videos Screen ============
class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});
  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;
  String _filterGrade = 'الكل';
  String _filterSubject = 'الكل';

  final List<String> _grades = [
    'الكل', 'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
    'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
    'أول إعدادي', 'ثاني إعدادي', 'ثالث إعدادي',
  ];

  final List<String> _subjects = [
    'الكل', 'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
    'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var query = supabase.from('videos').select();
      if (_filterGrade != 'الكل') {
        query = query.eq('grade', _filterGrade);
      }
      if (_filterSubject != 'الكل') {
        query = query.eq('subject', _filterSubject);
      }
      final data = await query.order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _videos = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load videos error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.play_circle_fill),
            SizedBox(width: 10),
            Text('فيديوهات تعلمية',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          // فلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('الصف:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterGrade,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        items: _grades
                            .map((g) => DropdownMenuItem(
                                value: g, child: Text(g, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _filterGrade = v ?? 'الكل');
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('المادة:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterSubject,
                        isExpanded: true,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          isDense: true,
                        ),
                        items: _subjects
                            .map((s) => DropdownMenuItem(
                                value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _filterSubject = v ?? 'الكل');
                          _load();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // قائمة الفيديوهات
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
                : _videos.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(0xFFD32F2F),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _videos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _videoCard(_videos[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _videoCard(Map<String, dynamic> video) {
    final isYouTube = video['video_type'] == 'youtube';
    final thumbnail = video['thumbnail_url'];
    final ytId = isYouTube ? _extractYouTubeId(video['video_url'] ?? '') : null;
    final autoThumb = ytId != null
        ? 'https://img.youtube.com/vi/$ytId/maxresdefault.jpg'
        : null;
    final coverUrl = (thumbnail != null && thumbnail.toString().isNotEmpty)
        ? thumbnail
        : autoThumb;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            // نزيد views_count
            try {
              final current = video['views_count'] ?? 0;
              await supabase
                  .from('videos')
                  .update({'views_count': (current as int) + 1})
                  .eq('id', video['id']);
            } catch (_) {}

            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(video: video),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الصورة المصغرة
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
                child: Stack(
                  children: [
                    Container(
                      height: 180,
                      color: Colors.black12,
                      child: coverUrl != null
                          ? Image.network(coverUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFFD32F2F)
                                        .withOpacity(0.1),
                                    child: const Icon(
                                        Icons.play_circle_outline,
                                        size: 60,
                                        color: Color(0xFFD32F2F)),
                                  ))
                          : Container(
                              color: const Color(0xFFD32F2F).withOpacity(0.1),
                              child: const Icon(Icons.play_circle_outline,
                                  size: 60, color: Color(0xFFD32F2F))),
                    ),
                    // زر التشغيل
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              size: 40, color: Color(0xFFD32F2F)),
                        ),
                      ),
                    ),
                    // نوع الفيديو
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isYouTube
                              ? Colors.red
                              : const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isYouTube ? 'YouTube' : 'mp4',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // التفاصيل
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 4),
                    Text(
                        '${video['grade'] ?? ''} • ${video['subject'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.visibility,
                            size: 14, color: Color(0xFF888888)),
                        const SizedBox(width: 4),
                        Text('${video['views_count'] ?? 0} مشاهدة',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF888888))),
                      ],
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

  String? _extractYouTubeId(String url) {
    if (url.isEmpty) return null;
    try {
      if (url.contains('youtu.be/')) {
        return url.split('youtu.be/').last.split('?').first;
      }
      if (url.contains('youtube.com/watch')) {
        final uri = Uri.parse(url);
        return uri.queryParameters['v'];
      }
      if (url.contains('youtube.com/embed/')) {
        return url.split('youtube.com/embed/').last.split('?').first;
      }
    } catch (_) {}
    return null;
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_circle_outline,
                size: 60, color: Color(0xFFD32F2F)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد فيديوهات بعد',
              style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
        ],
      ),
    );
  }
}

// ============ Video Player Screen ============
class VideoPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> video;
  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  WebViewController? _webCtrl;
  bool _initializing = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final type = widget.video['video_type'] ?? 'youtube';
    final url = widget.video['video_url'] ?? '';

    if (url.isEmpty) {
      setState(() {
        _error = 'رابط الفيديو مفقود';
        _initializing = false;
      });
      return;
    }

    try {
      if (type == 'youtube') {
        final ytId = _extractId(url);
        if (ytId == null) {
          setState(() {
            _error = 'رابط يوتيوب غير صحيح';
            _initializing = false;
          });
          return;
        }
        final embedUrl =
            'https://www.youtube.com/embed/$ytId?autoplay=1&rel=0';
        _webCtrl = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.black)
          ..loadRequest(Uri.parse(embedUrl));
        setState(() => _initializing = false);
      } else {
        // mp4
        _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
        await _videoCtrl!.initialize();
        _chewieCtrl = ChewieController(
          videoPlayerController: _videoCtrl!,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoCtrl!.value.aspectRatio,
          errorBuilder: (context, msg) => Center(
            child: Text('خطأ: $msg',
                style: const TextStyle(color: Colors.white)),
          ),
        );
        setState(() => _initializing = false);
      }
    } catch (e) {
      setState(() {
        _error = 'فشل تحميل الفيديو';
        _initializing = false;
      });
      debugPrint('Video error: $e');
    }
  }

  String? _extractId(String url) {
    try {
      if (url.contains('youtu.be/')) {
        return url.split('youtu.be/').last.split('?').first;
      }
      if (url.contains('youtube.com/watch')) {
        return Uri.parse(url).queryParameters['v'];
      }
      if (url.contains('youtube.com/embed/')) {
        return url.split('youtube.com/embed/').last.split('?').first;
      }
      // إذا كان المعرف فقط
      if (!url.contains('/') && url.length >= 10) return url;
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    _chewieCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.video['title'] ?? 'فيديو',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: Column(
        children: [
          // منطقة الفيديو
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _initializing
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.white, size: 50),
                            const SizedBox(height: 10),
                            Text(_error,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 14)),
                          ],
                        ),
                      )
                    : widget.video['video_type'] == 'youtube'
                        ? WebViewWidget(controller: _webCtrl!)
                        : Chewie(controller: _chewieCtrl!),
          ),
          // معلومات
          Expanded(
            child: Container(
              color: const Color(0xFF1A1A1A),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video['title'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.video['grade'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.video['subject'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    if (widget.video['description'] != null &&
                        widget.video['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 15),
                      Text(
                        widget.video['description'],
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherAIScreen extends StatefulWidget {
  const TeacherAIScreen({super.key});
  @override
  State<TeacherAIScreen> createState() => _TeacherAIScreenState();
}

class _TeacherAIScreenState extends State<TeacherAIScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<XFile> _pickedImages = [];
  bool _sending = false;
  bool _loading = true;
  String _userName = '';
  String _userGrade = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name') ?? 'طالب';
    _userGrade = prefs.getString('user_grade') ?? '';
    await _loadHistory();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadHistory() async {
    try {
      final data = await supabase
          .from('chats')
          .select()
          .eq('user_name', _userName)
          .order('created_at', ascending: true)
          .limit(100);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        for (var m in data) {
          _messages.add(Map<String, dynamic>.from(m));
        }
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Load chats error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    if (_pickedImages.length >= 3) {
      showKitabiSnack(context, 'الحد الأقصى 3 صور');
      return;
    }
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
      if (img != null) {
        setState(() => _pickedImages.add(img));
      }
    } catch (e) {
      showKitabiSnack(context, 'فشل اختيار الصورة');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty && _pickedImages.isEmpty) return;
    if (_sending) return;

    setState(() => _sending = true);

    final userMsg = {
      'user_name': _userName,
      'role': 'user',
      'content': text.isEmpty ? '(صورة)' : text,
    };
    setState(() {
      _messages.add(userMsg);
      _messageCtrl.clear();
      _pickedImages.clear();
    });
    _scrollToBottom();

    try {
      await supabase.from('chats').insert({
        'user_name': _userName,
        'role': 'user',
        'content': text.isEmpty ? '(صورة)' : text,
        'image_urls': [],
      });
    } catch (e) {
      debugPrint('Save user msg error: $e');
    }

    final aiResponse = await _callGemini(text);

    final aiMsg = {
      'user_name': _userName,
      'role': 'assistant',
      'content': aiResponse,
    };
    setState(() {
      _messages.add(aiMsg);
      _sending = false;
    });
    _scrollToBottom();

    try {
      await supabase.from('chats').insert({
        'user_name': _userName,
        'role': 'assistant',
        'content': aiResponse,
        'image_urls': [],
      });
    } catch (e) {
      debugPrint('Save ai msg error: $e');
    }
  }

  Future<String> _getGeminiKey() async {
    try {
      final data = await supabase
          .from('admin_settings')
          .select('gemini_api_key')
          .eq('id', 1)
          .single();
      return data['gemini_api_key'] ?? '';
    } catch (e) {
      debugPrint('Get Gemini key error: $e');
      return '';
    }
  }

  Future<String> _callGemini(String question) async {
    if (question.isEmpty) {
      return 'أرسل سؤالك وسأجيبك بإذن الله.';
    }
    try {
      final apiKey = await _getGeminiKey();
      const model = 'gemini-3.7-flash';

      final sys = 'أنت معلم ذكي اسمك معلم كتابي، تعمل في تطبيق كتابي التعليمي الليبي. '
          'الطالب اسمه: ' + _userName + '. صفه: ' + _userGrade + '. '
          'رد بالعربية الفصحى مع لمسة ليبية بسيطة. اشرح بلطف ووضوح.';

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/interactions'),
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'input': sys + '\n\nسؤال الطالب: ' + question,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['steps'] != null && data['steps'] is List) {
          for (var step in data['steps']) {
            if (step['type'] == 'model_output' && step['content'] is List) {
              for (var c in step['content']) {
                if (c['type'] == 'text') {
                  return c['text'] ?? '';
                }
              }
            }
          }
        }
        if (data['output_text'] != null) {
          return data['output_text'].toString();
        }
        return 'لم أفهم الرد. جرب مرة أخرى.';
      } else if (response.statusCode == 503) {
        return 'الخادم مشغول حالياً، جرب بعد قليل.';
      } else if (response.statusCode == 429) {
        return 'الخدمة مزدحمة، جرب بعد دقيقة.';
      } else {
        return 'حدث خطأ. جرب لاحقاً.';
      }
    } catch (e) {
      debugPrint('Gemini error: $e');
      return 'تعذر الاتصال. تحقق من الإنترنت.';
    }
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('مسح المحادثة'),
        content: const Text('هل تريد مسح كل المحادثة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await supabase.from('chats').delete().eq('user_name', _userName);
      if (!mounted) return;
      setState(() => _messages.clear());
      showKitabiSnack(context, 'تم مسح المحادثة');
    } catch (e) {
      showKitabiSnack(context, 'فشل المسح');
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white,
              child: Icon(Icons.smart_toy, color: Color(0xFF7B1FA2), size: 22),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('معلم كتابي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('AI مساعد', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? _buildWelcome()
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _ChatBubble(msg: _messages[i]),
                        ),
                ),
                if (_sending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    alignment: Alignment.centerRight,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF7B1FA2)),
                        ),
                        SizedBox(width: 8),
                        Text('يكتب...',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF7B1FA2),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)]),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B1FA2).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, size: 70, color: Colors.white),
            ),
            const SizedBox(height: 25),
            const Text('مرحباً بك في معلم كتابي',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 10),
            const Text(
              'اسألني أي سؤال دراسي وسأساعدك\nمن المنهج الليبي بإذن الله',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pickedImages.isNotEmpty)
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pickedImages.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_pickedImages[i].path),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: () => setState(() => _pickedImages.removeAt(i)),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image_outlined, color: Color(0xFF7B1FA2)),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'اكتب سؤالك...',
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF7B1FA2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sending ? null : _sendMessage,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Chat Bubble ============
class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF7B1FA2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
          if (!isUser) const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1565C0) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: SelectableText(
                msg['content'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isUser ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 6),
          if (isUser)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
        ],
      ),
    );
  }
}

// ============ Manage Videos Screen ============
class ManageVideosScreen extends StatefulWidget {
  const ManageVideosScreen({super.key});
  @override
  State<ManageVideosScreen> createState() => _ManageVideosScreenState();
}

class _ManageVideosScreenState extends State<ManageVideosScreen> {
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('videos')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _videos = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load videos error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteVideo(Map<String, dynamic> video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('تأكيد الحذف',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل تريد حذف الفيديو "${video['title']}"؟',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // نحذف الملف إذا كان mp4
      if (video['video_type'] == 'mp4' && video['video_url'] != null) {
        try {
          final url = video['video_url'].toString();
          final fileName = url.split('/').last;
          await supabase.storage.from('books').remove([fileName]);
        } catch (_) {}
      }
      await supabase.from('videos').delete().eq('id', video['id']);
      if (!mounted) return;
      showKitabiSnack(context, 'تم حذف الفيديو');
      _load();
    } catch (e) {
      if (!mounted) return;
      showKitabiSnack(context, 'فشل الحذف');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('إدارة الفيديوهات',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => _showAddVideo(),
            icon: const Icon(Icons.add_circle, size: 28),
            tooltip: 'إضافة فيديو',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : _videos.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFD32F2F),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _videos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _videoCard(_videos[i]),
                  ),
                ),
    );
  }

  Widget _videoCard(Map<String, dynamic> video) {
    final isYT = video['video_type'] == 'youtube';
    final ytId = isYT ? _extractYT(video['video_url'] ?? '') : null;
    final thumb = ytId != null
        ? 'https://img.youtube.com/vi/$ytId/default.jpg'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // صورة مصغرة
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: thumb != null
                  ? Image.network(thumb, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.play_circle_outline,
                          color: Color(0xFFD32F2F)))
                  : const Icon(Icons.play_circle_outline,
                      color: Color(0xFFD32F2F)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video['title'] ?? '',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${video['grade']} • ${video['subject']}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF555555)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isYT ? Colors.red : const Color(0xFF1565C0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(isYT ? 'YT' : 'mp4',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      Text('👁 ${video['views_count'] ?? 0}',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF888888))),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _deleteVideo(video),
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractYT(String url) {
    try {
      if (url.contains('youtu.be/')) {
        return url.split('youtu.be/').last.split('?').first;
      }
      if (url.contains('youtube.com/watch')) {
        return Uri.parse(url).queryParameters['v'];
      }
      if (url.contains('youtube.com/embed/')) {
        return url.split('youtube.com/embed/').last.split('?').first;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _showAddVideo() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String videoType = 'youtube';
    String selectedGrade = 'أول ابتدائي';
    String selectedSubject = 'الرياضيات';
    bool uploading = false;

    final List<String> grades = [
      'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
      'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
      'أول إعدادي', 'ثاني إعدادي', 'ثالث إعدادي',
      'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي',
    ];

    final List<String> subjects = [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.video_call, color: Color(0xFFD32F2F)),
              SizedBox(width: 10),
              Text('إضافة فيديو',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'عنوان الفيديو',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGrade,
                    decoration: InputDecoration(
                      labelText: 'الصف',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: grades
                        .map((g) =>
                            DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: uploading
                        ? null
                        : (v) => setSt(
                            () => selectedGrade = v ?? selectedGrade),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: InputDecoration(
                      labelText: 'المادة',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: subjects
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: uploading
                        ? null
                        : (v) => setSt(
                            () => selectedSubject = v ?? selectedSubject),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('النوع:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('YouTube',
                                style: TextStyle(fontSize: 12)),
                            value: 'youtube',
                            groupValue: videoType,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: uploading
                                ? null
                                : (v) =>
                                    setSt(() => videoType = v ?? 'youtube'),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('mp4',
                                style: TextStyle(fontSize: 12)),
                            value: 'mp4',
                            groupValue: videoType,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: uploading
                                ? null
                                : (v) => setSt(() => videoType = v ?? 'mp4'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (videoType == 'youtube')
                    TextField(
                      controller: urlCtrl,
                      decoration: InputDecoration(
                        labelText: 'رابط يوتيوب',
                        hintText: 'https://youtube.com/watch?v=...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                try {
                                  final picker = ImagePicker();
                                  // نستخدم file_picker بدلاً منه لكن هنا نستخدم pickVideo
                                  final video = await picker.pickVideo(
                                      source: ImageSource.gallery);
                                  if (video != null) {
                                    setSt(() {
                                      urlCtrl.text = video.path;
                                    });
                                  }
                                } catch (e) {
                                  showKitabiSnack(context, 'فشل اختيار الفيديو');
                                }
                              },
                        icon: const Icon(Icons.video_file),
                        label: Text(urlCtrl.text.isEmpty
                            ? 'اختر فيديو من الجهاز'
                            : 'تم اختيار الفيديو'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: uploading
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        showKitabiSnack(context, 'اكتب عنوان الفيديو');
                        return;
                      }
                      if (urlCtrl.text.trim().isEmpty) {
                        showKitabiSnack(context,
                            videoType == 'youtube'
                                ? 'الصق رابط يوتيوب'
                                : 'اختر فيديو من الجهاز');
                        return;
                      }

                      setSt(() => uploading = true);

                      try {
                        String finalUrl = urlCtrl.text.trim();

                        // إذا كان mp4، نرفعه إلى Storage
                        if (videoType == 'mp4') {
                          final videoFile = XFile(finalUrl);
                          final bytes = await videoFile.readAsBytes();
                          final ext = finalUrl.split('.').last;
                          final fileName =
                              'video_${DateTime.now().millisecondsSinceEpoch}.$ext';

                          await supabase.storage
                              .from('books')
                              .uploadBinary(fileName, bytes);

                          finalUrl = supabase.storage
                              .from('books')
                              .getPublicUrl(fileName);
                        }

                        await supabase.from('videos').insert({
                          'title': titleCtrl.text.trim(),
                          'description': descCtrl.text.trim(),
                          'grade': selectedGrade,
                          'subject': selectedSubject,
                          'video_type': videoType,
                          'video_url': finalUrl,
                          'uploaded_by': 'admin',
                        });

                        if (!context.mounted) return;
                        Navigator.pop(dialogCtx);
                        showKitabiSnack(context, 'تم إضافة الفيديو');
                        _load();
                      } catch (e) {
                        setSt(() => uploading = false);
                        showKitabiSnack(context, 'فشل: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              child: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.video_library_outlined,
                size: 60, color: Color(0xFFD32F2F)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد فيديوهات بعد',
              style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _showAddVideo,
            icon: const Icon(Icons.add),
            label: const Text('إضافة فيديو'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class ControlRoomScreen extends StatefulWidget {
  const ControlRoomScreen({super.key});
  @override
  State<ControlRoomScreen> createState() => _ControlRoomScreenState();
}

class _ControlRoomScreenState extends State<ControlRoomScreen> {
  final _idController = TextEditingController();
  final _passController = TextEditingController();
  bool _logged = false;
  bool _showLoginPassword = false;

  Future<void> _login() async {
    String storedPassword = 'العلم نور';
    try {
      final data = await supabase
          .from('admin_settings')
          .select('admin_password')
          .eq('id', 1)
          .single();
      storedPassword = data['admin_password'] ?? 'العلم نور';
    } catch (e) {
      debugPrint('Load password error: $e');
    }

    if (_idController.text.trim() == '0922251374' &&
        _passController.text.trim() == storedPassword) {
      setState(() => _logged = true);
    } else {
      showKitabiSnack(context, 'بيانات خاطئة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('غرفة التحكم',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _logged ? _panel() : _loginUi(),
    );
  }

  Widget _loginUi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.admin_panel_settings,
                size: 70, color: Colors.white),
          ),
          const SizedBox(height: 25),
          const Text('الدخول للمشرفين',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          const Text('هذه الصفحة مخصصة للمشرف فقط',
              style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
          const SizedBox(height: 30),
          TextField(
            controller: _idController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'الرقم',
              prefixIcon: const Icon(Icons.phone),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _passController,
            obscureText: !_showLoginPassword,
            decoration: InputDecoration(
              labelText: 'كلمة السر',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                onPressed: () => setState(
                    () => _showLoginPassword = !_showLoginPassword),
                icon: Icon(
                  _showLoginPassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: const Color(0xFF555555),
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('دخول',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 30),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مرحباً بك في غرفة التحكم',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1A1A1A))),
                    SizedBox(height: 2),
                    Text('v0.1 — الإصدار التجريبي',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF555555))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _bigCard('المستخدمون', 'عرض',
                  Icons.people_alt_rounded, const Color(0xFF1565C0),
                  () => _showUsersManagement()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard('رفع الكتب', 'جديد',
                  Icons.upload_file_rounded, const Color(0xFF00897B),
                  () => _showUploadBook()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bigCard('إرسال إشعار', 'لكل الطلاب',
                  Icons.send_rounded, const Color(0xFF7B1FA2),
                  () => _showSendNotification()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard('كلمة السر', 'تغيير',
                  Icons.key_rounded, const Color(0xFFEF6C00),
                  () => _changePassword()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bigCard('الاختبارات', 'إدارة',
                  Icons.assignment_rounded, const Color(0xFFD32F2F),
                  () => _showQuizzes()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard('الإحصائيات', 'تحليل',
                  Icons.bar_chart_rounded, const Color(0xFF283593),
                  () => _showStatistics()),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 12),
            ],
          ),
          child: Column(
            children: [
              _listItem(Icons.group_add_rounded, 'إدارة المستخدمين',
                  const Color(0xFF1565C0), _showUsersManagement),
              _divider(),
              _listItem(Icons.campaign_rounded, 'إشعار جماعي',
                  const Color(0xFF7B1FA2), _showSendNotification),
              _divider(),
              _listItem(Icons.lock_reset_rounded, 'تغيير كلمة السر',
                  const Color(0xFFEF6C00), _changePassword),
              _divider(),
              _listItem(Icons.library_books_rounded, 'إدارة الكتب',
                  const Color(0xFF00897B), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageBooksScreen()),
                );
              }),
              _divider(),
              _listItem(Icons.video_library_rounded, 'إدارة الفيديوهات',
                  const Color(0xFFD32F2F), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageVideosScreen()),
                );
              }),
              _divider(),
              _listItem(Icons.settings_rounded, 'إعدادات متقدمة',
                  const Color(0xFF283593), () {
                showKitabiSnack(context, 'الإعدادات — قريباً');
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bigCard(String title, String subtitle, IconData icon, Color color,
      VoidCallback onTap) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const Spacer(),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _listItem(
      IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1A1A1A))),
      trailing: const Icon(Icons.arrow_back_ios,
          size: 14, color: Color(0xFF555555)),
      onTap: onTap,
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 70, endIndent: 15, color: Color(0xFFF0F0F0));

  // ============ إدارة المستخدمين ============
  Future<void> _showUsersManagement() async {
    List<Map<String, dynamic>> usersList = [];
    bool loading = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          if (loading) {
            supabase
                .from('users')
                .select()
                .order('created_at', ascending: false)
                .then((data) {
              setSt(() {
                usersList = List<Map<String, dynamic>>.from(data);
                loading = false;
              });
            }).catchError((e) {
              setSt(() => loading = false);
            });
          }
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.manage_accounts,
                        color: Color(0xFF1565C0), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'إدارة المستخدمين (${usersList.length})',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setSt(() => loading = true),
                      icon: const Icon(Icons.refresh,
                          color: Color(0xFF1565C0)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF1565C0)))
                      : usersList.isEmpty
                          ? const Center(
                              child: Text('لا يوجد مستخدمون',
                                  style: TextStyle(
                                      color: Color(0xFF555555))))
                          : ListView.separated(
                              itemCount: usersList.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final u = usersList[i];
                                final banned = u['is_banned'] == true;
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: banned
                                        ? Colors.red.shade50
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: banned
                                          ? Colors.red.shade200
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: banned
                                            ? Colors.red
                                            : const Color(0xFF1565C0),
                                        child: Text(
                                          (u['name'] ?? '?')
                                              .toString()
                                              .substring(0, 1),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(u['name'] ?? '',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: Color(0xFF1A1A1A))),
                                            Text(
                                                '${u['grade'] ?? ''} - ${u['muraqaba'] ?? ''}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF555555))),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          try {
                                            await supabase
                                                .from('users')
                                                .update({
                                              'is_banned': !banned,
                                              'ban_reason': !banned
                                                  ? 'مخالفة سياسة التطبيق'
                                                  : null,
                                            }).eq('id', u['id']);
                                            setSt(() {
                                              usersList[i]['is_banned'] =
                                                  !banned;
                                            });
                                            if (!context.mounted) return;
                                            showKitabiSnack(
                                                context,
                                                !banned
                                                    ? 'تم حظر المستخدم'
                                                    : 'تم إلغاء الحظر');
                                          } catch (e) {
                                            showKitabiSnack(
                                                context, 'فشل التحديث');
                                          }
                                        },
                                        icon: Icon(
                                          banned
                                              ? Icons.lock_open
                                              : Icons.block,
                                          color: banned
                                              ? Colors.green
                                              : Colors.red,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============ الإحصائيات ============
  Future<void> _showStatistics() async {
    int usersCount = 0;
    int booksCount = 0;
    int notifsCount = 0;
    int videosCount = 0;
    int quizzesCount = 0;
    int bannedCount = 0;

    try {
      final users = await supabase.from('users').select('is_banned');
      usersCount = users.length;
      bannedCount = users.where((u) => u['is_banned'] == true).length;

      final books = await supabase.from('books').select('id');
      booksCount = books.length;

      final notifs = await supabase.from('notifications').select('id');
      notifsCount = notifs.length;

      final videos = await supabase.from('videos').select('id');
      videosCount = videos.length;

      final quizzes = await supabase.from('quizzes').select('id');
      quizzesCount = quizzes.length;
    } catch (e) {
      debugPrint('Stats error: $e');
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 15),
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Color(0xFF283593), size: 24),
                SizedBox(width: 10),
                Text('الإحصائيات',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _statBox('المستخدمون', '$usersCount',
                    Icons.people, const Color(0xFF1565C0)),
                const SizedBox(width: 10),
                _statBox('الكتب', '$booksCount',
                    Icons.menu_book, const Color(0xFF00897B)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statBox('الإشعارات', '$notifsCount',
                    Icons.notifications, const Color(0xFF7B1FA2)),
                const SizedBox(width: 10),
                _statBox('الفيديوهات', '$videosCount',
                    Icons.play_circle, const Color(0xFFD32F2F)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statBox('الاختبارات', '$quizzesCount',
                    Icons.assignment, const Color(0xFFEF6C00)),
                const SizedBox(width: 10),
                _statBox('المحظورون', '$bannedCount',
                    Icons.block, const Color(0xFFD32F2F)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF555555))),
          ],
        ),
      ),
    );
  }


  // ============ إرسال إشعار ============
  Future<void> _showSendNotification() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String selectedTarget = 'الجميع';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.campaign, color: Color(0xFF7B1FA2)),
              SizedBox(width: 10),
              Text('إرسال إشعار',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'نص الإشعار',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedTarget,
                  decoration: InputDecoration(
                    labelText: 'المرسل إليه',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'الجميع', child: Text('الجميع')),
                    DropdownMenuItem(
                        value: 'صف دراسي', child: Text('صف دراسي')),
                    DropdownMenuItem(value: 'مراقبة', child: Text('مراقبة')),
                  ],
                  onChanged: (v) =>
                      setSt(() => selectedTarget = v ?? 'الجميع'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) {
                  showKitabiSnack(context, 'اكتب عنوان الإشعار');
                  return;
                }
                if (bodyCtrl.text.trim().isEmpty) {
                  showKitabiSnack(context, 'اكتب نص الإشعار');
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  await supabase.from('notifications').insert({
                    'title': titleCtrl.text.trim(),
                    'body': bodyCtrl.text.trim(),
                    'target_type': selectedTarget,
                    'sent_by': 'admin',
                  });
                  if (!context.mounted) return;
                  showKitabiSnack(context, 'تم إرسال الإشعار بنجاح');
                } catch (e) {
                  if (!context.mounted) return;
                  showKitabiSnack(context, 'فشل الإرسال');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                foregroundColor: Colors.white,
              ),
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  // ============ تغيير كلمة السر ============
  Future<void> _changePassword() async {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool showOld = false;
    bool showNew = false;

    String currentPassword = 'العلم نور';
    try {
      final data = await supabase
          .from('admin_settings')
          .select('admin_password')
          .eq('id', 1)
          .single();
      currentPassword = data['admin_password'] ?? 'العلم نور';
    } catch (e) {
      debugPrint('Load password error: $e');
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.key, color: Color(0xFFEF6C00)),
              SizedBox(width: 10),
              Text('تغيير كلمة السر',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPassCtrl,
                obscureText: !showOld,
                decoration: InputDecoration(
                  labelText: 'كلمة السر الحالية',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () => setSt(() => showOld = !showOld),
                    icon: Icon(
                      showOld ? Icons.visibility : Icons.visibility_off,
                      color: const Color(0xFF555555),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassCtrl,
                obscureText: !showNew,
                decoration: InputDecoration(
                  labelText: 'كلمة السر الجديدة',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    onPressed: () => setSt(() => showNew = !showNew),
                    icon: Icon(
                      showNew ? Icons.visibility : Icons.visibility_off,
                      color: const Color(0xFF555555),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (oldPassCtrl.text.trim() != currentPassword) {
                  showKitabiSnack(context, 'كلمة السر الحالية خاطئة');
                  return;
                }
                if (newPassCtrl.text.trim().length < 4) {
                  showKitabiSnack(context, 'كلمة السر قصيرة');
                  return;
                }
                Navigator.pop(dialogCtx);
                try {
                  await supabase.from('admin_settings').update({
                    'admin_password': newPassCtrl.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', 1);
                  if (!context.mounted) return;
                  showKitabiSnack(context, 'تم تغيير كلمة السر بنجاح');
                } catch (e) {
                  if (!context.mounted) return;
                  showKitabiSnack(context, 'فشل تغيير كلمة السر');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF6C00),
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ============ الاختبارات ============
  Future<void> _showQuizzes() async {
    List<Map<String, dynamic>> quizzes = [];
    bool loading = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          if (loading) {
            supabase
                .from('quizzes')
                .select()
                .order('created_at', ascending: false)
                .then((data) {
              setSt(() {
                quizzes = List<Map<String, dynamic>>.from(data);
                loading = false;
              });
            }).catchError((e) {
              setSt(() => loading = false);
            });
          }
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.assignment,
                        color: Color(0xFFD32F2F), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('الاختبارات (${quizzes.length})',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A))),
                    ),
                    IconButton(
                      onPressed: () => _addQuiz(setSt),
                      icon: const Icon(Icons.add_circle,
                          color: Color(0xFF2E7D32), size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFD32F2F)))
                      : quizzes.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_outlined,
                                      size: 60, color: Color(0xFF555555)),
                                  SizedBox(height: 12),
                                  Text('لا توجد اختبارات بعد',
                                      style: TextStyle(
                                          color: Color(0xFF555555))),
                                  SizedBox(height: 6),
                                  Text('اضغط + لإضافة أول اختبار',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888))),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: quizzes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final q = quizzes[i];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD32F2F)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.quiz,
                                            color: Color(0xFFD32F2F),
                                            size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(q['title'] ?? '',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14)),
                                            Text(
                                                '${q['grade'] ?? ''} • ${q['subject'] ?? ''}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF555555))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addQuiz(StateSetter setSt) async {
    final titleCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: Color(0xFF2E7D32)),
            SizedBox(width: 10),
            Text('اختبار جديد',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'عنوان الاختبار',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              decoration: InputDecoration(
                labelText: 'المادة',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gradeCtrl,
              decoration: InputDecoration(
                labelText: 'الصف',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) {
                showKitabiSnack(context, 'اكتب عنوان الاختبار');
                return;
              }
              Navigator.pop(dialogCtx);
              try {
                await supabase.from('quizzes').insert({
                  'title': titleCtrl.text.trim(),
                  'subject': subjectCtrl.text.trim(),
                  'grade': gradeCtrl.text.trim(),
                  'questions': [],
                });
                if (!context.mounted) return;
                showKitabiSnack(context, 'تم إضافة الاختبار');
                setSt(() {});
              } catch (e) {
                if (!context.mounted) return;
                showKitabiSnack(context, 'فشل الإضافة');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  // ============ رفع الكتب ============
  Future<void> _showUploadBook() async {
    final titleCtrl = TextEditingController();
    String selectedGrade = 'أول ابتدائي';
    String selectedSubject = 'الرياضيات';
    String selectedCategory = 'book';
    List<XFile> pickedImages = [];
    XFile? coverImage;
    bool uploading = false;
    double progress = 0;

    final List<String> grades = [
      'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
      'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
      'أول إعدادي', 'ثاني إعدادي',
    ];

    final List<String> subjects = [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Color(0xFF00897B)),
              SizedBox(width: 10),
              Text('رفع كتاب جديد',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'عنوان الكتاب',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGrade,
                    decoration: InputDecoration(
                      labelText: 'الصف',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: grades
                        .map((g) =>
                            DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: uploading
                        ? null
                        : (v) =>
                            setSt(() => selectedGrade = v ?? selectedGrade),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSubject,
                    decoration: InputDecoration(
                      labelText: 'المادة',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: subjects
                        .map((s) =>
                            DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: uploading
                        ? null
                        : (v) => setSt(
                            () => selectedSubject = v ?? selectedSubject),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Text('النوع:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('كتاب',
                                style: TextStyle(fontSize: 13)),
                            value: 'book',
                            groupValue: selectedCategory,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: uploading
                                ? null
                                : (v) => setSt(
                                    () => selectedCategory = v ?? 'book'),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('شيتات',
                                style: TextStyle(fontSize: 13)),
                            value: 'sheets',
                            groupValue: selectedCategory,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: uploading
                                ? null
                                : (v) => setSt(
                                    () => selectedCategory = v ?? 'sheets'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (true) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton.icon(
                        onPressed: uploading
                            ? null
                            : () async {
                                try {
                                  final picker = ImagePicker();
                                  final images = await picker
                                      .pickMultiImage(imageQuality: 85);
                                  if (images.isNotEmpty) {
                                    setSt(() {
                                      pickedImages = images;
                                    });
                                  }
                                } catch (e) {
                                  showKitabiSnack(
                                      context, 'فشل اختيار الصور');
                                }
                              },
                        icon: const Icon(Icons.photo_library),
                        label: Text(
                            'اختيار صور (${pickedImages.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (pickedImages.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(6),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                          itemCount: pickedImages.length,
                          itemBuilder: (_, i) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  File(pickedImages[i].path),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: uploading
                                      ? null
                                      : () => setSt(
                                          () => pickedImages.removeAt(i)),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // === زر اختيار الغلاف ===
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 65,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: coverImage != null
                                  ? Image.file(
                                      File(coverImage!.path),
                                      fit: BoxFit.cover)
                                  : const Icon(Icons.image_outlined,
                                      color: Colors.grey, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('الغلاف (اختياري)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  const SizedBox(height: 3),
                                  Text(
                                    coverImage == null
                                        ? 'بدون غلاف: سيُستخدم أول صورة'
                                        : 'تم اختيار الغلاف',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF555555)),
                                  ),
                                ],
                              ),
                            ),
                            if (coverImage == null)
                              IconButton(
                                onPressed: uploading
                                    ? null
                                    : () async {
                                        final picker = ImagePicker();
                                        final img =
                                            await picker.pickImage(
                                                source:
                                                    ImageSource.gallery,
                                                imageQuality: 85);
                                        if (img != null) {
                                          setSt(
                                              () => coverImage = img);
                                        }
                                      },
                                icon: const Icon(
                                    Icons.add_photo_alternate,
                                    color: Colors.amber, size: 28),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            else
                              IconButton(
                                onPressed: uploading
                                    ? null
                                    : () => setSt(
                                        () => coverImage = null),
                                icon: const Icon(Icons.close,
                                    color: Colors.red, size: 22),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (uploading) ...[
                    const SizedBox(height: 15),
                    LinearProgressIndicator(
                        value: progress,
                        color: const Color(0xFF1565C0)),
                    const SizedBox(height: 8),
                    Text(
                      'جاري الرفع ${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: uploading
                  ? null
                  : () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        showKitabiSnack(context, 'اكتب عنوان الكتاب');
                        return;
                      }
                      if (pickedImages.isEmpty) {
                        showKitabiSnack(
                            context, 'اختر صور الكتاب أولاً');
                        return;
                      }

                      setSt(() => uploading = true);
                      List<String> uploadedUrls = [];

                      try {
                        // 1) نرفع الغلاف إن وُجد
                        String? coverUrl;
                        if (coverImage != null) {
                          final coverBytes =
                              await coverImage!.readAsBytes();
                          final coverExt =
                              coverImage!.path.split('.').last;
                          final coverName =
                              'cover_${DateTime.now().millisecondsSinceEpoch}.$coverExt';
                          await supabase.storage
                              .from('books')
                              .uploadBinary(coverName, coverBytes);
                          coverUrl = supabase.storage
                              .from('books')
                              .getPublicUrl(coverName);
                        }

                        // 2) نرفع صور المحتوى
                        int idx = 0;
                        for (var img in pickedImages) {
                          idx++;
                          setSt(() => progress = idx / pickedImages.length);

                          final bytes = await img.readAsBytes();
                          final ext = img.path.split('.').last;
                          final fileName =
                              'book_${DateTime.now().millisecondsSinceEpoch}_${idx}.$ext';

                          await supabase.storage
                              .from('books')
                              .uploadBinary(fileName, bytes);

                          final url = supabase.storage
                              .from('books')
                              .getPublicUrl(fileName);
                          uploadedUrls.add(url);
                        }

                        // 3) نحفظ في الجدول
                        await supabase.from('books').insert({
                          'title': titleCtrl.text.trim(),
                          'grade': selectedGrade,
                          'subject': selectedSubject,
                          'book_type': 'images',
                          'category': selectedCategory,
                          'image_urls': uploadedUrls,
                          'cover_url':
                              coverUrl ?? uploadedUrls.first,
                          'uploaded_by': 'admin',
                        });

                        if (!context.mounted) return;
                        Navigator.pop(dialogCtx);
                        showKitabiSnack(
                            context, 'تم رفع الكتاب بنجاح');
                      } catch (e) {
                        setSt(() => uploading = false);
                        showKitabiSnack(context, 'فشل الرفع: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
              child: const Text('رفع'),
            ),
          ],
        ),
      ),
    );
  }


}
