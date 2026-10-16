// ============================================
// Kitabi v1.0 — تطبيق تعليمي للطلاب الليبيين
// ============================================

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

// ============ إعدادات Supabase ============
const String kSupabaseUrl = 'https://vlyfghfoelbbbdljbvcr.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_d4ZrC9cHXb8YvzyvlRkeCA_GOMtyzgt';

// وصول سريع
final supabase = Supabase.instance.client;

// ValueNotifier للوضع الليلي (يُحدّث التطبيق فورياً)
final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

// ValueNotifier لحجم الخط (يُحدّث التطبيق فورياً)
final ValueNotifier<double> fontScaleNotifier = ValueNotifier<double>(1.0);

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

  // تهيئة الإشعارات المحلية
  await NotificationService().init();

  await Supabase.initialize(
    url: kSupabaseUrl,
    anonKey: kSupabaseAnonKey,
  );

  // نقرأ الوضع الليلي المحفوظ
  try {
    final prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Load dark mode error: $e');
  }

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
// ============ Subscription Helper ============
class RoleHelper {
  static String roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'moderator':
        return 'مشرف';
      case 'teacher':
        return 'معلم';
      default:
        return 'طالب';
    }
  }

  static Color roleColor(String? role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFD32F2F);
      case 'moderator':
        return const Color(0xFF7B1FA2);
      case 'teacher':
        return const Color(0xFF00897B);
      default:
        return const Color(0xFF1565C0);
    }
  }

  static IconData roleIcon(String? role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'moderator':
        return Icons.shield;
      case 'teacher':
        return Icons.school;
      default:
        return Icons.person;
    }
  }
}

class SubscriptionHelper {
  static Future<bool> isPlusUser(String userName) async {
    try {
      final now = DateTime.now().toIso8601String();
      final data = await supabase
          .from('subscriptions')
          .select('id')
          .eq('user_name', userName)
          .eq('is_active', true)
          .gte('expires_at', now)
          .limit(1);
      return data.isNotEmpty;
    } catch (e) {
      debugPrint('Check plus error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getSubscription(String userName) async {
    try {
      final data = await supabase
          .from('subscriptions')
          .select()
          .eq('user_name', userName)
          .eq('is_active', true)
          .order('expires_at', ascending: false)
          .limit(1);
      if (data.isEmpty) return null;
      return Map<String, dynamic>.from(data[0]);
    } catch (e) {
      return null;
    }
  }
}

// GlobalKey للتحكم بالوضع الليلي من أي مكان
final GlobalKey<_KitabiAppInnerState> kitabiAppKey =
    GlobalKey<_KitabiAppInnerState>();

class KitabiApp extends StatelessWidget {
  const KitabiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _KitabiAppInner(key: kitabiAppKey);
  }
}

class _KitabiAppInner extends StatefulWidget {
  const _KitabiAppInner({super.key});

  @override
  State<_KitabiAppInner> createState() => _KitabiAppInnerState();
}

class _KitabiAppInnerState extends State<_KitabiAppInner> {
  bool _isDark = false;
  bool _loaded = false;
  StreamSubscription<AuthState>? _authSub;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _load();
    _listenToAuth();
  }

  void _listenToAuth() {
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('Auth event: $event');
      
      // عند استلام رابط إعادة تعيين كلمة السر
      if (event == AuthChangeEvent.passwordRecovery) {
        _navKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => const ResetPasswordScreen()),
          (route) => false,
        );
        return;
      }
      
      // عند تأكيد الإيميل (signedIn من رابط التأكيد)
      if (event == AuthChangeEvent.signedIn) {
        // نتحقق من metadata
        final user = data.session?.user;
        if (user != null && user.emailConfirmedAt != null) {
          final createdAt = user.createdAt;
          // إذا كان الحساب جديداً (خلال آخر 5 دقائق)
          try {
            final created = DateTime.parse(createdAt);
            final diff = DateTime.now().difference(created);
            if (diff.inMinutes < 5) {
              _navKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const EmailVerifiedScreen()),
                (route) => false,
              );
            }
          } catch (_) {}
        }
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final dark = prefs.getBool('dark_mode') ?? false;
    final fontScale = prefs.getDouble('font_scale') ?? 1.0;
    darkModeNotifier.value = dark;
    fontScaleNotifier.value = fontScale;
    setState(() {
      _isDark = dark;
      _loaded = true;
    });
  }

  void toggleDark(bool value) async {
    setState(() => _isDark = value);
    darkModeNotifier.value = value;  // ← التحديث الفوري
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF1565C0),
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        return MaterialApp(
          title: 'Kitabi',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navKey,
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
            scaffoldBackgroundColor: const Color(0xFF121212),
            useMaterial3: true,
          ),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            return ValueListenableBuilder<double>(
              valueListenable: fontScaleNotifier,
              builder: (context, scale, _) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ============ Signup Screen (تسجيل جديد) ============
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _agreed = false;
  String? _selectedGrade;
  String? _selectedMuraqaba;
  bool _showPass = false;
  bool _showConfirm = false;
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

  Future<void> _signup() async {
    // التحقق
    if (_nameCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب اسمك');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty ||
        !_emailCtrl.text.contains('@')) {
      showKitabiSnack(context, 'اكتب بريد صحيح');
      return;
    }
    if (_passCtrl.text.length < 6) {
      showKitabiSnack(context, 'كلمة السر 6 أحرف على الأقل');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      showKitabiSnack(context, 'كلمتا السر غير متطابقتين');
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

    if (!_agreed) {
      showKitabiSnack(context, 'يجب الموافقة على الشروط');
      return;
    }

    setState(() => _saving = true);

    try {
      // 1) ننشئ الحساب في Supabase Auth
      final response = await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        emailRedirectTo: 'kitabi://email-verified',
        data: {
          'name': _nameCtrl.text.trim(),
          'grade': _selectedGrade,
          'muraqaba': _selectedMuraqaba,
        },
      );

      if (response.user == null) {
        if (!mounted) return;
        setState(() => _saving = false);
        showKitabiSnack(context, 'فشل التسجيل، حاول لاحقاً');
        return;
      }

      // 2) نحفظ البيانات في جدول users
      try {
        final existing = await supabase
            .from('users')
            .select('id')
            .eq('email', _emailCtrl.text.trim())
            .limit(1);

        if (existing.isEmpty) {
          await supabase.from('users').insert({
            'name': _nameCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'grade': _selectedGrade,
            'muraqaba': _selectedMuraqaba,
            'points': 50,
            'level': 1,
            'achievements': 0,
            'role': 'student',
          });
        }
      } catch (e) {
        debugPrint('Insert user error: $e');
      }

      // 3) نحفظ في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameCtrl.text.trim());
      await prefs.setString('user_grade', _selectedGrade!);
      await prefs.setString('user_muraqaba', _selectedMuraqaba!);
      await prefs.setString('user_email', _emailCtrl.text.trim());
      await prefs.setInt('user_points', 50);
      await prefs.setInt('user_level', 1);
      await prefs.setInt('user_achievements', 0);

      if (!mounted) return;
      setState(() => _saving = false);
      
      // نعرض dialog "تحقق من إيميلك"
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.mark_email_unread,
                    color: Color(0xFF1565C0), size: 28),
                SizedBox(width: 10),
                Text('تحقق من بريدك'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🎉 تم إنشاء حسابك بنجاح!',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                const Text('أرسلنا رابط تأكيد إلى:'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _emailCtrl.text.trim(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'افتح الرابط من إيميلك لتفعيل حسابك ثم سجّل دخولك.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFFEF6C00), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تحقق من مجلد الرسائل غير المرغوب فيها',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEF6C00)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('حسناً، سجّل الدخول',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Signup error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      String msg = 'فشل التسجيل';
      if (e.toString().contains('already registered')) {
        msg = 'هذا الإيميل مسجل من قبل';
      } else if (e.toString().contains('invalid')) {
        msg = 'بيانات غير صحيحة';
      }
      showKitabiSnack(context, msg);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
      suffixIcon: suffix,
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text('إنشاء حساب جديد',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // الشعار
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_add_alt_1,
                      size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('انضم إلى كتابي',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('أنشئ حسابك المجاني الآن',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF555555))),
              ),
              const SizedBox(height: 30),

              // الاسم
              TextField(
                controller: _nameCtrl,
                decoration: _deco('الاسم الكامل', Icons.person),
              ),
              const SizedBox(height: 14),

              // الإيميل
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: _deco('البريد الإلكتروني', Icons.email),
              ),
              const SizedBox(height: 14),

              // كلمة السر
              TextField(
                controller: _passCtrl,
                obscureText: !_showPass,
                decoration: _deco(
                  'كلمة السر',
                  Icons.lock,
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _showPass = !_showPass),
                    icon: Icon(
                      _showPass
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFF555555),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // تأكيد كلمة السر
              TextField(
                controller: _confirmCtrl,
                obscureText: !_showConfirm,
                decoration: _deco(
                  'تأكيد كلمة السر',
                  Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    icon: Icon(
                      _showConfirm
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFF555555),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // الصف
              DropdownButtonFormField<String>(
                value: _selectedGrade,
                decoration: _deco('الصف الدراسي', Icons.school),
                items: _grades
                    .map((g) =>
                        DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedGrade = v),
              ),
              const SizedBox(height: 14),

              // المراقبة
              DropdownButtonFormField<String>(
                value: _selectedMuraqaba,
                decoration: _deco('المراقبة', Icons.location_city),
                items: _muraqabat
                    .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedMuraqaba = v),
              ),
              const SizedBox(height: 20),
              
              // Checkbox الموافقة على الشروط
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _agreed
                      ? const Color(0xFF00897B).withOpacity(0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _agreed
                        ? const Color(0xFF00897B).withOpacity(0.3)
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) =>
                          setState(() => _agreed = v ?? false),
                      activeColor: const Color(0xFF00897B),
                    ),
                    Expanded(
                      child: Wrap(
                        children: [
                          const Text('أوافق على ',
                              style: TextStyle(fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const TermsOfServiceScreen()),
                            ),
                            child: const Text(
                              'شروط الاستخدام',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00897B),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(' و ',
                              style: TextStyle(fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PrivacyPolicyScreen()),
                            ),
                            child: const Text(
                              'سياسة الخصوصية',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // زر التسجيل
SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _saving ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text('إنشاء الحساب',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),

              // زر الرجوع للدخول
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('عندك حساب بالفعل؟ ',
                      style: TextStyle(fontSize: 14)),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('سجل دخول',
                        style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Login Screen (تسجيل دخول) ============
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;
  bool _saving = false;

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب بريدك');
      return;
    }
    if (_passCtrl.text.isEmpty) {
      showKitabiSnack(context, 'اكتب كلمة السر');
      return;
    }

    setState(() => _saving = true);

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (response.user == null) {
        if (!mounted) return;
        setState(() => _saving = false);
        showKitabiSnack(context, 'بيانات خاطئة');
        return;
      }

      // نجيب بيانات المستخدم من جدول users
      try {
        final data = await supabase
            .from('users')
            .select()
            .eq('email', _emailCtrl.text.trim())
            .limit(1);

        if (data.isNotEmpty) {
          final user = data[0];

          // نفحص الحظر
          if (user['is_banned'] == true) {
            await supabase.auth.signOut();
            if (!mounted) return;
            showKitabiSnack(context, 'حسابك محظور');
            setState(() => _saving = false);
            return;
          }

          // نحفظ في SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', user['name'] ?? '');
          await prefs.setString('user_grade', user['grade'] ?? '');
          await prefs.setString(
              'user_muraqaba', user['muraqaba'] ?? '');
          await prefs.setString(
              'user_email', _emailCtrl.text.trim());
          await prefs.setInt('user_points', user['points'] ?? 0);
          await prefs.setInt('user_level', user['level'] ?? 1);
          await prefs.setInt(
              'user_achievements', user['achievements'] ?? 0);

          // نتحقق من الدور
          final role = (user['role'] ?? 'student').toString();
          if (!mounted) return;
          if (role == 'admin' || role == 'moderator') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const ControlRoomScreen(
                      fromSplash: true)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeShell()),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Load user error: $e');
      }

      // لو ما لقينا المستخدم في users
      if (!mounted) return;
      showKitabiSnack(context, 'لم يتم العثور على بياناتك');
      setState(() => _saving = false);
    } catch (e) {
      debugPrint('Login error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      String msg = 'فشل تسجيل الدخول';
      if (e.toString().contains('Invalid login')) {
        msg = 'الإيميل أو كلمة السر خاطئة';
      } else if (e.toString().contains('Email not confirmed')) {
        msg = 'الإيميل غير مؤكد';
      }
      showKitabiSnack(context, msg);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty ||
        !_emailCtrl.text.contains('@')) {
      showKitabiSnack(context, 'اكتب بريدك أولاً');
      return;
    }
    
    try {
      await supabase.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
        redirectTo: 'kitabi://reset-password',
      );
      if (!mounted) return;
      
      // نعرض dialog توضيحي
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.mark_email_read, color: Color(0xFF00897B)),
              SizedBox(width: 10),
              Text('تحقق من بريدك'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم إرسال رابط تغيير كلمة السر إلى:'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _emailCtrl.text.trim(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'افتح الرابط من إيميلك لتغيير كلمة السر.',
                style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 8),
              const Text(
                '💡 تحقق من مجلد الرسائل غير المرغوب فيها',
                style: TextStyle(fontSize: 12, color: Color(0xFFEF6C00)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Forgot error: $e');
      if (!mounted) return;
      showKitabiSnack(context, 'فشل الإرسال: تأكد من الإيميل');
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
      suffixIcon: suffix,
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
              // الشعار
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1565C0).withOpacity(0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu_book,
                      size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('KITABI',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Color(0xFF1A1A1A))),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('مرحباً بعودتك 👋',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF555555))),
              ),
              const SizedBox(height: 40),

              // الإيميل
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                decoration: _deco('البريد الإلكتروني', Icons.email),
              ),
              const SizedBox(height: 14),

              // كلمة السر
              TextField(
                controller: _passCtrl,
                obscureText: !_showPass,
                decoration: _deco(
                  'كلمة السر',
                  Icons.lock,
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _showPass = !_showPass),
                    icon: Icon(
                      _showPass
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: const Color(0xFF555555),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // نسيت كلمة السر
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('نسيت كلمة السر؟',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF1565C0))),
                ),
              ),
              const SizedBox(height: 20),

              // زر الدخول
              SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _saving ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(
                          color: Colors.white)
                      : const Text('تسجيل الدخول',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              // إنشاء حساب
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ما عندك حساب؟ ',
                      style: TextStyle(fontSize: 14)),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text('أنشئ حساب',
                        style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Onboarding Screen ============
// ============ Privacy Policy Screen ============
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('سياسة الخصوصية',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.update,
                      color: Color(0xFF1565C0), size: 20),
                  SizedBox(width: 10),
                  Text('آخر تحديث: 15 أكتوبر 2026',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _section(
              'مقدمة',
              'مرحباً بك في تطبيق كتابي. نحن نحترم خصوصيتك ونلتزم بحماية بياناتك الشخصية. '
                  'توضح هذه السياسة كيفية جمعنا واستخدامنا وحمايتنا لمعلوماتك عند استخدام التطبيق.',
            ),
            _section(
              'المعلومات التي نجمعها',
              '1. معلومات التسجيل:\n'
                  '   • الاسم الكامل\n'
                  '   • البريد الإلكتروني\n'
                  '   • الصف الدراسي\n'
                  '   • المراقبة التعليمية\n\n'
                  '2. معلومات الاستخدام:\n'
                  '   • الكتب التي تقرأها\n'
                  '   • الاختبارات التي تحلها\n'
                  '   • النقاط والإنجازات',
            ),
            _section(
              'كيف نستخدم معلوماتك',
              '• لتقديم خدمات التطبيق التعليمية\n'
                  '• لتحسين تجربتك التعليمية\n'
                  '• لإرسال الإشعارات المتعلقة بالتعليم\n'
                  '• للتواصل معك بشأن حسابك\n'
                  '• لحماية التطبيق من الاستخدام المسيء',
            ),
            _section(
              'حماية البيانات',
              'نستخدم تقنيات تشفير حديثة (SSL/TLS) لحماية بياناتك. '
                  'يتم تخزين المعلومات على خوادم آمنة (Supabase) مع تطبيق سياسات صارمة للوصول.',
            ),
            _section(
              'حقوقك',
              '• الحق في الوصول إلى بياناتك\n'
                  '• الحق في تعديل بياناتك\n'
                  '• الحق في حذف حسابك\n'
                  '• الحق في الاعتراض على معالجة بياناتك',
            ),
            _section(
              'ملفات تعريف الارتباط',
              'لا نستخدم ملفات تعريف الارتباط التقليدية. '
                  'نستخدم تقنيات التخزين المحلي (SharedPreferences) '
                  'لحفظ إعداداتك مثل الوضع الليلي وحالة التسجيل.',
            ),
            _section(
              'خصوصية الأطفال',
              'التطبيق مخصص للطلاب من جميع الأعمار. '
                  'للطلاب تحت 13 عاماً، يجب الحصول على موافقة الوالدين.',
            ),
            _section(
              'التغييرات على السياسة',
              'قد نقوم بتحديث هذه السياسة من وقت لآخر. '
                  'سنقوم بإشعارك بأي تغييرات جوهرية عبر التطبيق.',
            ),
            _section(
              'مشاركة البيانات مع أطراف ثالثة',
              '• لا نبيع بياناتك الشخصية لأي طرف.\n'
                  '• نستخدم Supabase (مزود استضافة آمن) لتخزين البيانات.\n'
                  '• لا نشارك بياناتك مع أي جهة خارجية لأغراض تجارية.\n'
                  '• قد نكشف عن البيانات إذا طُلب منا قانونياً.',
            ),
            _section(
              'حقوق الملكية الفكرية',
              '• جميع محتويات التطبيق (الشعار، التصميم، الكود) مملوكة لفريق كتابي.\n'
                  '• الكتب التعليمية حقوقها محفوظة لوزارة التعليم الليبية.\n'
                  '• يمنع نسخ أو إعادة نشر أي محتوى بدون إذن.',
            ),
            _section(
              'حذف الحساب',
              'يمكنك حذف حسابك في أي وقت من:\n\n'
                  'الإعدادات → حسابي → حذف الحساب\n\n'
                  'سيتم حذف جميع بياناتك نهائياً ولا يمكن استرجاعها.',
            ),
            _section(
              'تواصل معنا',
              'لأي استفسار حول سياسة الخصوصية:\n\n'
                  '📧 mhmdkfkwfalqmaty@gmail.com\n'
                  '📞 0922251374',
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(Icons.shield, color: Colors.white, size: 45),
                  SizedBox(height: 12),
                  Text('خصوصيتك محمية',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('نلتزم بحماية بياناتك وأمانها',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  height: 1.7)),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.menu_book_rounded,
      'title': 'مرحباً بك في كتابي',
      'description':
          'كل كتب المنهج الليبي في مكان واحد. من الابتدائي إلى الثانوي.',
      'color': 0xFF1565C0,
    },
    {
      'icon': Icons.smart_toy_rounded,
      'title': 'معلم ذكي بالـ AI',
      'description':
          'اسأل أي سؤال في المنهج، وارفع صورة المسألة، واحصل على شرح مفصل.',
      'color': 0xFF7B1FA2,
    },
    {
      'icon': Icons.assignment_rounded,
      'title': 'اختبارات ودورات',
      'description':
          'اختبر نفسك، تابع تقدمك، واكسب النقاط. ودورات تعليمية كاملة.',
      'color': 0xFFEF6C00,
    },
    {
      'icon': Icons.workspace_premium,
      'title': 'اشترك في كتابي بلس',
      'description':
          'مزايا حصرية: دورات، بث تعليمي، وإمكانيات إضافية.',
      'color': 0xFF00897B,
    },
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final color = Color(page['color']);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(left: 5),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? color
                              : const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('تخطي',
                        style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF555555),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) =>
                    setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  final c = Color(p['color']);
                  return Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                c,
                                c.withOpacity(0.6),
                              ],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: c.withOpacity(0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Icon(p['icon'],
                              size: 80, color: Colors.white),
                        ),
                        const SizedBox(height: 45),
                        Text(
                          p['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: c,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          p['description'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF555555),
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: () {
                        _pageCtrl.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      icon: const Icon(Icons.arrow_forward,
                          size: 28, color: Color(0xFF555555)),
                    ),
                  const Spacer(),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _pageCtrl.nextPage(
                              duration:
                                  const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          } else {
                            _finish();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: color.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _currentPage < _pages.length - 1
                              ? 'التالي'
                              : 'ابدأ الآن',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
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

    // 0) نفحص إذا شاف الـ Onboarding
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!onboardingDone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // 1) نفحص جلسة Supabase
    final session = supabase.auth.currentSession;
    if (session == null) {
      // ما فيه جلسة → Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final userEmail = session.user.email ?? '';
    if (userEmail.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // 2) نفحص بيانات المستخدم + الحظر
    bool banned = false;
    String role = 'student';
    try {
      final data = await supabase
          .from('users')
          .select('is_banned, name, grade, muraqaba, role')
          .eq('email', userEmail)
          .limit(1);

      if (data.isNotEmpty) {
        final user = data[0];
        if (user['is_banned'] == true) banned = true;
        role = (user['role'] ?? 'student').toString();

        // نحفظ في SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', user['name'] ?? '');
        await prefs.setString('user_grade', user['grade'] ?? '');
        await prefs.setString('user_muraqaba', user['muraqaba'] ?? '');
        await prefs.setString('user_email', userEmail);
        await prefs.setInt('user_points', user['points'] ?? 0);
        await prefs.setInt('user_level', user['level'] ?? 1);
        await prefs.setInt('user_achievements', user['achievements'] ?? 0);
      } else {
        // المستخدم موجود في Auth لكن ما عنده بيانات في users
        // → نخرجه ونطلب منه يسجل من جديد
        await supabase.auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignupScreen()),
        );
        return;
      }
    } catch (e) {
      debugPrint('Check error: $e');
    }

    if (!mounted) return;

    if (banned) {
      await supabase.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BannedScreen()),
      );
      return;
    }

    // 3) نتحقق من الدور
    if (role == 'admin' || role == 'moderator') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ControlRoomScreen(fromSplash: true),
        ),
      );
      return;
    }

    // 4) الطالب العادي → HomeShell
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



// ============ Home Shell ============
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  String _userRole = 'student';
  String _userName = 'طالب';
  String _userGrade = '';

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? '';
      final grade = prefs.getString('user_grade') ?? '';
      if (mounted) {
        setState(() {
          _userName = name.isEmpty ? 'طالب' : name;
          _userGrade = grade;
        });
      }
      if (name.isEmpty) return;
      final data = await supabase
          .from('users')
          .select('role')
          .eq('name', name)
          .limit(1);
      if (data.isNotEmpty && mounted) {
        setState(() {
          _userRole = (data[0]['role'] ?? 'student').toString();
        });
      }
    } catch (e) {
      debugPrint('Role check error: $e');
    }
  }

  bool _isAdminOrModerator() {
    return _userRole == 'admin' || _userRole == 'moderator';
  }

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(
        onStartLearning: () => _goToTab(1),
        onOpenNotifications: () => _goToTab(2),
        onOpenSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const SettingsScreen()),
          );
        },
        userName: _userName,
        userGrade: _userGrade,
        userRole: _userRole,
      ),
      const LibraryTab(),
      const NotificationsTab(),
      const AccountTab(),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF5F7FA),
      body: tabs[_index],
      floatingActionButton: _isAdminOrModerator()
          ? FloatingActionButton.small(
              heroTag: 'back_to_control',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ControlRoomScreen(
                          fromSplash: true)),
                );
              },
              backgroundColor: const Color(0xFF1565C0),
              tooltip: 'رجوع للوحة التحكم',
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 20),
            )
          : null,
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
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenSettings;
  final String userName;
  final String userGrade;
  final String userRole;
  const HomeTab({
    super.key,
    required this.onStartLearning,
    this.onOpenNotifications,
    this.onOpenSettings,
    this.userName = 'طالب',
    this.userGrade = '',
    this.userRole = 'student',
  });

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
                  onPressed: onOpenNotifications,
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: Color(0xFF1565C0), size: 26),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 18),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  },
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
                            child: const Text('الإصدار 1.0',
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
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _quickBtn(context, 'المكتبة', Icons.menu_book_rounded,
                        const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const LibraryTab())))),
                    const SizedBox(width: 10),
                    Expanded(child: _quickBtn(context, 'الدورات', Icons.school_rounded,
                        const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF26A69A)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const CoursesScreen())))),
                    const SizedBox(width: 10),
                    Expanded(child: _quickBtn(context, 'المعلم الذكي', Icons.smart_toy_rounded,
                        const LinearGradient(colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const TeacherAIScreen())))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _quickBtn(context, 'المنتدى', Icons.forum_rounded,
                        const LinearGradient(colors: [Color(0xFF283593), Color(0xFF5C6BC0)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ForumScreen(
                            userName: userName,
                            userGrade: userGrade,
                            userRole: userRole,
                        ))))),
                    const SizedBox(width: 10),
                    Expanded(child: _quickBtn(context, 'الاختبارات', Icons.assignment_rounded,
                        const LinearGradient(colors: [Color(0xFFEF6C00), Color(0xFFFFA726)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const QuizzesScreen())))),
                    const SizedBox(width: 10),
                    Expanded(child: _quickBtn(context, 'ملاحظاتي', Icons.sticky_note_2_rounded,
                        const LinearGradient(colors: [Color(0xFF00838F), Color(0xFF00ACC1)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const NotesScreen())))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _quickBtn(context, 'فيديوهات', Icons.play_circle_fill_rounded,
                        const LinearGradient(colors: [Color(0xFFD32F2F), Color(0xFFEF5350)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const VideosScreen())))),
                    const SizedBox(width: 10),
                    Expanded(child: _quickBtn(context, 'شيتات وأوراق', Icons.description_rounded,
                        const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const SheetsScreen())))),
                    const SizedBox(width: 10),
                    Expanded(child: _quickBtn(context, 'آلة حاسبة', Icons.calculate_rounded,
                        const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFFF5C8A)]),
                        () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const CalculatorScreen())))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ===== الصفوف الدراسية الليبية =====
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('الصفوف الدراسية الليبية',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
          ),
          const SizedBox(height: 8),

          // المرحلة الابتدائية
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _stageHeader('المرحلة الابتدائية', Color(0xFF42A5F5),
                Icons.emoji_nature),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _gradesGrid(context, const [
              'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
              'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
            ], Color(0xFF42A5F5)),
          ),
          const SizedBox(height: 8),

          // المرحلة الإعدادية
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _stageHeader('المرحلة الإعدادية', Color(0xFFFFA726),
                Icons.school),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _gradesGrid(context, const [
              'أول إعدادي', 'ثاني إعدادي', 'ثالث إعدادي',
            ], Color(0xFFFFA726)),
          ),
          const SizedBox(height: 8),

          // المرحلة الثانوية
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _stageHeader('المرحلة الثانوية', Color(0xFF7E57C2),
                Icons.workspace_premium),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _gradesGrid(context, const [
              'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي',
            ], Color(0xFF7E57C2)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }





    Widget _stageHeader(String title, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _gradesGrid(
      BuildContext context, List<String> grades, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: grades.map((grade) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 3,
          height: 60,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GradeSubjectsScreen(
                      gradeName: grade,
                      subjects: const [
                        'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
                        'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
                      ],
                      icons: const {
                        'الرياضيات': Icons.calculate_rounded,
                        'اللغة العربية': Icons.translate_rounded,
                        'اللغة الإنجليزية': Icons.language_rounded,
                        'التربية الإسلامية': Icons.mosque_rounded,
                        'الحاسوب': Icons.computer_rounded,
                        'العلوم': Icons.science_rounded,
                        'الاجتماعيات': Icons.public_rounded,
                      },
                      colors: const {
                        'الرياضيات': Color(0xFF1565C0),
                        'اللغة العربية': Color(0xFF00897B),
                        'اللغة الإنجليزية': Color(0xFF7B1FA2),
                        'التربية الإسلامية': Color(0xFF00838F),
                        'الحاسوب': Color(0xFF283593),
                        'العلوم': Color(0xFFEF6C00),
                        'الاجتماعيات': Color(0xFFD32F2F),
                      },
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      grade,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _quickBtn(BuildContext context, String label, IconData icon,
      Gradient grad, VoidCallback onTap) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
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
class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  static const List<Map<String, dynamic>> _grades = [
    {'name': 'أول ابتدائي', 'icon': Icons.looks_one, 'color': 0xFF42A5F5},
    {'name': 'ثاني ابتدائي', 'icon': Icons.looks_two, 'color': 0xFF42A5F5},
    {'name': 'ثالث ابتدائي', 'icon': Icons.looks_3, 'color': 0xFF26A69A},
    {'name': 'رابع ابتدائي', 'icon': Icons.looks_4, 'color': 0xFF26A69A},
    {'name': 'خامس ابتدائي', 'icon': Icons.looks_5, 'color': 0xFF66BB6A},
    {'name': 'سادس ابتدائي', 'icon': Icons.looks_6, 'color': 0xFF66BB6A},
    {'name': 'أول إعدادي', 'icon': Icons.school, 'color': 0xFFFFA726},
    {'name': 'ثاني إعدادي', 'icon': Icons.school, 'color': 0xFFFFA726},
    {'name': 'ثالث إعدادي', 'icon': Icons.school, 'color': 0xFFEF6C00},
    {'name': 'أولى ثانوي', 'icon': Icons.workspace_premium, 'color': 0xFF7E57C2},
    {'name': 'ثانية ثانوي', 'icon': Icons.workspace_premium, 'color': 0xFF5E35B1},
    {'name': 'ثالثة ثانوي', 'icon': Icons.workspace_premium, 'color': 0xFF4527A0},
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
            itemBuilder: (context, i) => _gradeCard(_grades[i], context),
          ),
        ),
      ],
    );
  }

  Widget _gradeCard(Map<String, dynamic> g, BuildContext context) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => _openGrade(g['name'], context),
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
                  child: Text(g['name'],
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
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
    );
  }

  Future<void> _openGrade(String gradeName, BuildContext context) async {
    try {
      // نجيب المواد من DB
      final data = await supabase
          .from('subjects')
          .select()
          .eq('grade', gradeName)
          .order('display_order', ascending: true);

      if (!context.mounted) return;

      // نتحقق إذا فيه أقسام
      final sections = data
          .map((e) => (e['section'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (sections.isNotEmpty) {
        // فيه أقسام → نروح لشاشة اختيار القسم
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SectionSelectScreen(
              gradeName: gradeName,
              sections: sections,
            ),
          ),
        );
        return;
      }

      // ما فيه أقسام → نروح للمواد مباشرة
      final subjects = data
          .map((e) => e['subject_name'].toString())
          .toList();
      final icons = <String, IconData>{};
      final colors = <String, Color>{};
      for (var item in data) {
        final name = item['subject_name'].toString();
        icons[name] = _iconFromName(item['icon_name'].toString());
        colors[name] = _colorFromHex(item['color'].toString());
      }

      if (subjects.isEmpty) {
        showKitabiSnack(context, 'لا توجد مواد في هذا الصف');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GradeSubjectsScreen(
            gradeName: gradeName,
            subjects: subjects,
            icons: icons,
            colors: colors,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Load subjects error: $e');
      if (!context.mounted) return;
      showKitabiSnack(context, 'فشل تحميل المواد');
    }
  }

  IconData _iconFromName(String name) {
    final map = {
      'calculate': Icons.calculate_rounded,
      'translate': Icons.translate_rounded,
      'language': Icons.language_rounded,
      'mosque': Icons.mosque_rounded,
      'computer': Icons.computer_rounded,
      'science': Icons.science_rounded,
      'public': Icons.public_rounded,
      'biotech': Icons.biotech_rounded,
      'history_edu': Icons.history_edu_rounded,
      'groups': Icons.groups_rounded,
      'flag': Icons.flag_rounded,
      'sports_soccer': Icons.sports_soccer_rounded,
      'psychology': Icons.psychology_rounded,
      'bar_chart': Icons.bar_chart_rounded,
      'menu_book': Icons.menu_book_rounded,
      'edit': Icons.edit_rounded,
      'rate_review': Icons.rate_review_rounded,
    };
    return map[name] ?? Icons.book_rounded;
  }

  Color _colorFromHex(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }
}



// ============ Grade Subjects Screen ============
// ============ Section Select Screen ============
class SectionSelectScreen extends StatelessWidget {
  final String gradeName;
  final List<String> sections;
  final bool isSheets;

  const SectionSelectScreen({
    super.key,
    required this.gradeName,
    required this.sections,
    this.isSheets = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5E35B1),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(gradeName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF5E35B1).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school,
                  size: 60, color: Color(0xFF5E35B1)),
            ),
            const SizedBox(height: 20),
            const Text('اختر القسم',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            Text('صف $gradeName يحتوي على أكثر من قسم',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF555555))),
            const SizedBox(height: 30),
            ...sections.map((section) => _sectionCard(context, section)),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, String section) {
    final isScientific = section == 'علمي';
    final color = isScientific
        ? const Color(0xFF1565C0)
        : const Color(0xFF7B1FA2);
    final icon = isScientific ? Icons.science : Icons.menu_book;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            try {
              // إذا كان شيتات → نروح لقائمة الشيتات
              if (isSheets) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SheetsListScreen(
                      grade: '$gradeName - $section',
                      subject: null,
                    ),
                  ),
                );
                return;
              }

              // نجيب المواد من subjects
              final data = await supabase
                  .from('subjects')
                  .select()
                  .eq('grade', gradeName)
                  .eq('section', section)
                  .order('display_order', ascending: true);
              if (!context.mounted) return;
              final subjects = data
                  .map((e) => e['subject_name'].toString())
                  .toList();
              final icons = <String, IconData>{};
              final colors = <String, Color>{};
              for (var item in data) {
                final name = item['subject_name'].toString();
                icons[name] = _iconFromName(item['icon_name'].toString());
                colors[name] = _colorFromHex(item['color'].toString());
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GradeSubjectsScreen(
                    gradeName: '$gradeName - $section',
                    subjects: subjects,
                    icons: icons,
                    colors: colors,
                  ),
                ),
              );
            } catch (e) {
              debugPrint('Load subjects error: $e');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 36),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('القسم $section',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      const SizedBox(height: 4),
                      Text(
                        isScientific
                            ? 'العلوم + الرياضيات + الفيزياء'
                            : 'الآداب + اللغات + الفلسفة',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF555555)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_back_ios, color: color, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFromName(String name) {
    final map = {
      'calculate': Icons.calculate_rounded,
      'translate': Icons.translate_rounded,
      'language': Icons.language_rounded,
      'mosque': Icons.mosque_rounded,
      'computer': Icons.computer_rounded,
      'science': Icons.science_rounded,
      'public': Icons.public_rounded,
      'biotech': Icons.biotech_rounded,
      'history_edu': Icons.history_edu_rounded,
      'groups': Icons.groups_rounded,
      'flag': Icons.flag_rounded,
      'sports_soccer': Icons.sports_soccer_rounded,
      'psychology': Icons.psychology_rounded,
      'bar_chart': Icons.bar_chart_rounded,
      'menu_book': Icons.menu_book_rounded,
      'edit': Icons.edit_rounded,
      'rate_review': Icons.rate_review_rounded,
    };
    return map[name] ?? Icons.book_rounded;
  }

  Color _colorFromHex(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF1565C0);
    }
  }
}

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
  String _email = '';
  String _grade = '';
  String _muraqaba = '';
  int _points = 0;
  int _level = 1;
  int _achievements = 0;
  int _pendingRequests = 0;
  bool _isPlus = false;
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _load();
      }



  Future<void> _loadPendingRequests() async {
    if (_name.isEmpty) return;
    try {
      final data = await supabase
          .from('role_requests')
          .select('id')
          .eq('user_name', _name)
          .eq('status', 'pending');
      if (!mounted) return;
      setState(() => _pendingRequests = data.length);
    } catch (e) {
      debugPrint('Load pending error: $e');
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = await UserStats.get();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('user_name') ?? 'طالب';
      _email = prefs.getString('user_email') ?? '';
      _grade = prefs.getString('user_grade') ?? '';
      _muraqaba = prefs.getString('user_muraqaba') ?? '';
      _points = stats['points'] ?? 0;
      _level = stats['level'] ?? 1;
      _achievements = stats['achievements'] ?? 0;
    });
    await _loadPendingRequests();
    await _checkPlus();
    await _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    if (_email.isEmpty) return;
    final url = await AvatarHelper.getAvatarUrl(_email);
    if (!mounted) return;
    setState(() => _avatarUrl = url);
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
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
              const SizedBox(height: 20),
              const Text('تغيير الصورة الرمزية',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: Color(0xFF1565C0)),
                title: const Text('من المعرض'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt,
                    color: Color(0xFF00897B)),
                title: const Text('التقاط صورة'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (_avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('حذف الصورة',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(ctx, null),
                ),
            ],
          ),
        ),
      );

      if (source == null) {
        // حذف الصورة
        if (_avatarUrl == null) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('حذف الصورة؟'),
            content: const Text('هل تريد حذف صورة الملف الشخصي؟'),
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
                child: const Text('حذف'),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        setState(() => _uploadingAvatar = true);
        final ok = await AvatarHelper.deleteAvatar(_email);
        if (!mounted) return;
        setState(() {
          _uploadingAvatar = false;
          if (ok) _avatarUrl = null;
        });
        if (ok) {
          showKitabiSnack(context, '✅ تم حذف الصورة');
        } else {
          showKitabiSnack(context, 'فشل الحذف');
        }
        return;
      }

      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (picked == null) return;

      setState(() => _uploadingAvatar = true);
      final url = await AvatarHelper.uploadAvatar(
        email: _email,
        imageFile: File(picked.path),
      );

      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        if (url != null) _avatarUrl = url;
      });

      if (url != null) {
        showKitabiSnack(context, '✅ تم تحديث الصورة');
      } else {
        showKitabiSnack(context, 'فشل الرفع');
      }
    } catch (e) {
      debugPrint('pickAvatar error: $e');
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      showKitabiSnack(context, 'خطأ: $e');
    }
  }

  Future<void> _checkPlus() async {
    if (_email.isEmpty) return;
    try {
      final isPlus = await SubscriptionHelper.isPlusUser(_email);
      if (!mounted) return;
      setState(() => _isPlus = isPlus);
    } catch (e) {
      debugPrint('Check plus error: $e');
    }
  }

  Future<void> _logout() async {
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
                        child: ClipOval(
                            child: _uploadingAvatar
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF1565C0),
                                      strokeWidth: 3,
                                    ),
                                  )
                                : (_avatarUrl != null &&
                                        _avatarUrl!.isNotEmpty)
                                    ? Image.network(
                                        _avatarUrl!,
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            _name.isNotEmpty ? _name[0] : '؟',
                                            style: TextStyle(
                                              color: _avatarColor(),
                                              fontSize: 44,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        loadingBuilder: (ctx, child, progress) {
                                          if (progress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF1565C0),
                                              strokeWidth: 3,
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
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
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingAvatar
                                ? null
                                : _pickAvatar,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isPlus) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('PLUS',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          _name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      const Color(0xFF1565C0), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PersonalInfoScreen()),
                    ).then((_) => _load());
                  }),
                  _menuDivider(),
                  _menuItem(Icons.track_changes, 'أهدافي التعليمية',
                      const Color(0xFF66BB6A), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GoalsScreen()),
                    );
                  }),
                  _menuDivider(),
                  _menuItem(Icons.card_giftcard, 'كود الهدية 🎁',
                      const Color(0xFFE91E63), () {
                    if (_email.isEmpty) {
                      showKitabiSnack(context,
                          '⚠️ لا يوجد إيميل مسجّل، سجّل خروجك ثم دخولك مرة أخرى');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ReferralScreen(
                                userEmail: _email,
                                userName: _name,
                              )),
                    );
                  }),
                  _menuDivider(),

                  _menuItem(Icons.timer_outlined, 'مؤقت الدراسة',
                      const Color(0xFFE91E63), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PomodoroScreen()),
                    );
                  }),
                  _menuDivider(),
                  _menuItem(Icons.calendar_month, 'جدول الحصص',
                      const Color(0xFF1565C0), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScheduleScreen()),
                    );
                  }),
                  _menuDivider(),
                  _menuItem(Icons.settings_outlined, 'الإعدادات',
                      const Color(0xFF7E57C2), () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  }),
                  _menuDivider(),
                  _menuItem(Icons.help_outline, 'المساعدة والدعم',
                      const Color(0xFF26A69A), () {
                    _showHelpDialog();
                  }),
                  _menuDivider(),
                  _menuItem(Icons.privacy_tip_outlined, 'سياسة الخصوصية',
                      const Color(0xFF1565C0), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen()),
                    );
                  }),
                  _menuDivider(),
                  _menuItem(Icons.gavel, 'شروط الاستخدام',
                      const Color(0xFF00897B), () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const TermsOfServiceScreen()),
                    );
                  }),
                  _menuDivider(),
                  _menuItem(Icons.info_outline, 'عن التطبيق',
                      const Color(0xFF5E35B1), () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'KITABI',
                      applicationVersion: '1.0.0',
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
                  _menuDivider(),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B1FA2).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mail_outline,
                          color: Color(0xFF7B1FA2), size: 22),
                    ),
                    title: const Text('طلبات الصلاحيات',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_pendingRequests > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_pendingRequests',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_back_ios,
                            size: 14, color: Color(0xFF555555)),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RoleRequestsScreen(userName: _name),
                        ),
                      );
                      // نحدث العدد بعد الرجوع
                      _loadPendingRequests();
                    },
                  ),
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

  void _showHelpDialog() {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.help_outline,
                    color: Color(0xFF26A69A), size: 28),
                SizedBox(width: 10),
                Text('المساعدة والدعم',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ],
            ),
            const SizedBox(height: 20),
            _helpItem(
              Icons.phone,
              'اتصل بنا',
              '+218 92 225 1374',
              const Color(0xFF00897B),
              () => showKitabiSnack(context, 'اتصل: 0922251374'),
            ),
            const SizedBox(height: 10),
            _helpItem(
              Icons.email,
              'راسلنا',
              'support@kitabi.app',
              const Color(0xFF1565C0),
              () => showKitabiSnack(context, 'أرسل: support@kitabi.app'),
            ),
            const SizedBox(height: 10),
            _helpItem(
              Icons.question_answer,
              'الأسئلة الشائعة',
              'إجابات على أسئلتك',
              const Color(0xFF7B1FA2),
              () => _showFAQ(),
            ),
            const SizedBox(height: 10),
            _helpItem(
              Icons.info,
              'عن التطبيق',
              'الإصدار 1.0.0',
              const Color(0xFFEF6C00),
              () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'KITABI',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.menu_book,
                      size: 40, color: Color(0xFF1565C0)),
                  children: const [
                    Text(
                        'تطبيق تعليمي مجاني للطلاب الليبيين.\nجميع الخصائص مجانية بالكامل.'),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _helpItem(IconData icon, String title, String subtitle, Color color,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1A1A1A))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF555555))),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  void _showFAQ() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.question_answer, color: Color(0xFF7B1FA2)),
            SizedBox(width: 10),
            Text('الأسئلة الشائعة'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('1. هل التطبيق مجاني؟',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 5),
              Text('نعم، كل الخصائص مجانية بالكامل.',
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 15),
              Text('2. كيف أسجل في التطبيق؟',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 5),
              Text(
                  'اكتب اسمك + صفك + مراقبتك عند أول فتح.',
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 15),
              Text('3. ما هو كتابي بلس؟',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 5),
              Text(
                  'اشتراك اختياري يمنحك مزايا إضافية (بتوث تعليمية، دورات حصرية).',
                  style: TextStyle(fontSize: 13)),
              SizedBox(height: 15),
              Text('4. كيف أضيف ملاحظة؟',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 5),
              Text('من الرئيسية → ملاحظاتي → زر +.',
                  style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
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
                  Text(
                      '${book['grade']}${book['section'] != null ? ' - ${book['section']}' : ''} • ${book['subject']}',
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
        final finalUrl = ytId != null
            ? 'https://www.youtube.com/watch?v=$ytId'
            : url;
        try {
          if (!await launchUrl(Uri.parse(finalUrl),
              mode: LaunchMode.externalApplication)) {
            throw 'لا يمكن فتح الرابط';
          }
        } catch (e) {
          debugPrint('Launch error: $e');
        }
        if (mounted) Navigator.pop(context);
        return;
      } else {
        // mp4
        _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
        await _videoCtrl!.initialize();
        await _videoCtrl!.play();
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
                    : AspectRatio(
                        aspectRatio: _videoCtrl!.value.aspectRatio,
                        child: VideoPlayer(_videoCtrl!),
                      ),
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

// ============ Forum Screen ============
// ============ Post Detail Screen ============
class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String userName;
  final String userRole;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.userName,
    required this.userRole,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  bool _liked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = (widget.post['likes'] ?? 0) as int;
    _loadComments();
    _checkLiked();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('post_comments')
          .select()
          .eq('post_id', widget.post['id'])
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _comments = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load comments error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _checkLiked() async {
    try {
      final data = await supabase
          .from('post_likes')
          .select('id')
          .eq('post_id', widget.post['id'])
          .eq('user_name', widget.userName)
          .limit(1);
      if (!mounted) return;
      setState(() => _liked = data.isNotEmpty);
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    try {
      if (_liked) {
        await supabase
            .from('post_likes')
            .delete()
            .eq('post_id', widget.post['id'])
            .eq('user_name', widget.userName);
        setState(() {
          _liked = false;
          _likesCount = (_likesCount - 1).clamp(0, 99999);
        });
      } else {
        await supabase.from('post_likes').insert({
          'post_id': widget.post['id'],
          'user_name': widget.userName,
        });
        setState(() {
          _liked = true;
          _likesCount++;
        });
      }
      await supabase.from('posts').update({
        'likes': _likesCount,
      }).eq('id', widget.post['id']);
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      // نجيب بيانات الكاتب
      final prefs = await SharedPreferences.getInstance();
      final authorEmail = prefs.getString('user_email') ?? '';
      final authorAvatar = authorEmail.isNotEmpty
          ? await AvatarHelper.getAvatarUrl(authorEmail)
          : null;

      await supabase.from('post_comments').insert({
        'post_id': widget.post['id'],
        'author_name': widget.userName,
        'author_role': widget.userRole,
        'author_email': authorEmail.isEmpty ? null : authorEmail,
        'author_avatar': authorAvatar,
        'content': text,
      });
      final currentCount = widget.post['comments_count'] ?? 0;
      await supabase.from('posts').update({
        'comments_count': (currentCount as int) + 1,
      }).eq('id', widget.post['id']);

      _commentCtrl.clear();
      await _loadComments();
      if (!mounted) return;
      setState(() => _sending = false);
    } catch (e) {
      debugPrint('Send comment error: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      showKitabiSnack(context, 'فشل الإرسال');
    }
  }

  bool get _canDelete {
    return widget.userRole == 'admin' ||
        widget.userRole == 'moderator';
  }

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف المنشور'),
        content: const Text('هل تريد حذف المنشور؟'),
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await supabase.from('posts').delete().eq('id', widget.post['id']);
      if (!mounted) return;
      Navigator.pop(context);
      showKitabiSnack(context, 'تم الحذف');
    } catch (e) {
      showKitabiSnack(context, 'فشل الحذف');
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    try {
      await supabase
          .from('post_comments')
          .delete()
          .eq('id', comment['id']);
      await _loadComments();
    } catch (e) {
      showKitabiSnack(context, 'فشل الحذف');
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      if (diff.inDays < 30) return 'منذ ${diff.inDays} ي';
      return '${d.year}/${d.month}/${d.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.post['author_role'] ?? 'student';
    final roleColor = RoleHelper.roleColor(role);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('المنشور',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_canDelete)
            IconButton(
              onPressed: _deletePost,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: roleColor,
                              radius: 22,
                              child: Text(
                                (widget.post['author_name'] ?? '؟')
                                    .toString()
                                    .substring(0, 1),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                            widget.post['author_name'] ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15),
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                        decoration: BoxDecoration(
                                          color:
                                              roleColor.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          RoleHelper.roleLabel(role),
                                          style: TextStyle(
                                              color: roleColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                      _formatDate(widget.post['created_at']),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF888888))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        if (widget.post['title'] != null &&
                            widget.post['title'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(widget.post['title'],
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A))),
                          ),
                        Text(
                          widget.post['content'] ?? '',
                          style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF333333),
                              height: 1.6),
                        ),
                        const Divider(height: 25),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Row(
                                children: [
                                  Icon(
                                    _liked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _liked
                                        ? Colors.red
                                        : const Color(0xFF888888),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 5),
                                  Text('$_likesCount',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: _liked
                                              ? Colors.red
                                              : const Color(0xFF888888),
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            const Icon(Icons.comment_outlined,
                                size: 22, color: Color(0xFF888888)),
                            const SizedBox(width: 5),
                            Text('${_comments.length}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF888888),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.comment,
                          color: Color(0xFF1565C0), size: 22),
                      const SizedBox(width: 8),
                      Text('التعليقات (${_comments.length})',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1565C0)))
                  else if (_comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 50, color: Color(0xFF888888)),
                          SizedBox(height: 10),
                          Text('لا توجد تعليقات بعد',
                              style: TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 14)),
                        ],
                      ),
                    )
                  else
                    ..._comments.map((c) => _commentCard(c)),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'اكتب تعليقاً...',
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
                      color: Color(0xFF1565C0),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _sending ? null : _sendComment,
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded,
                              color: Colors.white),
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

  Widget _commentCard(Map<String, dynamic> comment) {
    final role = comment['author_role'] ?? 'student';
    final color = RoleHelper.roleColor(role);
    final canDelete = widget.userRole == 'admin' ||
        widget.userRole == 'moderator' ||
        comment['author_name'] == widget.userName;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarHelper.buildAvatar(
            email: comment['author_email'] ?? '',
            name: comment['author_name'] ?? '؟',
            avatarUrl: comment['author_avatar'],
            radius: 18,
            backgroundColor: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(comment['author_name'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(RoleHelper.roleLabel(role),
                          style: TextStyle(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text(_formatDate(comment['created_at']),
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF888888))),
                    if (canDelete)
                      GestureDetector(
                        onTap: () => _deleteComment(comment),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.close,
                              size: 14, color: Colors.red),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(comment['content'] ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF333333),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ForumScreen extends StatefulWidget {
  final String userName;
  final String userGrade;
  final String userRole;

  const ForumScreen({
    super.key,
    required this.userName,
    required this.userGrade,
    required this.userRole,
  });

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String _filter = 'all'; // all / mygrade / general

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var query = supabase.from('posts').select();
      final data = await query.order('is_pinned', ascending: false).order('created_at', ascending: false).limit(100);
      
      if (!mounted) return;
      final allPosts = List<Map<String, dynamic>>.from(data);
      
      // نفلتر حسب الفلتر
      List<Map<String, dynamic>> filtered;
      if (_filter == 'mygrade') {
        filtered = allPosts.where((p) {
          return p['post_type'] == 'grade' && p['target_grade'] == widget.userGrade;
        }).toList();
      } else if (_filter == 'general') {
        filtered = allPosts.where((p) => p['post_type'] == 'general').toList();
      } else {
        // all: منشورات صفي + العامة
        filtered = allPosts.where((p) {
          if (p['post_type'] == 'general') return true;
          if (p['post_type'] == 'grade' && p['target_grade'] == widget.userGrade) return true;
          return false;
        }).toList();
      }
      
      setState(() {
        _posts = filtered;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load posts error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get _canPost {
    return widget.userRole == 'admin' ||
        widget.userRole == 'moderator' ||
        widget.userRole == 'teacher';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.forum),
            SizedBox(width: 10),
            Text('المنتدى',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatePostScreen(
                      userName: widget.userName,
                      userRole: widget.userRole,
                      userGrade: widget.userGrade,
                    ),
                  ),
                );
                if (result == true) _load();
              },
              backgroundColor: const Color(0xFF1565C0),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('منشور جديد',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          // الفلاتر
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _filterBtn('الكل', 'all')),
                const SizedBox(width: 8),
                Expanded(child: _filterBtn('صفّي', 'mygrade')),
                const SizedBox(width: 8),
                Expanded(child: _filterBtn('عام', 'general')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF1565C0)))
                : _posts.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(0xFF1565C0),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _posts.length,
                          itemBuilder: (_, i) => _postCard(_posts[i]),
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
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1565C0)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
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

  Widget _postCard(Map<String, dynamic> post) {
    final role = post['author_role'] ?? 'student';
    final roleColor = RoleHelper.roleColor(role);
    final isPinned = post['is_pinned'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isPinned
            ? Border.all(color: const Color(0xFFFFA000), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  post: post,
                  userName: widget.userName,
                  userRole: widget.userRole,
                ),
              ),
            );
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس المنشور
                Row(
                  children: [
                    AvatarHelper.buildAvatar(
                        email: post['author_email'] ?? '',
                        name: post['author_name'] ?? '؟',
                        avatarUrl: post['author_avatar'],
                        radius: 20,
                        backgroundColor: roleColor,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(post['author_name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  RoleHelper.roleLabel(role),
                                  style: TextStyle(
                                      color: roleColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isPinned) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.push_pin,
                                    color: Color(0xFFFFA000), size: 14),
                              ],
                            ],
                          ),
                          Text(_formatDate(post['created_at']),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF888888))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // العنوان
                if (post['title'] != null &&
                    post['title'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(post['title'],
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))),
                  ),
                // المحتوى
                Text(
                  post['content'] ?? '',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF333333),
                      height: 1.5),
                ),
                const SizedBox(height: 10),
                // التصنيف
                Row(
                  children: [
                    if (post['post_type'] == 'grade')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '📚 ${post['target_grade'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (post['post_type'] == 'general') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7E57C2).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('📣 عام',
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF7E57C2),
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 20),
                // التفاعلات
                Row(
                  children: [
                    const Icon(Icons.favorite_border,
                        size: 18, color: Color(0xFF888888)),
                    const SizedBox(width: 4),
                    Text('${post['likes'] ?? 0}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888888))),
                    const SizedBox(width: 20),
                    const Icon(Icons.comment_outlined,
                        size: 18, color: Color(0xFF888888)),
                    const SizedBox(width: 4),
                    Text('${post['comments_count'] ?? 0}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888888))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      if (diff.inDays < 30) return 'منذ ${diff.inDays} ي';
      return '${d.year}/${d.month}/${d.day}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.forum_outlined,
                size: 60, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد منشورات بعد',
              style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
          if (_canPost) ...[
            const SizedBox(height: 10),
            const Text('اضغط زر + لإضافة أول منشور',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
          ],
        ],
      ),
    );
  }
}

// ============ Create Post Screen ============
class CreatePostScreen extends StatefulWidget {
  final String userName;
  final String userRole;
  final String userGrade;

  const CreatePostScreen({
    super.key,
    required this.userName,
    required this.userRole,
    required this.userGrade,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _postType = 'general';
  String? _targetGrade;
  bool _isPinned = false;
  bool _saving = false;

  final List<String> _grades = [
    'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
    'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
    'أول إعدادي', 'ثاني إعدادي', 'ثالث إعدادي',
    'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي',
  ];

  Future<void> _save() async {
    if (_contentCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب محتوى المنشور');
      return;
    }
    if (_postType == 'grade' && _targetGrade == null) {
      showKitabiSnack(context, 'اختر الصف');
      return;
    }

    setState(() => _saving = true);

    try {
      // نجيب بيانات الكاتب
      final prefs = await SharedPreferences.getInstance();
      final authorEmail = prefs.getString('user_email') ?? '';
      final authorAvatar = authorEmail.isNotEmpty
          ? await AvatarHelper.getAvatarUrl(authorEmail)
          : null;

      await supabase.from('posts').insert({
        'author_name': widget.userName,
        'author_role': widget.userRole,
        'author_email': authorEmail.isEmpty ? null : authorEmail,
        'author_avatar': authorAvatar,
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'post_type': _postType,
        'target_grade': _postType == 'grade' ? _targetGrade : null,
        'is_pinned': _isPinned,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Create post error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showKitabiSnack(context, 'فشل النشر');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('منشور جديد',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('نشر',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // نوع المنشور
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نوع المنشور:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _typeBtn('📣 عام', 'general',
                            'للجميع'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _typeBtn('📚 لصف معين', 'grade',
                            'لصف واحد'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // اختيار الصف
            if (_postType == 'grade') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonFormField<String>(
                  value: _targetGrade,
                  decoration: InputDecoration(
                    labelText: 'الصف',
                    prefixIcon: const Icon(Icons.school,
                        color: Color(0xFF1565C0)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _grades
                      .map((g) => DropdownMenuItem(
                          value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setState(() => _targetGrade = v),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // العنوان
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'عنوان (اختياري)',
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // المحتوى
            TextField(
              controller: _contentCtrl,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'محتوى المنشور',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // تثبيت
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, color: Color(0xFFFFA000)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('تثبيت المنشور في الأعلى',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Switch(
                    value: _isPinned,
                    onChanged: (v) => setState(() => _isPinned = v),
                    activeColor: const Color(0xFFFFA000),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(String label, String value, String sub) {
    final active = _postType == value;
    return GestureDetector(
      onTap: () => setState(() => _postType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1565C0)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF555555),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            Text(sub,
                style: TextStyle(
                    color: active
                        ? Colors.white70
                        : const Color(0xFF888888),
                    fontSize: 10)),
          ],
        ),
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
      if (apiKey.isEmpty) {
        return 'خدمة المعلم غير مفعّلة. تواصل مع الإدارة.';
      }

      final model = 'google/gemma-4-26b-a4b-it:free';

      final sys = 'أنت "معلم كتابي"، معلم ذكي متخصص في المنهج الليبي الرسمي. '
          'تعمل في تطبيق كتابي التعليمي الليبي. '
          'الطالب اسمه: $_userName. صفه: $_userGrade. '
          '\n\n'
          'قواعد مهمة:\n'
          '1. اشرح حسب المنهج الليبي الرسمي (من كتب وزارة التربية والتعليم الليبية).\n'
          '2. استخدم المصطلحات الليبية المستخدمة في الكتب المدرسية.\n'
          '3. إذا كان الدرس في كتاب الصف المحدد، اتبع ترتيب الكتاب وأمثلته.\n'
          '4. اذكر رقم الباب/الفصل إذا أمكن.\n'
          '5. رد بالعربية الفصحى المبسطة مع لمسة ليبية خفيفة.\n'
          '6. اشرح خطوة بخطوة مع أمثلة عملية.\n'
          '7. إذا لم تكن متأكداً من تفاصيل المنهج، قل ذلك بصراحة واقترح على الطالب مراجعة الكتاب.\n'
          '8. لا تختلق معلومات غير موجودة في المنهج الليبي.\n'
          '\n'
          'ابدأ ردك بتحية لطيفة للطالب، ثم اشرح بلطف ووضوح. اجعل الإجابة منظمة ومختصرة.';

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://kitabi.app',
          'X-Title': 'Kitabi',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': sys},
            {'role': 'user', 'content': question},
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['choices'] != null &&
            data['choices'] is List &&
            data['choices'].isNotEmpty) {
          final msg = data['choices'][0]['message'];
          if (msg != null && msg['content'] != null) {
            return msg['content'].toString();
          }
        }
        return 'لم أفهم الرد. جرب مرة أخرى.';
      } else if (response.statusCode == 429) {
        // نجرب نموذج بديل
        return await _tryAlternativeModel(question, apiKey, sys);
      } else if (response.statusCode == 401) {
        return 'مفتاح المعلم غير صحيح.';
      } else if (response.statusCode == 503 || response.statusCode == 404) {
        return await _tryAlternativeModel(question, apiKey, sys);
      } else {
        return 'حدث خطأ (${response.statusCode}). جرب لاحقاً.';
      }
    } catch (e) {
      debugPrint('OpenRouter error: $e');
      return 'تعذر الاتصال بالمعلم. تحقق من الإنترنت.';
    }
  }

  Future<String> _tryAlternativeModel(
      String question, String apiKey, String sys) async {
    final models = [
      'google/gemma-4-26b-a4b-it:free',
      'nvidia/nemotron-3.5-lightning:free',
      'liquid/lfm-2.5-2.6b:free',
      'openrouter/free',
    ];

    for (var model in models) {
      try {
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://kitabi.app',
            'X-Title': 'Kitabi',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': sys},
              {'role': 'user', 'content': question},
            ],
            'temperature': 0.7,
            'max_tokens': 1000,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data['choices'] != null &&
              data['choices'] is List &&
              data['choices'].isNotEmpty) {
            final msg = data['choices'][0]['message'];
            if (msg != null && msg['content'] != null) {
              return msg['content'].toString();
            }
          }
        }
      } catch (e) {
        debugPrint('Alt model error: $e');
        continue;
      }
    }

    return 'المعلم مشغول حالياً. جرب بعد دقيقة.';
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

// ============ Add Subscription Screen ============
class AddSubscriptionScreen extends StatefulWidget {
  const AddSubscriptionScreen({super.key});
  @override
  State<AddSubscriptionScreen> createState() => _AddSubscriptionScreenState();
}

class _AddSubscriptionScreenState extends State<AddSubscriptionScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _search = '';
  String _selectedDuration = '1';
  String? _selectedUserEmail;
  String? _selectedUserName;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load users error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    if (_selectedUserEmail == null || _selectedUserEmail!.isEmpty) {
      showKitabiSnack(context, 'اختر مستخدماً لديه إيميل');
      return;
    }

    final months = int.parse(_selectedDuration);
    final now = DateTime.now();
    final expires = DateTime(now.year, now.month + months, now.day);

    try {
      // نتحقق إذا عنده اشتراك سابق
      final existing = await supabase
          .from('subscriptions')
          .select('id')
          .eq('user_email', _selectedUserEmail!)
          .eq('is_active', true)
          .limit(1);

      if (existing.isNotEmpty) {
        // نحدّث الموجود
        await supabase.from('subscriptions').update({
          'expires_at': expires.toIso8601String(),
          'started_at': now.toIso8601String(),
          'starts_at': now.toIso8601String(),
        }).eq('id', existing[0]['id']);
      } else {
        // نضيف جديد
        await supabase.from('subscriptions').insert({
          'user_email': _selectedUserEmail,
          'user_name': _selectedUserName,
          'plan': 'plus',
          'is_active': true,
          'started_at': now.toIso8601String(),
          'starts_at': now.toIso8601String(),
          'expires_at': expires.toIso8601String(),
        });
      }

      if (!mounted) return;
      showKitabiSnack(context, '✅ تم تفعيل Plus بنجاح');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showKitabiSnack(context, 'فشل التفعيل: $e');
    }
  }

    @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _users
        : _users.where((u) {
            final name = (u['name'] ?? '').toString();
            return name.contains(_search);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFA000),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('إضافة اشتراك بلس',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // اختيار المدة
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر المدة:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _durationChip('1', 'شهر'),
                    const SizedBox(width: 8),
                    _durationChip('6', '6 شهور'),
                    const SizedBox(width: 8),
                    _durationChip('12', 'سنة'),
                  ],
                ),
              ],
            ),
          ),
          // البحث
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن مستخدم...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // قائمة المستخدمين
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFFA000)))
                : filtered.isEmpty
                    ? const Center(child: Text('لا يوجد مستخدمون'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _userCard(filtered[i]),
                      ),
          ),
          // زر التفعيل
          if (_selectedUserEmail != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _activate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'تفعيل بلس لـ $_selectedUserName',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _durationChip(String value, String label) {
    final selected = _selectedDuration == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDuration = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFA000)
                : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF555555),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final name = (user['name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final hasEmail = email.isNotEmpty && email != 'null';
    final isSelected = _selectedUserEmail == email;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFFFA000).withOpacity(0.15)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFFA000)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: hasEmail
            ? () => setState(() {
                  _selectedUserEmail = email;
                  _selectedUserName = name;
                })
            : () => showKitabiSnack(context,
                'هذا المستخدم لا يملك إيميل'),
        leading: CircleAvatar(
          backgroundColor: hasEmail
              ? const Color(0xFF1565C0)
              : Colors.grey,
          child: Text(
            name.isNotEmpty ? name[0] : '؟',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          hasEmail ? name : '$name (بدون إيميل)',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: hasEmail
                  ? const Color(0xFF1A1A1A)
                  : Colors.grey),
        ),
        subtitle: Text(
          '${user['grade']} • ${user['muraqaba']}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle,
                color: Color(0xFFFFA000), size: 26)
            : null,
      ),
    );
  }
}

// ============ Subscriptions List Screen ============
class SubscriptionsListScreen extends StatefulWidget {
  const SubscriptionsListScreen({super.key});
  @override
  State<SubscriptionsListScreen> createState() =>
      _SubscriptionsListScreenState();
}

class _SubscriptionsListScreenState extends State<SubscriptionsListScreen> {
  List<Map<String, dynamic>> _subs = [];
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
          .from('subscriptions')
          .select()
          .eq('is_active', true)
          .order('expires_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _subs = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _cancelSubscription(Map<String, dynamic> sub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('إلغاء الاشتراك'),
        content: Text('هل تريد إلغاء بلس لـ "${sub['user_name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase.from('subscriptions').update({
        'is_active': false,
      }).eq('id', sub['id']);
      if (!mounted) return;
      showKitabiSnack(context, 'تم إلغاء الاشتراك');
      _load();
    } catch (e) {
      showKitabiSnack(context, 'فشل الإلغاء');
    }
  }

  String _daysLeft(String? expiresStr) {
    if (expiresStr == null) return '';
    try {
      final expires = DateTime.parse(expiresStr);
      final diff = expires.difference(DateTime.now()).inDays;
      if (diff < 0) return 'منتهي';
      if (diff == 0) return 'اليوم';
      if (diff == 1) return 'يوم واحد';
      return '$diff يوم';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFA000),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('اشتراكات بلس (${_subs.length})',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFA000)))
          : _subs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.card_membership,
                          size: 80, color: Color(0xFFFFA000)),
                      SizedBox(height: 15),
                      Text('لا توجد اشتراكات نشطة',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFF555555))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFFFA000),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _subs.length,
                    itemBuilder: (_, i) => _subCard(_subs[i]),
                  ),
                ),
    );
  }

  Widget _subCard(Map<String, dynamic> sub) {
    final name = (sub['user_name'] ?? '').toString();
    final days = _daysLeft(sub['expires_at']);
    final expired = days == 'منتهي';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor:
                  expired ? Colors.grey : const Color(0xFFFFA000),
              child: Text(
                name.isNotEmpty ? name[0] : '؟',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: expired ? Colors.grey : const Color(0xFFFFA000),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  expired ? Icons.timer_off : Icons.workspace_premium,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 6),
            if (!expired)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('PLUS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        subtitle: Text(
          'متبقي: $days',
          style: TextStyle(
            fontSize: 12,
            color: expired ? Colors.red : const Color(0xFF555555),
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: IconButton(
          onPressed: () => _cancelSubscription(sub),
          icon: const Icon(Icons.cancel, color: Colors.red, size: 22),
          tooltip: 'إلغاء',
        ),
      ),
    );
  }
}

// ============ Manage Roles Screen ============
class ManageRolesScreen extends StatefulWidget {
  const ManageRolesScreen({super.key});
  @override
  State<ManageRolesScreen> createState() => _ManageRolesScreenState();
}

class _ManageRolesScreenState extends State<ManageRolesScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('users')
          .select()
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _sendRoleRequest(Map<String, dynamic> user) async {
    String? newRole;
    final msgCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield, color: Color(0xFF7B1FA2)),
              SizedBox(width: 10),
              Text('تعيين دور',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('اختر الدور لـ "${user['name']}":',
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 15),
              _roleOption('teacher', 'معلم', Icons.school,
                  const Color(0xFF00897B), newRole, (r) {
                newRole = r;
                setSt(() {});
              }),
              const SizedBox(height: 8),
              _roleOption('moderator', 'مشرف', Icons.shield,
                  const Color(0xFF7B1FA2), newRole, (r) {
                newRole = r;
                setSt(() {});
              }),
              const SizedBox(height: 8),
              _roleOption('admin', 'مدير',
                  Icons.admin_panel_settings, const Color(0xFFD32F2F),
                  newRole, (r) {
                newRole = r;
                setSt(() {});
              }),
              const SizedBox(height: 15),
              TextField(
                controller: msgCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'رسالة (اختياري)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newRole == null) {
                  showKitabiSnack(context, 'اختر دوراً');
                  return;
                }
                Navigator.pop(ctx, true);
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

    if (confirm != true || newRole == null) return;

    try {
      await supabase.from('role_requests').insert({
        'user_name': user['name'],
        'requested_role': newRole,
        'message': msgCtrl.text.trim().isEmpty
            ? 'طلب تعيين كـ ${RoleHelper.roleLabel(newRole)}'
            : msgCtrl.text.trim(),
        'status': 'pending',
      });
      if (!mounted) return;
      showKitabiSnack(context, 'تم إرسال الطلب لـ ${user['name']}');
    } catch (e) {
      if (!mounted) return;
      showKitabiSnack(context, 'فشل الإرسال');
    }
  }

  Widget _roleOption(String value, String label, IconData icon,
      Color color, String? current, Function(String) onSelect) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 14)),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _users
        : _users
            .where((u) => (u['name'] ?? '').toString().contains(_search))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('إدارة الصلاحيات',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن مستخدم...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF7B1FA2)))
                : filtered.isEmpty
                    ? const Center(child: Text('لا يوجد مستخدمون'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(0xFF7B1FA2),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _userCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final role = user['role'] ?? 'student';
    final color = RoleHelper.roleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Text(
                (user['name'] ?? '؟').toString().substring(0, 1),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(RoleHelper.roleIcon(role),
                    color: Colors.white, size: 10),
              ),
            ),
          ],
        ),
        title: Text(user['name'] ?? '',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(RoleHelper.roleLabel(role),
                  style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Text('${user['grade'] ?? ''}',
                style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _sendRoleRequest(user),
          icon: const Icon(Icons.edit, color: Color(0xFF7B1FA2), size: 22),
          tooltip: 'تعيين دور',
        ),
      ),
    );
  }
}

// ============ Role Requests Screen (للمستخدم) ============
class RoleRequestsScreen extends StatefulWidget {
  final String userName;
  const RoleRequestsScreen({super.key, required this.userName});

  @override
  State<RoleRequestsScreen> createState() => _RoleRequestsScreenState();
}

class _RoleRequestsScreenState extends State<RoleRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
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
          .from('role_requests')
          .select()
          .eq('user_name', widget.userName)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> req, bool accept) async {
    try {
      if (accept) {
        await supabase.from('users').update({
          'role': req['requested_role'],
        }).eq('name', widget.userName);
      }
      await supabase.from('role_requests').update({
        'status': accept ? 'accepted' : 'rejected',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', req['id']);

      if (!mounted) return;
      showKitabiSnack(
          context, accept ? 'تم قبول الدور ✅' : 'تم الرفض');
      _load();
    } catch (e) {
      if (!mounted) return;
      showKitabiSnack(context, 'فشل');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('طلباتي (${_requests.length})',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7B1FA2)))
          : _requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox,
                          size: 80, color: Color(0xFF7B1FA2)),
                      SizedBox(height: 15),
                      Text('لا توجد طلبات',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFF555555))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _requests.length,
                  itemBuilder: (_, i) => _requestCard(_requests[i]),
                ),
    );
  }

  Widget _requestCard(Map<String, dynamic> req) {
    final role = req['requested_role'] ?? 'teacher';
    final color = RoleHelper.roleColor(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(RoleHelper.roleIcon(role),
                    color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('دعوة لتصبح ${RoleHelper.roleLabel(role)}',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const SizedBox(height: 4),
                    Text(req['message'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _respond(req, false),
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                  label: const Text('رفض',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _respond(req, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('قبول',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============ Advanced Settings Screen ============
// ============ Statistics Screen ============
// ============ Change Password Screen ============
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

  Future<void> _save() async {
    if (_oldCtrl.text.trim().isEmpty ||
        _newCtrl.text.trim().isEmpty ||
        _confirmCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'املأ كل الحقول');
      return;
    }
    if (_newCtrl.text.trim() != _confirmCtrl.text.trim()) {
      showKitabiSnack(context, 'كلمتا السر غير متطابقتين');
      return;
    }
    if (_newCtrl.text.trim().length < 4) {
      showKitabiSnack(context, 'كلمة السر قصيرة (4 أحرف على الأقل)');
      return;
    }

    setState(() => _saving = true);

    try {
      final data = await supabase
          .from('admin_settings')
          .select('admin_password')
          .eq('id', 1)
          .single();
      final current = data['admin_password'] ?? 'العلم نور';

      if (_oldCtrl.text.trim() != current) {
        if (!mounted) return;
        setState(() => _saving = false);
        showKitabiSnack(context, 'كلمة السر الحالية خاطئة');
        return;
      }

      await supabase.from('admin_settings').update({
        'admin_password': _newCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);

      if (!mounted) return;
      showKitabiSnack(context, 'تم تغيير كلمة السر بنجاح');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Change pwd error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showKitabiSnack(context, 'فشل التغيير');
    }
  }

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEF6C00),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('تغيير كلمة سر الغرفة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFEF6C00).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_reset,
                  size: 60, color: Color(0xFFEF6C00)),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('غيّر كلمة سر الدخول للمشرفين',
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF555555))),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _oldCtrl,
              obscureText: !_showOld,
              decoration: InputDecoration(
                labelText: 'كلمة السر الحالية',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showOld = !_showOld),
                  icon: Icon(
                    _showOld ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF555555),
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _newCtrl,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: 'كلمة السر الجديدة',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showNew = !_showNew),
                  icon: Icon(
                    _showNew ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF555555),
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة السر',
                prefixIcon: const Icon(Icons.check_circle_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                  icon: Icon(
                    _showConfirm ? Icons.visibility : Icons.visibility_off,
                    color: const Color(0xFF555555),
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('حفظ',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF6C00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Quick Broadcast Screen ============
class QuickBroadcastScreen extends StatefulWidget {
  const QuickBroadcastScreen({super.key});
  @override
  State<QuickBroadcastScreen> createState() => _QuickBroadcastScreenState();
}

class _QuickBroadcastScreenState extends State<QuickBroadcastScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _target = 'all';
  bool _sending = false;

  final List<String> _templates = [
    'صيانة مجدولة: سيتوقف التطبيق غداً من 2-4 صباحاً',
    'تحديث جديد متوفر: تم إضافة ميزات رائعة',
    'مسابقة أسبوعية: شارك واكسب نقاط',
    'تذكير: راجع دروسك اليوم',
  ];

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty ||
        _bodyCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب العنوان والنص');
      return;
    }

    setState(() => _sending = true);

    try {
      await supabase.from('notifications').insert({
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'target_type': _target,
        'sent_by': 'admin',
      });
      if (!mounted) return;
      showKitabiSnack(context, '✅ تم إرسال الإشعار');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Broadcast error: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      showKitabiSnack(context, 'فشل الإرسال');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
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
        title: const Text('إشعار جماعي سريع',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // قوالب جاهزة
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt,
                          color: Color(0xFFFFA000), size: 20),
                      SizedBox(width: 8),
                      Text('قوالب سريعة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._templates.map((t) => GestureDetector(
                        onTap: () =>
                            setState(() => _bodyCtrl.text = t),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(t,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'عنوان الإشعار',
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'نص الإشعار',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: DropdownButtonFormField<String>(
                value: _target,
                decoration: const InputDecoration(
                  labelText: 'المرسل إليه',
                  prefixIcon: Icon(Icons.people),
                  border: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الجميع')),
                  DropdownMenuItem(
                      value: 'plus_only', child: Text('مشتركو بلس فقط')),
                  DropdownMenuItem(
                      value: 'teachers', child: Text('المعلمون فقط')),
                ],
                onChanged: (v) =>
                    setState(() => _target = v ?? 'all'),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('إرسال',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Export CSV Screen ============
class ExportCSVScreen extends StatefulWidget {
  const ExportCSVScreen({super.key});
  @override
  State<ExportCSVScreen> createState() => _ExportCSVScreenState();
}

class _ExportCSVScreenState extends State<ExportCSVScreen> {
  bool _exporting = false;
  String _status = '';

  Future<void> _exportAll() async {
    setState(() {
      _exporting = true;
      _status = 'جاري التصدير...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp =
          DateTime.now().millisecondsSinceEpoch.toString();
      final exportDir = Directory('${dir.path}/kitabi_export_$timestamp');
      await exportDir.create(recursive: true);

      // 1) المستخدمون
      final users = await supabase.from('users').select();
      await _writeCSV(exportDir, 'users.csv', users);

      // 2) الكتب
      final books = await supabase.from('books').select();
      await _writeCSV(exportDir, 'books.csv', books);

      // 3) الإشعارات
      final notifs = await supabase.from('notifications').select();
      await _writeCSV(exportDir, 'notifications.csv', notifs);

      // 4) الفيديوهات
      final videos = await supabase.from('videos').select();
      await _writeCSV(exportDir, 'videos.csv', videos);

      // 5) الاختبارات
      final quizzes = await supabase.from('quizzes').select();
      await _writeCSV(exportDir, 'quizzes.csv', quizzes);

      // 6) المنشورات
      final posts = await supabase.from('posts').select();
      await _writeCSV(exportDir, 'posts.csv', posts);

      // 7) التعليقات
      final comments = await supabase.from('post_comments').select();
      await _writeCSV(exportDir, 'comments.csv', comments);

      // 8) الاشتراكات
      final subs = await supabase.from('subscriptions').select();
      await _writeCSV(exportDir, 'subscriptions.csv', subs);

      if (!mounted) return;
      setState(() {
        _exporting = false;
        _status = '✅ تم التصدير إلى:\n${exportDir.path}';
      });
      showKitabiSnack(context, 'تم التصدير بنجاح');
    } catch (e) {
      debugPrint('Export error: $e');
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _status = '❌ فشل: $e';
      });
    }
  }

  Future<void> _writeCSV(
      Directory dir, String name, List<dynamic> data) async {
    if (data.isEmpty) return;
    final rows = <String>[];
    final keys = (data[0] as Map).keys.toList();
    rows.add(keys.join(','));
    for (var item in data) {
      final row = keys.map((k) {
        final v = item[k];
        if (v == null) return '';
        final s = v.toString().replaceAll(',', ';').replaceAll('\n', ' ');
        return '"$s"';
      }).join(',');
      rows.add(row);
    }
    final file = File('${dir.path}/$name');
    await file.writeAsString('\uFEFF${rows.join('\n')}',
        encoding: utf8);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('تصدير البيانات (CSV)',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.download,
                  size: 60, color: Color(0xFF00897B)),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('تصدير كل البيانات كملفات CSV',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                  'سيتم إنشاء مجلد يحتوي على 8 ملفات CSV',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF555555))),
            ),
            const SizedBox(height: 20),
            // الملفات
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExportItem('📁', 'users.csv', 'المستخدمون'),
                  _ExportItem('📁', 'books.csv', 'الكتب + الشيتات'),
                  _ExportItem('📁', 'notifications.csv', 'الإشعارات'),
                  _ExportItem('📁', 'videos.csv', 'الفيديوهات'),
                  _ExportItem('📁', 'quizzes.csv', 'الاختبارات'),
                  _ExportItem('📁', 'posts.csv', 'المنشورات'),
                  _ExportItem('📁', 'comments.csv', 'التعليقات'),
                  _ExportItem('📁', 'subscriptions.csv', 'الاشتراكات'),
                ],
              ),
            ),
            const SizedBox(height: 25),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _status.startsWith('✅')
                      ? Colors.green.shade50
                      : _status.startsWith('❌')
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_status,
                    style: const TextStyle(fontSize: 12, height: 1.5)),
              ),
            const SizedBox(height: 15),
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _exportAll,
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.file_download),
                label: Text(
                  _exporting ? 'جاري التصدير...' : 'تصدير الكل',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportItem extends StatelessWidget {
  final String icon, file, desc;
  const _ExportItem(this.icon, this.file, this.desc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(file,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text(desc,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ============ Backup Screen ============
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _creating = false;
  String _status = '';

  Future<void> _createBackup() async {
    setState(() {
      _creating = true;
      _status = 'جاري الإنشاء...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final backupFile = File('${dir.path}/kitabi_backup_$timestamp.json');

      // نجمع كل البيانات
      final data = <String, dynamic>{
        'created_at': DateTime.now().toIso8601String(),
        'version': '1.0.0',
        'users': await supabase.from('users').select(),
        'books': await supabase.from('books').select(),
        'notifications': await supabase.from('notifications').select(),
        'videos': await supabase.from('videos').select(),
        'quizzes': await supabase.from('quizzes').select(),
        'posts': await supabase.from('posts').select(),
        'post_comments': await supabase.from('post_comments').select(),
        'subscriptions': await supabase.from('subscriptions').select(),
        'role_requests': await supabase.from('role_requests').select(),
        'app_settings': await supabase.from('app_settings').select(),
        'admin_settings': await supabase.from('admin_settings').select(),
      };

      await backupFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(data));

      if (!mounted) return;
      setState(() {
        _creating = false;
        _status = '✅ تم الحفظ:\n${backupFile.path}';
      });
      showKitabiSnack(context, 'تم إنشاء النسخة الاحتياطية');
    } catch (e) {
      debugPrint('Backup error: $e');
      if (!mounted) return;
      setState(() {
        _creating = false;
        _status = '❌ فشل: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('نسخة احتياطية',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.backup,
                  size: 60, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text('نسخة احتياطية كاملة',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                  'ملف JSON يحتوي على كل بيانات التطبيق',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF555555))),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📦 النسخة تحتوي على:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 10),
                  Text('• المستخدمون + الصلاحيات',
                      style: TextStyle(fontSize: 12, height: 1.6)),
                  Text('• الكتب + الشيتات',
                      style: TextStyle(fontSize: 12, height: 1.6)),
                  Text('• الإشعارات + الفيديوهات',
                      style: TextStyle(fontSize: 12, height: 1.6)),
                  Text('• المنشورات + التعليقات',
                      style: TextStyle(fontSize: 12, height: 1.6)),
                  Text('• الاشتراكات + الطلبات',
                      style: TextStyle(fontSize: 12, height: 1.6)),
                  Text('• إعدادات التطبيق',
                      style: TextStyle(fontSize: 12, height: 1.6)),
                ],
              ),
            ),
            const SizedBox(height: 25),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _status.startsWith('✅')
                      ? Colors.green.shade50
                      : _status.startsWith('❌')
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_status,
                    style: const TextStyle(fontSize: 12, height: 1.5)),
              ),
            const SizedBox(height: 15),
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _createBackup,
                icon: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_alt),
                label: Text(
                  _creating ? 'جاري الإنشاء...' : 'إنشاء نسخة احتياطية',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  Map<String, int> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await supabase.from('users').select('id, role, is_banned');
      final books = await supabase.from('books').select('id, category');
      final notifs = await supabase.from('notifications').select('id');
      final videos = await supabase.from('videos').select('id');
      final quizzes = await supabase.from('quizzes').select('id');
      final posts = await supabase.from('posts').select('id');
      final comments = await supabase.from('post_comments').select('id');
      final subs = await supabase
          .from('subscriptions')
          .select('id, is_active, expires_at');

      final activeSubs = subs.where((s) {
        if (s['is_active'] != true) return false;
        try {
          final exp = DateTime.parse(s['expires_at'].toString());
          return exp.isAfter(DateTime.now());
        } catch (_) {
          return false;
        }
      }).length;

      final teachers = users.where((u) => u['role'] == 'teacher').length;
      final mods = users.where((u) => u['role'] == 'moderator').length;
      final admins = users.where((u) => u['role'] == 'admin').length;
      final banned = users.where((u) => u['is_banned'] == true).length;
      final booksCount =
          books.where((b) => b['category'] != 'sheets').length;
      final sheetsCount =
          books.where((b) => b['category'] == 'sheets').length;

      if (!mounted) return;
      setState(() {
        _stats = {
          'المستخدمون': users.length,
          'المعلمون': teachers,
          'المشرفون': mods,
          'المدراء': admins,
          'المحظورون': banned,
          'الكتب': booksCount,
          'الشيتات': sheetsCount,
          'الإشعارات': notifs.length,
          'الفيديوهات': videos.length,
          'الاختبارات': quizzes.length,
          'المنشورات': posts.length,
          'التعليقات': comments.length,
          'مشتركو بلس': activeSubs,
        };
        _loading = false;
      });
    } catch (e) {
      debugPrint('Stats error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF283593),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('الإحصائيات الشاملة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF283593)))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF283593),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('المستخدمون', Icons.people),
                  _statsGrid([
                    'المستخدمون', 'المعلمون', 'المشرفون',
                    'المدراء', 'المحظورون', 'مشتركو بلس',
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle('المحتوى', Icons.library_books),
                  _statsGrid([
                    'الكتب', 'الشيتات', 'الإشعارات',
                    'الفيديوهات', 'الاختبارات',
                  ]),
                  const SizedBox(height: 20),
                  _sectionTitle('المنتدى', Icons.forum),
                  _statsGrid(['المنشورات', 'التعليقات']),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF283593)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  Widget _statsGrid(List<String> keys) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemCount: keys.length,
      itemBuilder: (_, i) => _statCard(keys[i]),
    );
  }

  Widget _statCard(String key) {
    final value = _stats[key] ?? 0;
    final color = _colorFor(key);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(key,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('$value',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Color _colorFor(String key) {
    switch (key) {
      case 'المستخدمون':
        return const Color(0xFF1565C0);
      case 'المعلمون':
        return const Color(0xFF00897B);
      case 'المشرفون':
        return const Color(0xFF7B1FA2);
      case 'المدراء':
        return const Color(0xFFD32F2F);
      case 'المحظورون':
        return const Color(0xFF555555);
      case 'مشتركو بلس':
        return const Color(0xFFFFA000);
      case 'الكتب':
        return const Color(0xFF1565C0);
      case 'الشيتات':
        return const Color(0xFF00695C);
      case 'الإشعارات':
        return const Color(0xFF7B1FA2);
      case 'الفيديوهات':
        return const Color(0xFFD32F2F);
      case 'الاختبارات':
        return const Color(0xFFEF6C00);
      case 'المنشورات':
        return const Color(0xFF283593);
      case 'التعليقات':
        return const Color(0xFF00838F);
      default:
        return const Color(0xFF555555);
    }
  }
}

// ============ Color Settings Screen ============
class ColorSettingsScreen extends StatefulWidget {
  const ColorSettingsScreen({super.key});
  @override
  State<ColorSettingsScreen> createState() => _ColorSettingsScreenState();
}

class _ColorSettingsScreenState extends State<ColorSettingsScreen> {
  String _primary = '#1565C0';
  String _nav = '#2C2C2E';
  bool _loading = true;

  final List<String> _colors = [
    '#1565C0', // أزرق
    '#00897B', // أخضر مزرق
    '#7B1FA2', // بنفسجي
    '#D32F2F', // أحمر
    '#EF6C00', // برتقالي
    '#283593', // نيلي
    '#00695C', // أخضر داكن
    '#455A64', // رمادي مزرق
    '#F57C00', // ذهبي
    '#C2185B', // وردي
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('app_settings')
          .select('primary_color, nav_color')
          .eq('id', 1)
          .single();
      if (!mounted) return;
      setState(() {
        _primary = data['primary_color'] ?? '#1565C0';
        _nav = data['nav_color'] ?? '#2C2C2E';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<void> _save() async {
    try {
      await supabase.from('app_settings').update({
        'primary_color': _primary,
        'nav_color': _nav,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
      if (!mounted) return;
      showKitabiSnack(context, 'تم حفظ الألوان');
    } catch (e) {
      showKitabiSnack(context, 'فشل الحفظ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _hexToColor(_primary),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('تخصيص الألوان',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check),
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('اللون الأساسي', Icons.color_lens),
                _colorGrid(
                  _primary,
                  (c) => setState(() => _primary = c),
                ),
                const SizedBox(height: 25),
                _sectionTitle('لون الشريط السفلي', Icons.navigation),
                _colorGrid(
                  _nav,
                  (c) => setState(() => _nav = c),
                ),
                const SizedBox(height: 25),
                // معاينة
                _sectionTitle('معاينة', Icons.preview),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _hexToColor(_primary),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('زر تجريبي',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _hexToColor(_nav),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceAround,
                          children: [
                            Icon(Icons.home, color: Colors.white),
                            Icon(Icons.menu_book, color: Colors.white70),
                            Icon(Icons.notifications, color: Colors.white70),
                            Icon(Icons.person, color: Colors.white70),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ الألوان',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hexToColor(_primary),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF555555)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  Widget _colorGrid(String current, Function(String) onSelect) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _colors.length,
      itemBuilder: (_, i) {
        final color = _colors[i];
        final selected = current == color;
        return GestureDetector(
          onTap: () => onSelect(color),
          child: Container(
            decoration: BoxDecoration(
              color: _hexToColor(color),
              borderRadius: BorderRadius.circular(14),
              border: selected
                  ? Border.all(color: Colors.white, width: 4)
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _hexToColor(color).withOpacity(0.5),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 28)
                : null,
          ),
        );
      },
    );
  }
}

// ============ Welcome Message Screen ============
class WelcomeMessageScreen extends StatefulWidget {
  const WelcomeMessageScreen({super.key});
  @override
  State<WelcomeMessageScreen> createState() => _WelcomeMessageScreenState();
}

class _WelcomeMessageScreenState extends State<WelcomeMessageScreen> {
  final _ctrl = TextEditingController();
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
          .from('app_settings')
          .select('welcome_message')
          .eq('id', 1)
          .single();
      if (!mounted) return;
      setState(() {
        _ctrl.text = data['welcome_message'] ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await supabase.from('app_settings').update({
        'welcome_message': _ctrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
      if (!mounted) return;
      showKitabiSnack(context, 'تم الحفظ');
      Navigator.pop(context);
    } catch (e) {
      showKitabiSnack(context, 'فشل الحفظ');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('رسالة الترحيب',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('اكتب رسالة تظهر للطلاب عند التسجيل:',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF555555))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'مرحباً بك في كتابي...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});
  @override
  State<AdvancedSettingsScreen> createState() =>
      _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  Map<String, dynamic> _settings = {};
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
          .from('app_settings')
          .select()
          .eq('id', 1)
          .single();
      if (!mounted) return;
      setState(() {
        _settings = Map<String, dynamic>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load settings error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF455A64),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('الإعدادات المتقدمة',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF455A64)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // قسم عام
                _sectionTitle('عام', Icons.settings),
                _card([
                  _item(
                    icon: Icons.school,
                    color: const Color(0xFF1565C0),
                    title: 'المراقبات',
                    subtitle:
                        '${(_settings['muraqabat'] as List?)?.length ?? 0} مراقبة',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ManageMuraqabatScreen(),
                        ),
                      );
                      _load();
                    },
                  ),
                  _divider(),
                  _item(
                    icon: Icons.chat_bubble_outline,
                    color: const Color(0xFF00897B),
                    title: 'رسالة الترحيب',
                    subtitle: _settings['welcome_message'] ?? '',
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const WelcomeMessageScreen(),
                        ),
                      );
                      _load();
                    },
                  ),
                  _divider(),
                  _item(
                    icon: Icons.apps,
                    color: const Color(0xFF7B1FA2),
                    title: 'اسم التطبيق',
                    subtitle: _settings['app_name'] ?? 'Kitabi',
                    onTap: () => showKitabiSnack(
                        context, 'قريباً — تعديل اسم التطبيق'),
                  ),
                ]),

                // قسم الأمان
                _sectionTitle('الأمان', Icons.security),
                _card([
                  _item(
                    icon: Icons.lock_reset,
                    color: const Color(0xFFEF6C00),
                    title: 'تغيير كلمة سر الغرفة',
                    subtitle: 'تحديث كلمة سر الدخول',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const ChangePasswordScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  _item(
                    icon: Icons.campaign,
                    color: const Color(0xFF7B1FA2),
                    title: 'إشعار جماعي سريع',
                    subtitle: 'إرسال إشعار بقوالب جاهزة',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const QuickBroadcastScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                // قسم التخصيص
                _sectionTitle('التخصيص', Icons.color_lens),
                _card([
                  _item(
                    icon: Icons.palette,
                    color: const Color(0xFF7B1FA2),
                    title: 'الألوان',
                    subtitle:
                        'تخصيص ألوان التطبيق (${_settings['primary_color'] ?? ''})',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ColorSettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  _item(
                    icon: Icons.notifications_active,
                    color: const Color(0xFFFFA000),
                    title: 'إعدادات الإشعارات',
                    subtitle: (_settings['notifications_enabled'] == true)
                        ? 'مفعّلة'
                        : 'معطّلة',
                    onTap: () => showKitabiSnack(
                        context, 'قريباً — إعدادات الإشعارات'),
                  ),
                ]),

                // قسم التحليلات
                _sectionTitle('التحليلات', Icons.analytics),
                _card([
                  _item(
                    icon: Icons.bar_chart,
                    color: const Color(0xFF283593),
                    title: 'إحصائيات شاملة',
                    subtitle: 'تحليل بيانات التطبيق',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StatisticsScreen(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  _item(
                    icon: Icons.download,
                    color: const Color(0xFF00897B),
                    title: 'تصدير البيانات (CSV)',
                    subtitle: 'تحميل كل البيانات كملفات CSV',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExportCSVScreen(),
                        ),
                      );
                    },
                  ),
                ]),

                // قسم الصيانة
                _sectionTitle('الصيانة', Icons.build),
                _card([
                  _item(
                    icon: Icons.backup,
                    color: const Color(0xFF1565C0),
                    title: 'نسخة احتياطية',
                    subtitle: 'إنشاء نسخة من البيانات',
                    onTap: () => showKitabiSnack(
                        context, 'قريباً — نسخ احتياطي'),
                  ),
                  _divider(),
                  _item(
                    icon: Icons.build_circle,
                    color: (_settings['maintenance_mode'] == true)
                        ? Colors.red
                        : const Color(0xFF555555),
                    title: 'وضع الصيانة',
                    subtitle: (_settings['maintenance_mode'] == true)
                        ? 'مفعّل — التطبيق متوقف'
                        : 'معطّل',
                    onTap: () => _toggleMaintenance(),
                  ),
                ]),

                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Future<void> _toggleMaintenance() async {
    final current = _settings['maintenance_mode'] == true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text(current ? 'إلغاء وضع الصيانة' : 'تفعيل وضع الصيانة'),
        content: Text(current
            ? 'سيتمكن الطلاب من استخدام التطبيق.'
            : 'سيتم إيقاف استخدام التطبيق مؤقتاً للطلاب.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: current ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(current ? 'إلغاء' : 'تفعيل'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await supabase.from('app_settings').update({
        'maintenance_mode': !current,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
      if (!mounted) return;
      showKitabiSnack(context,
          !current ? 'تم تفعيل وضع الصيانة' : 'تم إلغاء وضع الصيانة');
      _load();
    } catch (e) {
      showKitabiSnack(context, 'فشل');
    }
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10, right: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF455A64)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF455A64))),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _item({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
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
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1A1A1A))),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.arrow_back_ios,
          size: 14, color: Color(0xFF555555)),
    );
  }

  Widget _divider() => const Divider(
      height: 1, indent: 70, endIndent: 15, color: Color(0xFFF0F0F0));
}

// ============ Manage Muraqabat Screen ============
class ManageMuraqabatScreen extends StatefulWidget {
  const ManageMuraqabatScreen({super.key});
  @override
  State<ManageMuraqabatScreen> createState() =>
      _ManageMuraqabatScreenState();
}

class _ManageMuraqabatScreenState extends State<ManageMuraqabatScreen> {
  List<String> _muraqabat = [];
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
          .from('app_settings')
          .select('muraqabat')
          .eq('id', 1)
          .single();
      final list = (data['muraqabat'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _muraqabat = list.map((e) => e.toString()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    try {
      await supabase.from('app_settings').update({
        'muraqabat': _muraqabat,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  Future<void> _add() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة مراقبة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'اسم المراقبة',
            hintText: 'مثال: مراقبة طرابلس',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF455A64),
                foregroundColor: Colors.white),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _muraqabat.add(result));
      await _save();
      if (!mounted) return;
      showKitabiSnack(context, 'تمت الإضافة');
    }
  }

  Future<void> _edit(int index) async {
    final ctrl = TextEditingController(text: _muraqabat[index]);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل المراقبة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'اسم المراقبة',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _muraqabat[index] = result);
      await _save();
      if (!mounted) return;
      showKitabiSnack(context, 'تم التعديل');
    }
  }

  Future<void> _delete(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف المراقبة'),
        content: Text('هل تريد حذف "${_muraqabat[index]}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _muraqabat.removeAt(index));
      await _save();
      if (!mounted) return;
      showKitabiSnack(context, 'تم الحذف');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('المراقبات (${_muraqabat.length})',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add_circle),
            tooltip: 'إضافة',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : _muraqabat.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off,
                          size: 80, color: Color(0xFF888888)),
                      SizedBox(height: 15),
                      Text('لا توجد مراقبات',
                          style: TextStyle(
                              fontSize: 16, color: Color(0xFF555555))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _muraqabat.length,
                  itemBuilder: (_, i) => _card(_muraqabat[i], i),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: const Color(0xFF1565C0),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة مراقبة',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _card(String name, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_city,
                color: Color(0xFF1565C0), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A))),
          ),
          IconButton(
            onPressed: () => _edit(index),
            icon: const Icon(Icons.edit,
                color: Color(0xFF1565C0), size: 20),
          ),
          IconButton(
            onPressed: () => _delete(index),
            icon: const Icon(Icons.delete,
                color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }
}

// ============ Notes Screen ============
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  String _search = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name') ?? '';
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('notes')
          .select()
          .eq('user_name', _userName)
          .order('is_pinned', ascending: false)
          .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _notes = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load notes error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الملاحظة'),
        content: Text('هل تريد حذف "${note['title'] ?? 'بدون عنوان'}"؟'),
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await supabase.from('notes').delete().eq('id', note['id']);
      if (!mounted) return;
      showKitabiSnack(context, 'تم الحذف');
      _load();
    } catch (e) {
      showKitabiSnack(context, 'فشل الحذف');
    }
  }

  Future<void> _togglePin(Map<String, dynamic> note) async {
    try {
      await supabase.from('notes').update({
        'is_pinned': !(note['is_pinned'] == true),
      }).eq('id', note['id']);
      _load();
    } catch (e) {
      debugPrint('Pin error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _search.isEmpty
        ? _notes
        : _notes.where((n) {
            final t = (n['title'] ?? '').toString();
            final c = (n['content'] ?? '').toString();
            return t.contains(_search) || c.contains(_search);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00838F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.sticky_note_2),
            SizedBox(width: 10),
            Text('ملاحظاتي',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          // البحث
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'ابحث في ملاحظاتك...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF00838F)))
                : filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(0xFF00838F),
                        child: GridView.builder(
                          padding: EdgeInsets.fromLTRB(12, 0, 12,
                              MediaQuery.of(context).padding.bottom + 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              _noteCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateNoteScreen(userName: _userName),
            ),
          );
          if (result == true) _load();
        },
        backgroundColor: const Color(0xFF00838F),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('ملاحظة جديدة',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _noteCard(Map<String, dynamic> note) {
    final color = _colorFromHex(note['color'] ?? '#FFFFFF');
    final isPinned = note['is_pinned'] == true;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPinned
              ? const Color(0xFFFFA000)
              : Colors.black.withOpacity(0.05),
          width: isPinned ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateNoteScreen(
                  userName: _userName,
                  existingNote: note,
                ),
              ),
            );
            if (result == true) _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note['title'] ?? 'بدون عنوان',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _togglePin(note),
                      child: Icon(
                        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 18,
                        color: isPinned
                            ? const Color(0xFFFFA000)
                            : const Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    note['content'] ?? '',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF555555),
                        height: 1.4),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if ((note['subject'] ?? '').toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          note['subject'],
                          style: const TextStyle(
                              fontSize: 9,
                              color: Color(0xFF555555),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _deleteNote(note),
                      child: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFromHex(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFFFFFFFF);
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF00838F).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sticky_note_2_outlined,
                size: 60, color: Color(0xFF00838F)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد ملاحظات بعد',
              style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
          const SizedBox(height: 10),
          const Text('اضغط + لإضافة ملاحظة جديدة',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ============ Create/Edit Note Screen ============
class CreateNoteScreen extends StatefulWidget {
  final String userName;
  final Map<String, dynamic>? existingNote;

  const CreateNoteScreen({
    super.key,
    required this.userName,
    this.existingNote,
  });

  @override
  State<CreateNoteScreen> createState() => _CreateNoteScreenState();
}

class _CreateNoteScreenState extends State<CreateNoteScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _color = '#FFFFFF';
  String? _subject;
  bool _isPinned = false;
  bool _saving = false;

  final List<String> _colors = [
    '#FFFFFF', '#FFF9C4', '#C8E6C9', '#BBDEFB',
    '#F8BBD0', '#FFE0B2', '#D1C4E9', '#B2DFDB',
  ];

  final List<String> _subjects = [
    'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
    'التربية الإسلامية', 'العلوم', 'الفيزياء',
    'الكيمياء', 'الأحياء', 'التاريخ', 'الجغرافيا',
    'الحاسوب', 'أخرى',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      _titleCtrl.text = widget.existingNote!['title'] ?? '';
      _contentCtrl.text = widget.existingNote!['content'] ?? '';
      _color = widget.existingNote!['color'] ?? '#FFFFFF';
      _subject = widget.existingNote!['subject'];
      _isPinned = widget.existingNote!['is_pinned'] == true;
    }
  }

  Future<void> _save() async {
    if (_contentCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب محتوى الملاحظة');
      return;
    }

    setState(() => _saving = true);
    try {
      final data = {
        'user_name': widget.userName,
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'color': _color,
        'subject': _subject,
        'is_pinned': _isPinned,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.existingNote != null) {
        await supabase
            .from('notes')
            .update(data)
            .eq('id', widget.existingNote!['id']);
      } else {
        await supabase.from('notes').insert(data);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save note error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showKitabiSnack(context, 'فشل الحفظ');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _hexToColor(_color),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00838F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.existingNote == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isPinned = !_isPinned),
            icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: 'تثبيت',
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('حفظ',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'العنوان (اختياري)',
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            // المحتوى
            TextField(
              controller: _contentCtrl,
              maxLines: 15,
              style: const TextStyle(fontSize: 15, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'اكتب ملاحظتك هنا...',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),
            // المادة
            const Text('المادة:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF555555))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _subjects.map((s) {
                final selected = _subject == s;
                return GestureDetector(
                  onTap: () => setState(() => _subject = selected ? null : s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF00838F)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF00838F).withOpacity(0.3)),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            fontSize: 11,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF00838F),
                            fontWeight: FontWeight.bold)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // الألوان
            const Text('اللون:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF555555))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _colors.map((c) {
                final selected = _color == c;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _hexToColor(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF00838F)
                            : Colors.black.withOpacity(0.1),
                        width: selected ? 3 : 1,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check,
                            size: 20, color: Color(0xFF00838F))
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Create Course Screen ============
class CreateCourseScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const CreateCourseScreen({
    super.key,
    required this.userName,
    required this.userRole,
  });

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _coverCtrl = TextEditingController();
  String? _selectedGrade;
  String? _selectedSubject;
  bool _isFree = true;
  bool _saving = false;

  final List<String> _grades = [
    'الكل', 'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
    'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
    'أول إعدادي', 'ثاني إعدادي', 'ثالث إعدادي',
    'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي',
  ];

  final List<String> _subjects = [
    'الكل', 'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
    'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الفيزياء',
    'الكيمياء', 'الأحياء', 'التاريخ', 'الجغرافيا',
    'الفلسفة', 'علم الاجتماع',
  ];

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب عنوان الدورة');
      return;
    }

    setState(() => _saving = true);
    try {
      await supabase.from('courses').insert({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'cover_url': _coverCtrl.text.trim().isEmpty
            ? null
            : _coverCtrl.text.trim(),
        'instructor_name': widget.userName,
        'instructor_role': widget.userRole,
        'grade': _selectedGrade,
        'subject': _selectedSubject,
        'is_free': _isFree,
        'is_published': true,
        'lessons_count': 0,
        'students_count': 0,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save course error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showKitabiSnack(context, 'فشل الحفظ');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _coverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('دورة جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('حفظ',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'عنوان الدورة',
                hintText: 'مثال: أساسيات الرياضيات',
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // الوصف
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'وصف الدورة',
                hintText: 'اشرح ما سيتعلمه الطالب...',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // غلاف
            TextField(
              controller: _coverCtrl,
              decoration: InputDecoration(
                labelText: 'رابط صورة الغلاف (اختياري)',
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.image),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // الصف
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              decoration: InputDecoration(
                labelText: 'الصف',
                prefixIcon: const Icon(Icons.school),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedGrade = v),
            ),
            const SizedBox(height: 12),
            // المادة
            DropdownButtonFormField<String>(
              value: _selectedSubject,
              decoration: InputDecoration(
                labelText: 'المادة',
                prefixIcon: const Icon(Icons.book),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSubject = v),
            ),
            const SizedBox(height: 12),
            // مجاني / بلس
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('نوع الدورة:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _typeBtn('🆓 مجاني', true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _typeBtn('💎 مشتركي بلس', false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(String label, bool value) {
    final active = _isFree == value;
    return GestureDetector(
      onTap: () => setState(() => _isFree = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                fontSize: 13)),
      ),
    );
  }
}

// ============ Create Lesson Screen ============
class CreateLessonScreen extends StatefulWidget {
  final String courseId;
  final int nextOrder;

  const CreateLessonScreen({
    super.key,
    required this.courseId,
    required this.nextOrder,
  });

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _videoCtrl = TextEditingController();
  int _duration = 0;
  bool _saving = false;

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب عنوان الدرس');
      return;
    }
    if (_videoCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب رابط الفيديو');
      return;
    }

    setState(() => _saving = true);
    try {
      await supabase.from('lessons').insert({
        'course_id': widget.courseId,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'video_url': _videoCtrl.text.trim(),
        'duration_min': _duration,
        'display_order': widget.nextOrder,
      });

      // نحدّث عدد الدروس في الدورة
      final courseData = await supabase
          .from('courses')
          .select('lessons_count')
          .eq('id', widget.courseId)
          .single();
      final current = courseData['lessons_count'] ?? 0;
      await supabase.from('courses').update({
        'lessons_count': (current as int) + 1,
      }).eq('id', widget.courseId);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save lesson error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showKitabiSnack(context, 'فشل الحفظ');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('إضافة درس ${widget.nextOrder}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('حفظ',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'عنوان الدرس',
                hintText: 'مثال: مقدمة في الكسور',
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'وصف الدرس (اختياري)',
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _videoCtrl,
              decoration: InputDecoration(
                labelText: 'رابط الفيديو (YouTube)',
                hintText: 'https://youtube.com/watch?v=...',
                prefixIcon: const Icon(Icons.video_library),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المدة (بالدقائق):',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 15, 20, 30, 45, 60].map((m) {
                      final selected = _duration == m;
                      return GestureDetector(
                        onTap: () => setState(() => _duration = m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF00897B)
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$m د',
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF555555),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Color(0xFF00897B), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'يمكنك استخدام روابط YouTube أو روابط mp4 مباشرة',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF555555)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Courses Screen ============
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});
  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;
  String _userRole = 'student';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name') ?? '';
    try {
      final data = await supabase
          .from('users')
          .select('role')
          .eq('name', _userName)
          .limit(1);
      if (data.isNotEmpty) {
        _userRole = (data[0]['role'] ?? 'student').toString();
      }
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('courses')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _courses = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load courses error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get _canCreate {
    return _userRole == 'admin' ||
        _userRole == 'moderator' ||
        _userRole == 'teacher';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.school),
            SizedBox(width: 10),
            Text('الدورات التعليمية',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : _courses.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF00897B),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 16, 16,
                        MediaQuery.of(context).padding.bottom + 100),
                    itemCount: _courses.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 14),
                    itemBuilder: (_, i) => _courseCard(_courses[i]),
                  ),
                ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateCourseScreen(
                      userName: _userName,
                      userRole: _userRole,
                    ),
                  ),
                );
                if (result == true) _load();
              },
              backgroundColor: const Color(0xFF00897B),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('دورة جديدة',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _courseCard(Map<String, dynamic> course) {
    final isFree = course['is_free'] == true;
    final coverUrl = course['cover_url'];

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
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CourseDetailScreen(
                  course: course,
                  userName: _userName,
                  userRole: _userRole,
                ),
              ),
            );
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // صورة الغلاف
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: coverUrl != null && coverUrl.toString().isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.school,
                              color: Colors.white,
                              size: 40),
                        )
                      : const Icon(Icons.school,
                          color: Colors.white, size: 40),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course['instructor_name'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFree
                                  ? const Color(0xFF2E7D32)
                                      .withOpacity(0.15)
                                  : const Color(0xFFFFA000)
                                      .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isFree ? '🆓 مجاني' : '💎 بلس',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isFree
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFFFA000),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '📚 ${course['lessons_count'] ?? 0} درس',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 14, color: Color(0xFF00897B)),
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
              color: const Color(0xFF00897B).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_outlined,
                size: 60, color: Color(0xFF00897B)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد دورات بعد',
              style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
          if (_canCreate) ...[
            const SizedBox(height: 10),
            const Text('اضغط + لإضافة أول دورة',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
          ],
        ],
      ),
    );
  }
}

// ============ Course Detail Screen ============
class CourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  final String userName;
  final String userRole;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.userName,
    required this.userRole,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<Map<String, dynamic>> _lessons = [];
  bool _loading = true;
  bool _enrolled = false;
  int _progress = 0;
  List<String> _completedLessons = [];

  bool get _canEdit {
    return widget.userRole == 'admin' ||
        widget.userRole == 'moderator' ||
        widget.userRole == 'teacher';
  }

  @override
  void initState() {
    super.initState();
    _load();
    _checkEnrollment();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('lessons')
          .select()
          .eq('course_id', widget.course['id'])
          .order('display_order', ascending: true);
      if (!mounted) return;
      setState(() {
        _lessons = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _checkEnrollment() async {
    try {
      final data = await supabase
          .from('course_enrollments')
          .select()
          .eq('course_id', widget.course['id'])
          .eq('user_name', widget.userName)
          .limit(1);
      if (!mounted) return;
      if (data.isNotEmpty) {
        setState(() {
          _enrolled = true;
          _progress = (data[0]['progress'] ?? 0) as int;
          _completedLessons =
              List<String>.from(data[0]['completed_lessons'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Check enrollment error: $e');
    }
  }

  Future<void> _enroll() async {
    try {
      await supabase.from('course_enrollments').insert({
        'course_id': widget.course['id'],
        'user_name': widget.userName,
        'progress': 0,
        'completed_lessons': [],
      });
      // نزيد students_count
      final current = widget.course['students_count'] ?? 0;
      await supabase.from('courses').update({
        'students_count': (current as int) + 1,
      }).eq('id', widget.course['id']);
      if (!mounted) return;
      setState(() => _enrolled = true);
      showKitabiSnack(context, 'تم التسجيل في الدورة ✅');
    } catch (e) {
      showKitabiSnack(context, 'فشل التسجيل');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.course['title'] ?? 'الدورة',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, MediaQuery.of(context).padding.bottom + 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // رأس الدورة
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00897B).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.course['title'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'المعلم: ${widget.course['instructor_name'] ?? ''}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        if ((widget.course['description'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.course['description'],
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5),
                          ),
                        ],
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '📚 ${_lessons.length} درس',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '👥 ${widget.course['students_count'] ?? 0} طالب',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // شريط التقدم (إذا مشترك)
                  if (_enrolled) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.trending_up,
                                  color: Color(0xFF00897B), size: 20),
                              const SizedBox(width: 8),
                              const Text('تقدمك:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const Spacer(),
                              Text('$_progress%',
                                  style: const TextStyle(
                                      color: Color(0xFF00897B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progress / 100,
                              minHeight: 10,
                              backgroundColor:
                                  const Color(0xFFE0E0E0),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF00897B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // عنوان الدروس
                  Row(
                    children: [
                      const Icon(Icons.play_lesson,
                          color: Color(0xFF00897B), size: 22),
                      const SizedBox(width: 8),
                      Text('الدروس (${_lessons.length})',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // قائمة الدروس
                  if (_lessons.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 60, color: Color(0xFF888888)),
                          SizedBox(height: 10),
                          Text('لا توجد دروس بعد',
                              style: TextStyle(
                                  color: Color(0xFF888888),
                                  fontSize: 14)),
                        ],
                      ),
                    )
                  else
                    ..._lessons.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final lesson = entry.value;
                      final isCompleted =
                          _completedLessons.contains(lesson['id']);
                      return _lessonCard(lesson, idx, isCompleted);
                    }),

                  const SizedBox(height: 20),

                  // زر التسجيل
                  if (!_enrolled)
                    SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: _enroll,
                        icon: const Icon(Icons.school),
                        label: const Text('سجل في الدورة',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                  // زر إضافة درس
                  if (_canEdit) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateLessonScreen(
                                courseId: widget.course['id'],
                                nextOrder: _lessons.length + 1,
                              ),
                            ),
                          );
                          if (result == true) _load();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة درس'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00897B),
                          side: const BorderSide(
                              color: Color(0xFF00897B), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _lessonCard(
      Map<String, dynamic> lesson, int idx, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isCompleted
            ? Border.all(color: const Color(0xFF2E7D32), width: 1.5)
            : null,
      ),
      child: ListTile(
        onTap: () {
          if (lesson['video_url'] != null &&
              lesson['video_url'].toString().isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(
                  video: {
                    'title': lesson['title'],
                    'video_url': lesson['video_url'],
                    'video_type': 'youtube',
                  },
                ),
              ),
            );
          } else {
            showKitabiSnack(context, 'لا يوجد فيديو لهذا الدرس');
          }
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF2E7D32)
                : const Color(0xFF00897B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : Text('${idx + 1}',
                    style: const TextStyle(
                        color: Color(0xFF00897B),
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ),
        title: Text(lesson['title'] ?? '',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: (lesson['description'] ?? '').toString().isNotEmpty
            ? Text(lesson['description'],
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_enrolled)
              IconButton(
                onPressed: () => _toggleComplete(lesson),
                icon: Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCompleted
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF888888),
                  size: 24,
                ),
              ),
            const Icon(Icons.arrow_back_ios,
                size: 14, color: Color(0xFF888888)),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleComplete(Map<String, dynamic> lesson) async {
    try {
      final lessonId = lesson['id'].toString();
      final newCompleted = List<String>.from(_completedLessons);
      if (newCompleted.contains(lessonId)) {
        newCompleted.remove(lessonId);
      } else {
        newCompleted.add(lessonId);
      }
      final newProgress = _lessons.isEmpty
          ? 0
          : ((newCompleted.length / _lessons.length) * 100).round();

      await supabase.from('course_enrollments').update({
        'completed_lessons': newCompleted,
        'progress': newProgress,
      }).eq('course_id', widget.course['id']).eq('user_name', widget.userName);

      if (!mounted) return;
      setState(() {
        _completedLessons = newCompleted;
        _progress = newProgress;
      });
    } catch (e) {
      debugPrint('Toggle complete error: $e');
    }
  }
}

// ============ Personal Info Screen ============
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});
  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _nameCtrl = TextEditingController();
  String _grade = '';
  String _muraqaba = '';
  String _email = '';
  String _role = 'student';
  int _points = 0;
  int _level = 1;
  bool _loading = true;
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? '';
      final stats = await UserStats.get();
      if (name.isNotEmpty) {
        final data = await supabase
            .from('users')
            .select()
            .eq('name', name)
            .limit(1);
        if (data.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _nameCtrl.text = data[0]['name'] ?? '';
            _grade = data[0]['grade'] ?? '';
            _muraqaba = data[0]['muraqaba'] ?? '';
            _email = data[0]['email'] ?? '';
            _role = data[0]['role'] ?? 'student';
            _points = stats['points'] ?? 0;
            _level = stats['level'] ?? 1;
          });
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      debugPrint('Load personal info error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب اسمك');
      return;
    }
    if (_grade.isEmpty) {
      showKitabiSnack(context, 'اختر صفك');
      return;
    }
    if (_muraqaba.isEmpty) {
      showKitabiSnack(context, 'اختر مراقبتك');
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldName = prefs.getString('user_name') ?? '';

      // نحدث في users
      await supabase.from('users').update({
        'name': _nameCtrl.text.trim(),
        'grade': _grade,
        'muraqaba': _muraqaba,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('name', oldName);

      // نحدث في prefs
      await prefs.setString('user_name', _nameCtrl.text.trim());
      await prefs.setString('user_grade', _grade);
      await prefs.setString('user_muraqaba', _muraqaba);

      if (!mounted) return;
      showKitabiSnack(context, 'تم الحفظ ✅');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Save error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showKitabiSnack(context, 'فشل الحفظ');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('معلوماتي الشخصية',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('حفظ',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الأفاتار
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1565C0),
                                Color(0xFF42A5F5)
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1565C0)
                                    .withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _nameCtrl.text.isEmpty
                                  ? '؟'
                                  : _nameCtrl.text[0],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: RoleHelper.roleColor(_role)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            RoleHelper.roleLabel(_role),
                            style: TextStyle(
                                color: RoleHelper.roleColor(_role),
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),

                  // الاسم
                  TextField(
                    controller: _nameCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'الاسم',
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // الصف
                  DropdownButtonFormField<String>(
                    value: _grade.isEmpty ? null : _grade,
                    decoration: InputDecoration(
                      labelText: 'الصف',
                      prefixIcon: const Icon(Icons.school),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _grades
                        .map((g) => DropdownMenuItem(
                            value: g, child: Text(g)))
                        .toList(),
                    onChanged: (v) => setState(() => _grade = v ?? ''),
                  ),
                  const SizedBox(height: 14),

                  // المراقبة
                  DropdownButtonFormField<String>(
                    value: _muraqaba.isEmpty ? null : _muraqaba,
                    decoration: InputDecoration(
                      labelText: 'المراقبة',
                      prefixIcon: const Icon(Icons.location_city),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _muraqabat
                        .map((m) => DropdownMenuItem(
                            value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _muraqaba = v ?? ''),
                  ),
                  const SizedBox(height: 14),

                  // الإيميل (لو موجود)
                  if (_email.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email,
                              color: Color(0xFF555555), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('البريد الإلكتروني',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF888888))),
                                Text(_email,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    textDirection: TextDirection.ltr),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // الإحصائيات
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _statItem(
                              Icons.local_fire_department,
                              'النقاط',
                              '$_points',
                              const Color(0xFFFF6B35)),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE5E5E5),
                        ),
                        Expanded(
                          child: _statItem(
                              Icons.star,
                              'المستوى',
                              '$_level',
                              const Color(0xFFFFB300)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statItem(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF555555))),
      ],
    );
  }
}

// ============ Goals Screen ============
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final List<Map<String, dynamic>> _goals = [
    {
      'id': '1',
      'title': 'قراءة 5 كتب',
      'desc': 'اقرأ 5 كتب هذا الشهر',
      'icon': Icons.menu_book,
      'color': 0xFF1565C0,
      'target': 5,
      'unit': 'كتاب',
    },
    {
      'id': '2',
      'title': 'حل 20 اختبار',
      'desc': 'جرب 20 اختبار تدريبي',
      'icon': Icons.assignment,
      'color': 0xFFD32F2F,
      'target': 20,
      'unit': 'اختبار',
    },
    {
      'id': '3',
      'title': 'مشاهدة 10 فيديوهات',
      'desc': 'شاهد 10 فيديوهات تعليمية',
      'icon': Icons.play_circle,
      'color': 0xFFEF6C00,
      'target': 10,
      'unit': 'فيديو',
    },
    {
      'id': '4',
      'title': 'مشاركة في المنتدى',
      'desc': 'شارك بمنشور واحد على الأقل',
      'icon': Icons.forum,
      'color': 0xFF7B1FA2,
      'target': 1,
      'unit': 'منشور',
    },
    {
      'id': '5',
      'title': 'إنشاء 5 ملاحظات',
      'desc': 'اكتب 5 ملاحظات دراسية',
      'icon': Icons.sticky_note_2,
      'color': 0xFF00838F,
      'target': 5,
      'unit': 'ملاحظة',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF66BB6A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('أهدافي التعليمية',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // رسالة تشجيعية
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF66BB6A), Color(0xFF81C784)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF66BB6A).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.emoji_events,
                    color: Colors.white, size: 50),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('أهدافك لهذا الشهر',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      SizedBox(height: 5),
                      Text('أكمل أهدافك واكسب نقاطاً إضافية',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // قائمة الأهداف
          ..._goals.map((goal) => _goalCard(goal)),

          const SizedBox(height: 20),
          // إضافة هدف مخصص
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => showKitabiSnack(
                  context, 'قريباً: إضافة أهداف مخصصة'),
              icon: const Icon(Icons.add),
              label: const Text('إضافة هدف مخصص'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF66BB6A),
                side: const BorderSide(
                    color: Color(0xFF66BB6A), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(Map<String, dynamic> goal) {
    final color = Color(goal['color']);
    final progress = 0; // يمكن ربطه بـ DB لاحقاً
    final target = goal['target'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(goal['icon'], color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal['title'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1A1A1A))),
                    Text(goal['desc'],
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF555555))),
                  ],
                ),
              ),
              Text('$progress/$target',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress / target,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ Create Quiz Screen ============
class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});
  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}





class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _titleCtrl = TextEditingController();
  String? _selectedGrade;
  String? _selectedSubject;
  int _duration = 30;
  final List<Map<String, dynamic>> _questions = [];
  bool _saving = false;

  final List<String> _grades = [
    'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
    'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
    'أول إعدادي', 'ثاني إعدادي', 'ثالث إعدادي',
    'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي',
  ];

  final List<String> _subjects = [
    'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
    'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الفيزياء',
    'الكيمياء', 'الأحياء', 'التاريخ', 'الجغرافيا',
  ];

  Future<void> _addQuestion() async {
    final qCtrl = TextEditingController();
    final a1 = TextEditingController();
    final a2 = TextEditingController();
    final a3 = TextEditingController();
    final a4 = TextEditingController();
    final explCtrl = TextEditingController();
    int correct = 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.help_outline,
                  color: Color(0xFF1565C0)),
              const SizedBox(width: 10),
              Text('سؤال ${_questions.length + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: qCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'نص السؤال',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: a1,
                    decoration: InputDecoration(
                      labelText: 'الخيار أ',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: a2,
                    decoration: InputDecoration(
                      labelText: 'الخيار ب',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: a3,
                    decoration: InputDecoration(
                      labelText: 'الخيار ج',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: a4,
                    decoration: InputDecoration(
                      labelText: 'الخيار د',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text('الإجابة الصحيحة:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _answerRadio('أ', 0, correct,
                          (v) => setSt(() => correct = v)),
                      _answerRadio('ب', 1, correct,
                          (v) => setSt(() => correct = v)),
                      _answerRadio('ج', 2, correct,
                          (v) => setSt(() => correct = v)),
                      _answerRadio('د', 3, correct,
                          (v) => setSt(() => correct = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: explCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'شرح الإجابة (اختياري)',
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
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (qCtrl.text.trim().isEmpty ||
                    a1.text.trim().isEmpty ||
                    a2.text.trim().isEmpty) {
                  showKitabiSnack(context, 'املأ السؤال + خيارين على الأقل');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _questions.add({
          'q': qCtrl.text.trim(),
          'options': [
            a1.text.trim(),
            a2.text.trim(),
            a3.text.trim().isEmpty ? '-' : a3.text.trim(),
            a4.text.trim().isEmpty ? '-' : a4.text.trim(),
          ],
          'correct': correct,
          'explanation': explCtrl.text.trim(),
        });
      });
      if (!mounted) return;
      showKitabiSnack(context, 'تم إضافة السؤال');
    }
  }

  Widget _answerRadio(String label, int value, int current,
      Function(int) onSelect) {
    final selected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2E7D32)
                : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: selected
                        ? Colors.white
                        : const Color(0xFF555555),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showKitabiSnack(context, 'اكتب عنوان الاختبار');
      return;
    }
    if (_selectedGrade == null) {
      showKitabiSnack(context, 'اختر الصف');
      return;
    }
    if (_selectedSubject == null) {
      showKitabiSnack(context, 'اختر المادة');
      return;
    }
    if (_questions.isEmpty) {
      showKitabiSnack(context, 'أضف سؤال واحد على الأقل');
      return;
    }

    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? 'admin';

      await supabase.from('quizzes').insert({
        'title': _titleCtrl.text.trim(),
        'subject': _selectedSubject,
        'grade': _selectedGrade,
        'questions': _questions,
        'duration_min': _duration,
        'total_marks': _questions.length * 10,
        'created_by': name,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Save quiz error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showKitabiSnack(context, 'فشل الحفظ');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('اختبار جديد',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('حفظ',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'عنوان الاختبار',
                prefixIcon: const Icon(Icons.title),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              decoration: InputDecoration(
                labelText: 'الصف',
                prefixIcon: const Icon(Icons.school),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedGrade = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedSubject,
              decoration: InputDecoration(
                labelText: 'المادة',
                prefixIcon: const Icon(Icons.book),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSubject = v),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المدة (بالدقائق):',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 30, 45, 60, 90].map((m) {
                      final selected = _duration == m;
                      return GestureDetector(
                        onTap: () => setState(() => _duration = m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFD32F2F)
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$m د',
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF555555),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // قائمة الأسئلة
            Row(
              children: [
                const Icon(Icons.quiz,
                    color: Color(0xFFD32F2F), size: 22),
                const SizedBox(width: 8),
                Text('الأسئلة (${_questions.length})',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ],
            ),
            const SizedBox(height: 12),
            if (_questions.isEmpty)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.help_outline,
                        size: 50, color: Color(0xFF888888)),
                    SizedBox(height: 10),
                    Text('لا توجد أسئلة بعد',
                        style: TextStyle(
                            color: Color(0xFF888888), fontSize: 14)),
                    SizedBox(height: 5),
                    Text('اضغط + لإضافة أول سؤال',
                        style: TextStyle(
                            color: Color(0xFFD32F2F),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              ..._questions.asMap().entries.map((entry) {
                final idx = entry.key;
                final q = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text('${idx + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(q['q'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _questions.removeAt(idx)),
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(4, (i) {
                          final isCorrect = q['correct'] == i;
                          final label = ['أ', 'ب', 'ج', 'د'][i];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? const Color(0xFF2E7D32)
                                      .withOpacity(0.15)
                                  : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$label: ${(q['options'] as List)[i]}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isCorrect
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF555555),
                                  fontWeight: isCorrect
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 20),
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text('إضافة سؤال',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Quizzes Screen (للطلاب) ============
class QuizzesScreen extends StatefulWidget {
  const QuizzesScreen({super.key});
  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen> {
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;
  String _userName = '';
  String _userGrade = '';
  List<Map<String, dynamic>> _myResults = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('user_name') ?? '';
    _userGrade = prefs.getString('user_grade') ?? '';
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // نجيب اختبارات صف الطالب
      final data = await supabase
          .from('quizzes')
          .select()
          .eq('grade', _userGrade)
          .order('created_at', ascending: false);

      // نجيب نتائج الطالب
      List<Map<String, dynamic>> results = [];
      try {
        final r = await supabase
            .from('quiz_results')
            .select()
            .eq('user_name', _userName);
        results = List<Map<String, dynamic>>.from(r);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _quizzes = List<Map<String, dynamic>>.from(data);
        _myResults = results;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load quizzes error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _getResult(String quizId) {
    for (var r in _myResults) {
      if (r['quiz_id'] == quizId) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEF6C00),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.assignment),
            SizedBox(width: 10),
            Text('الاختبارات',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFEF6C00)))
          : _quizzes.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFFEF6C00),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 16, 16,
                        MediaQuery.of(context).padding.bottom + 20),
                    itemCount: _quizzes.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 14),
                    itemBuilder: (_, i) => _quizCard(_quizzes[i]),
                  ),
                ),
    );
  }

  Widget _quizCard(Map<String, dynamic> quiz) {
    final questions = (quiz['questions'] as List?) ?? [];
    final result = _getResult(quiz['id'].toString());
    final hasTaken = result != null;

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
          onTap: hasTaken
              ? null
              : () async {
                  final r = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TakeQuizScreen(
                        quiz: quiz,
                        userName: _userName,
                      ),
                    ),
                  );
                  if (r == true) _load();
                },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF6C00), Color(0xFFFFA726)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.assignment,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(quiz['title'] ?? '',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(
                            '${quiz['subject']} • ${quiz['grade']}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF555555)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _chip(Icons.help_outline,
                        '${questions.length} سؤال', const Color(0xFF1565C0)),
                    const SizedBox(width: 6),
                    _chip(Icons.timer_outlined,
                        '${quiz['duration_min']} د', const Color(0xFF00897B)),
                    const SizedBox(width: 6),
                    _chip(Icons.stars,
                        '${quiz['total_marks']} نقطة', const Color(0xFFFFA000)),
                  ],
                ),
                const SizedBox(height: 12),
                if (hasTaken)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Color(0xFF2E7D32), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'النتيجة: ${result['score'] ?? 0}/${quiz['total_marks']}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Text('مكتمل',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF2E7D32))),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF6C00).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.play_arrow,
                            color: Color(0xFFEF6C00), size: 20),
                        SizedBox(width: 8),
                        Text('ابدأ الاختبار',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFEF6C00),
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold)),
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
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFEF6C00).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined,
                size: 60, color: Color(0xFFEF6C00)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد اختبارات لصفك بعد',
              style: TextStyle(fontSize: 16, color: Color(0xFF555555))),
          const SizedBox(height: 8),
          Text('صفك: $_userGrade',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ============ Take Quiz Screen ============
class TakeQuizScreen extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final String userName;

  const TakeQuizScreen({
    super.key,
    required this.quiz,
    required this.userName,
  });

  @override
  State<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends State<TakeQuizScreen> {
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswer;
  bool _showHint = false;
  bool _submitting = false;
  int _score = 0;
  List<int> _answers = [];
  late int _timeLeft;
  late int _perQuestionTime;

  @override
  void initState() {
    super.initState();
    _questions = List<Map<String, dynamic>>.from(
        widget.quiz['questions'] ?? []);
    _perQuestionTime = widget.quiz['per_question_time'] ?? 60;
    _timeLeft = _perQuestionTime;
    _startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
        _startTimer();
      } else {
        // انتهى الوقت → ننتقل للسؤال التالي
        _next();
      }
    });
  }

  void _next() {
    if (_selectedAnswer == null) {
      showKitabiSnack(context, 'اختر إجابة');
      return;
    }

    // نحسب النتيجة
    final q = _questions[_currentIndex];
    if (_selectedAnswer == q['correct']) {
      _score += (q['marks'] ?? 10) as int;
    }
    _answers.add(_selectedAnswer!);

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _showHint = false;
        _timeLeft = _perQuestionTime;
      });
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    try {
      await supabase.from('quiz_results').insert({
        'quiz_id': widget.quiz['id'],
        'user_id': null,
        'user_name': widget.userName,
        'score': _score,
        'answers': _answers,
      });
    } catch (e) {
      debugPrint('Save result error: $e');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizResultScreen(
          quiz: widget.quiz,
          questions: _questions,
          answers: _answers,
          score: _score,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFEF6C00),
          foregroundColor: Colors.white,
          title: const Text('اختبار'),
        ),
        body: const Center(child: Text('لا توجد أسئلة')),
      );
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEF6C00),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'سؤال ${_currentIndex + 1}/${_questions.length}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _timeLeft < 10 ? Colors.red : Colors.white24,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text('$_timeLeft ث',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شريط التقدم
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFEF6C00)),
              ),
            ),
            const SizedBox(height: 20),

            // صورة السؤال
            if (q['image'] != null &&
                q['image'].toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  q['image'],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),

            // السؤال
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(q['q'] ?? '',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.5)),
            ),
            const SizedBox(height: 20),

            // الخيارات
            ...List.generate(4, (i) {
              final options = q['options'] as List;
              final opt = options[i].toString();
              if (opt == '-') return const SizedBox.shrink();
              final selected = _selectedAnswer == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedAnswer = i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFEF6C00)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFEF6C00)
                          : Colors.grey.shade200,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFF0F0F0),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            ['أ', 'ب', 'ج', 'د'][i],
                            style: TextStyle(
                                color: selected
                                    ? const Color(0xFFEF6C00)
                                    : const Color(0xFF555555),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(opt,
                            style: TextStyle(
                                fontSize: 14,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // التلميح
            if (q['hint'] != null && q['hint'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              if (_showHint)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFA000).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFFFA000).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb,
                          color: Color(0xFFFFA000), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(q['hint'],
                            style: const TextStyle(
                                fontSize: 13, height: 1.5)),
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showHint = true),
                  icon: const Icon(Icons.lightbulb_outline,
                      color: Color(0xFFFFA000)),
                  label: const Text('إظهار التلميح',
                      style: TextStyle(color: Color(0xFFFFA000))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFFA000)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],

            const SizedBox(height: 25),

            // زر التالي
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _next,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(_currentIndex == _questions.length - 1
                        ? Icons.check
                        : Icons.arrow_forward),
                label: Text(
                  _currentIndex == _questions.length - 1
                      ? 'إنهاء الاختبار'
                      : 'السؤال التالي',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF6C00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ Quiz Result Screen ============
class QuizResultScreen extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final List<Map<String, dynamic>> questions;
  final List<int> answers;
  final int score;

  const QuizResultScreen({
    super.key,
    required this.quiz,
    required this.questions,
    required this.answers,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final total = quiz['total_marks'] ?? 100;
    final percent = total == 0 ? 0 : (score / total * 100).round();

    Color color;
    String message;
    IconData icon;

    if (percent >= 80) {
      color = const Color(0xFF2E7D32);
      message = 'ممتاز! 🎉';
      icon = Icons.emoji_events;
    } else if (percent >= 60) {
      color = const Color(0xFFFFA000);
      message = 'جيد! استمر';
      icon = Icons.thumb_up;
    } else if (percent >= 40) {
      color = const Color(0xFFEF6C00);
      message = 'يحتاج تحسين';
      icon = Icons.trending_up;
    } else {
      color = Colors.red;
      message = 'حاول مرة أخرى';
      icon = Icons.emoji_emotions;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('نتيجة الاختبار',
            style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقة النتيجة
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(icon, color: Colors.white, size: 60),
                  const SizedBox(height: 15),
                  Text(message,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '$score / $total',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$percent%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // التفاصيل
            const Text('المراجعة:',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 12),

            ...questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              final selected = idx < answers.length ? answers[idx] : -1;
              final correct = q['correct'] ?? 0;
              final isCorrect = selected == correct;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCorrect
                        ? const Color(0xFF2E7D32)
                        : Colors.red,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? const Color(0xFF2E7D32)
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCorrect ? Icons.check : Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('سؤال ${idx + 1}: ${q['q']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(4, (i) {
                      final options = q['options'] as List;
                      final opt = options[i].toString();
                      if (opt == '-') return const SizedBox.shrink();
                      final isAnswer = i == correct;
                      final isSelected = i == selected;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAnswer
                              ? const Color(0xFF2E7D32).withOpacity(0.15)
                              : isSelected
                                  ? Colors.red.withOpacity(0.1)
                                  : const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(['أ', 'ب', 'ج', 'د'][i] + ':',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isAnswer
                                        ? const Color(0xFF2E7D32)
                                        : isSelected
                                            ? Colors.red
                                            : const Color(0xFF555555))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(opt,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isAnswer
                                          ? const Color(0xFF2E7D32)
                                          : isSelected
                                              ? Colors.red
                                              : const Color(0xFF555555))),
                            ),
                            if (isAnswer)
                              const Icon(Icons.check,
                                  color: Color(0xFF2E7D32), size: 16),
                            if (isSelected && !isAnswer)
                              const Icon(Icons.close,
                                  color: Colors.red, size: 16),
                          ],
                        ),
                      );
                    }),
                    if (q['explanation'] != null &&
                        q['explanation'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Color(0xFF1565C0), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(q['explanation'],
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.arrow_back),
                label: const Text('العودة للاختبارات',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ControlRoomScreen extends StatefulWidget {
  final bool fromSplash;
  const ControlRoomScreen({super.key, this.fromSplash = false});
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
        automaticallyImplyLeading: false,
        actions: [
          if (_logged)
            IconButton(
              tooltip: 'التطبيق',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HomeShell()),
                );
              },
              icon: const Icon(Icons.apps),
            ),
          const SizedBox(width: 8),
        ],
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

  Future<void> _showPlusUsers() async {
    try {
      final now = DateTime.now().toIso8601String();
      final subsData = await supabase
          .from('subscriptions')
          .select()
          .eq('is_active', true)
          .gte('expires_at', now)
          .order('expires_at', ascending: false);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              Text('مشتركو Plus (${subsData.length})'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: subsData.isEmpty
                ? const Center(child: Text('لا يوجد مشتركون حالياً'))
                : ListView.builder(
                    itemCount: subsData.length,
                    itemBuilder: (_, i) {
                      final sub = subsData[i];
                      final exp = DateTime.tryParse(sub['expires_at']);
                      final daysLeft = exp != null
                          ? exp.difference(DateTime.now()).inDays
                          : 0;
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFD700),
                          child: Icon(Icons.star,
                              color: Colors.white, size: 20),
                        ),
                        title: Text(sub['user_name'] ?? 'مستخدم',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(sub['user_email'] ?? '',
                            style: const TextStyle(fontSize: 10)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: daysLeft > 3
                                ? Colors.green.withOpacity(0.15)
                                : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$daysLeft يوم',
                              style: TextStyle(
                                  color: daysLeft > 3
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showKitabiSnack(context, 'خطأ: $e');
    }
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
                    Text('v1.0 — الإصدار الرسمي',
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
                  () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateQuizScreen()),
                );
                if (result == true && mounted) _showQuizzes();
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard('الإحصائيات', 'تحليل',
                  Icons.bar_chart_rounded, const Color(0xFF283593),
                  () => _showStatistics()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bigCard('اشتراك بلس', 'إضافة',
                  Icons.workspace_premium, const Color(0xFFFFA000),
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddSubscriptionScreen()),
                );
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard('المشتركون', 'قائمة',
                  Icons.card_membership, const Color(0xFF6A1B9A),
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionsListScreen()),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bigCard('كود الهدية', 'إحصائيات',
                  Icons.card_giftcard_rounded, const Color(0xFFE91E63),
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReferralStatsScreen()),
                );
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard('Plus', 'المستخدمون',
                  Icons.star_rounded, const Color(0xFFFFD700),
                  () => _showPlusUsers()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bigCard('الصلاحيات', 'إدارة',
                  Icons.shield, const Color(0xFF7B1FA2),
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageRolesScreen()),
                );
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard('الأدوار', 'عرض',
                  Icons.verified_user, const Color(0xFF00897B),
                  () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageRolesScreen()),
                );
              }),
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
              _listItem(Icons.workspace_premium, 'إضافة اشتراك بلس',
                  const Color(0xFFFFA000), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddSubscriptionScreen()),
                );
              }),
              _divider(),
              _listItem(Icons.card_membership, 'اشتراكات بلس',
                  const Color(0xFF6A1B9A), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionsListScreen()),
                );
              }),
              _divider(),
              _listItem(Icons.shield, 'إدارة الصلاحيات',
                  const Color(0xFF7B1FA2), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ManageRolesScreen()),
                );
              }),
              _divider(),
              _listItem(Icons.settings_suggest, 'الإعدادات المتقدمة',
                  const Color(0xFF455A64), () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdvancedSettingsScreen()),
                );
              }),
              _divider(),

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
                                      AvatarHelper.buildAvatar(
                                          email: u['email'] ?? '',
                                          name: u['name'] ?? '?',
                                          avatarUrl: u['avatar_url'],
                                          radius: 22,
                                          backgroundColor: banned
                                              ? Colors.red
                                              : const Color(0xFF1565C0),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                        u['name'] ?? '',
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                            color: Color(0xFF1A1A1A))),
                                                  ),
                                                  if (u['role'] != null &&
                                                      u['role'] != 'student')
                                                    Container(
                                                      margin: const EdgeInsets.only(right: 6),
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: RoleHelper.roleColor(
                                                                u['role'].toString())
                                                            .withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        RoleHelper.roleLabel(
                                                            u['role'].toString()),
                                                        style: TextStyle(
                                                            color: RoleHelper.roleColor(
                                                                u['role'].toString()),
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  if (banned)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red.shade100,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text(
                                                        'محظور',
                                                        style: TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (u['email'] != null &&
                                                  u['email'].toString().isNotEmpty)
                                                Text(
                                                  u['email'].toString(),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF888888)),
                                                ),
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
    String selectedSection = '';
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
                        : (v) => setSt(() {
                              selectedGrade = v ?? selectedGrade;
                              if (selectedGrade == 'ثانية ثانوي' ||
                                  selectedGrade == 'ثالثة ثانوي') {
                                if (selectedSection.isEmpty) {
                                  selectedSection = 'علمي';
                                }
                              } else {
                                selectedSection = '';
                              }
                            }),
                  ),
                  if (selectedGrade == 'ثانية ثانوي' ||
                      selectedGrade == 'ثالثة ثانوي') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedSection.isEmpty
                          ? 'علمي'
                          : selectedSection,
                      decoration: InputDecoration(
                        labelText: 'القسم',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'علمي', child: Text('القسم العلمي')),
                        DropdownMenuItem(
                            value: 'أدبي', child: Text('القسم الأدبي')),
                      ],
                      onChanged: uploading
                          ? null
                          : (v) => setSt(
                              () => selectedSection = v ?? 'علمي'),
                    ),
                  ],
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
                          'section': selectedSection.isEmpty
                              ? null
                              : selectedSection,
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

// ==================================================
// نظام كود الهدية (Referral System) — Kitabi
// أضف هذا الكود في نهاية lib/main.dart
// ==================================================

// ============ ReferralHelper ============
class ReferralHelper {
  /// يجلب أو ينشئ كود المستخدم
  static Future<String?> getOrCreateMyCode(String email) async {
    try {
      // 1) نبحث عن كود موجود
      final existing = await supabase
          .from('users')
          .select('invite_code')
          .eq('email', email)
          .limit(1);
      
      if (existing.isNotEmpty && existing[0]['invite_code'] != null) {
        return existing[0]['invite_code'] as String;
      }
      
      // 2) ننشئ كود جديد
      final codeResponse = await supabase.rpc('generate_referral_code');
      final newCode = codeResponse as String;
      
      // 3) نحفظه في users
      await supabase
          .from('users')
          .update({'invite_code': newCode})
          .eq('email', email);
      
      return newCode;
    } catch (e) {
      debugPrint('getOrCreateMyCode error: $e');
      return null;
    }
  }
  
  /// يجلب عدد الأشخاص الذين استخدموا كودي
  static Future<int> getMyInviteCount(String email) async {
    try {
      final data = await supabase
          .from('referral_uses')
          .select('id')
          .eq('code_owner_email', email);
      return (data as List).length;
    } catch (e) {
      return 0;
    }
  }
  
  /// يجلب قائمة من استخدموا كودي
  static Future<List<Map<String, dynamic>>> getMyReferrals(String email) async {
    try {
      final data = await supabase
          .from('referral_uses')
          .select()
          .eq('code_owner_email', email)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }
  
  /// هل استخدمت كوداً من قبل؟
  static Future<bool> hasUsedCode(String email) async {
    try {
      final data = await supabase
          .from('referral_uses')
          .select('id')
          .eq('used_by_email', email)
          .limit(1);
      return (data as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// تفعيل كود
  static Future<Map<String, dynamic>> redeemCode({
    required String code,
    required String email,
  }) async {
    try {
      final result = await supabase.rpc('redeem_referral_code', params: {
        'p_code': code.toUpperCase().trim(),
        'p_user_email': email,
      });
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      debugPrint('redeemCode error: $e');
      return {'success': false, 'error': 'خطأ في الاتصال: $e'};
    }
  }
}

// ============ ReferralScreen ============
class ReferralScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  const ReferralScreen({
    super.key,
    required this.userEmail,
    required this.userName,
  });
  
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _codeCtrl = TextEditingController();
  String? _myCode;
  bool _loading = true;
  bool _redeeming = false;
  int _inviteCount = 0;
  List<Map<String, dynamic>> _referrals = [];
  bool _hasUsedCode = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final code = await ReferralHelper.getOrCreateMyCode(widget.userEmail);
      final count = await ReferralHelper.getMyInviteCount(widget.userEmail);
      final refs = await ReferralHelper.getMyReferrals(widget.userEmail);
      final used = await ReferralHelper.hasUsedCode(widget.userEmail);
      
      if (!mounted) return;
      setState(() {
        _myCode = code;
        _inviteCount = count;
        _referrals = refs;
        _hasUsedCode = used;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }
  
  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      showKitabiSnack(context, 'اكتب كود صديقك');
      return;
    }
    
    setState(() => _redeeming = true);
    
    final result = await ReferralHelper.redeemCode(
      code: code,
      email: widget.userEmail,
    );
    
    if (!mounted) return;
    setState(() => _redeeming = false);
    
    if (result['success'] == true) {
      showKitabiSnack(context, '🎉 تم التفعيل! +3 أيام Plus لك، +7 أيام لصديقك');
      _codeCtrl.clear();
      _loadData();
    } else {
      showKitabiSnack(context, result['error']?.toString() ?? 'فشل التفعيل');
    }
  }
  
  void _copyCode() {
    if (_myCode == null) return;
    Clipboard.setData(ClipboardData(text: _myCode!));
    showKitabiSnack(context, '📋 تم نسخ الكود');
  }
  
  void _shareCode() {
    if (_myCode == null) return;
    final msg = 'مرحباً! استخدم كودي "$_myCode" في تطبيق كتابي '
                'وستحصل على 3 أيام Plus مجاناً! 🎁';
    Clipboard.setData(ClipboardData(text: msg));
    showKitabiSnack(context, '📋 تم نسخ رسالة الدعوة');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كود الهدية 🎁'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // === كودي ===
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.card_giftcard,
                              size: 48, color: Color(0xFF1565C0)),
                          const SizedBox(height: 12),
                          const Text('كودك الخاص',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF1565C0), width: 2),
                            ),
                            child: Text(
                              _myCode ?? '...',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _copyCode,
                                  icon: const Icon(Icons.copy),
                                  label: const Text('نسخ'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _shareCode,
                                  icon: const Icon(Icons.share),
                                  label: const Text('مشاركة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00897B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'استخدمه $_inviteCount مرة',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // === استخدم كود صديق ===
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('🎁 استخدم كود صديق',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            _hasUsedCode
                                ? 'استخدمت كوداً من قبل ✓'
                                : 'اكتب كود صديقك واحصل على 3 أيام Plus مجاناً!',
                            style: TextStyle(
                              color: _hasUsedCode
                                  ? Colors.green
                                  : Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _codeCtrl,
                            enabled: !_hasUsedCode,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'KITABI-XXXXXX',
                              prefixIcon: const Icon(Icons.vpn_key),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: (_redeeming || _hasUsedCode)
                                ? null
                                : _redeem,
                            icon: _redeeming
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Icon(Icons.check_circle),
                            label: Text(_redeeming ? 'جاري...' : 'تفعيل الكود'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // === قائمة من استخدموا كودي ===
                  if (_referrals.isNotEmpty)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('👥 من استخدم كودك ($_inviteCount)',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ..._referrals.map((r) => ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(r['used_by_name'] ?? 'مستخدم'),
                                  subtitle: Text(
                                    '+7 أيام لك',
                                    style: const TextStyle(
                                        color: Colors.green, fontSize: 12),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}


// ==================================================
// ReferralStatsScreen — إحصائيات كود الهدية
// ==================================================
class ReferralStatsScreen extends StatefulWidget {
  const ReferralStatsScreen({super.key});
  @override
  State<ReferralStatsScreen> createState() => _ReferralStatsScreenState();
}

class _ReferralStatsScreenState extends State<ReferralStatsScreen> {
  List<Map<String, dynamic>> _uses = [];
  List<Map<String, dynamic>> _subs = [];
  Map<String, int> _topInviters = {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final usesData = await supabase
          .from('referral_uses')
          .select()
          .order('created_at', ascending: false);
      final subsData = await supabase
          .from('subscriptions')
          .select()
          .eq('is_active', true)
          .order('expires_at', ascending: false);

      final Map<String, int> counts = {};
      for (var u in usesData) {
        final owner = u['code_owner_name'] ?? 'مجهول';
        counts[owner] = (counts[owner] ?? 0) + 1;
      }
      final sorted = Map.fromEntries(
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      );

      if (!mounted) return;
      setState(() {
        _uses = List<Map<String, dynamic>>.from(usesData);
        _subs = List<Map<String, dynamic>>.from(subsData);
        _topInviters = Map<String, int>.from(sorted);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load referral stats error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  int get _activePlusCount {
    final now = DateTime.now();
    return _subs.where((s) {
      final exp = DateTime.tryParse(s['expires_at']?.toString() ?? '');
      return exp != null && exp.isAfter(now);
    }).length;
  }

  Future<void> _exportCSV() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/referral_stats_${DateTime.now().millisecondsSinceEpoch}.csv');
      final buffer = StringBuffer();
      buffer.writeln('owner,used_by,code,owner_days,user_days,date');
      for (var u in _uses) {
        buffer.writeln([
          u['code_owner_name'] ?? '',
          u['used_by_name'] ?? '',
          u['invite_code'] ?? '',
          u['owner_reward_days'] ?? 0,
          u['user_reward_days'] ?? 0,
          u['created_at'] ?? '',
        ].join(','));
      }
      await file.writeAsString(buffer.toString());
      if (!mounted) return;
      showKitabiSnack(context, 'تم التصدير');
    } catch (e) {
      if (!mounted) return;
      showKitabiSnack(context, 'فشل التصدير: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredUses {
    if (_search.isEmpty) return _uses;
    final q = _search.toLowerCase();
    return _uses.where((u) {
      return (u['code_owner_name']?.toString().toLowerCase().contains(q) ?? false) ||
             (u['used_by_name']?.toString().toLowerCase().contains(q) ?? false) ||
             (u['invite_code']?.toString().toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('إحصائيات كود الهدية'),
          backgroundColor: const Color(0xFFE91E63),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إحصائيات كود الهدية'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'تصدير CSV',
            onPressed: _uses.isEmpty ? null : _exportCSV,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _statCard('إجمالي الاستخدامات',
                      '${_uses.length}', Icons.card_giftcard,
                      const Color(0xFFE91E63)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard('مشتركو Plus',
                      '$_activePlusCount', Icons.star,
                      const Color(0xFFFFD700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statCard('أكواد مستخدمة',
                      '${_uses.map((u) => u['invite_code']).toSet().length}',
                      Icons.vpn_key, const Color(0xFF7B1FA2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard('مستخدمون مميزون',
                      '${_topInviters.length}', Icons.emoji_events,
                      const Color(0xFFEF6C00)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_topInviters.isNotEmpty) ...[
              const Text('أكثر 5 مستخدمين دعوة',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 10),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: _topInviters.entries.take(5).toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final medals = ['1', '2', '3', '4', '5'];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE91E63),
                          child: Text(medals[idx],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(item.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE91E63).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${item.value} دعوة',
                              style: const TextStyle(
                                  color: Color(0xFFE91E63),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الكود...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('سجل الاستخدامات (${_filteredUses.length})',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_filteredUses.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 10),
                    Text('لا توجد استخدامات',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
            else
              ..._filteredUses.map((u) => Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE91E63).withOpacity(0.15),
                        child: const Icon(Icons.card_giftcard,
                            color: Color(0xFFE91E63), size: 20),
                      ),
                      title: Text(
                          '${u['code_owner_name']} - ${u['used_by_name']}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'الكود: ${u['invite_code']}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('+${u['owner_reward_days']} لصاحبه',
                              style: const TextStyle(
                                  color: Colors.green, fontSize: 10)),
                          Text('+${u['user_reward_days']} للمستخدم',
                              style: const TextStyle(
                                  color: Colors.blue, fontSize: 10)),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==================================================
// CalculatorScreen — آلة حاسبة علمية متطورة
// ==================================================
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _display = '0';
  String _expression = '';
  String _lastResult = '';
  double? _memory;
  bool _isScientific = false;
  bool _showHistory = false;
  List<Map<String, String>> _history = [];
  final ScrollController _historyScroll = ScrollController();

  @override
  void dispose() {
    _historyScroll.dispose();
    super.dispose();
  }

  void _haptic() {
    HapticFeedback.lightImpact();
  }

  void _onBtn(String value) {
    _haptic();
    setState(() {
      // الأرقام
      if (RegExp(r'^[0-9]$').hasMatch(value)) {
        if (_display == '0' || _display == 'خطأ') {
          _display = value;
        } else {
          _display += value;
        }
      }
      // النقطة العشرية
      else if (value == '.') {
        if (!_display.contains('.')) {
          _display += '.';
        }
      }
      // العمليات
      else if (value == '+' || value == '-' || value == '×' || value == '÷') {
        _expression += _display + ' ' + value + ' ';
        _display = '0';
      }
      // يساوي
      else if (value == '=') {
        _calculate();
      }
      // مسح الكل
      else if (value == 'C') {
        _display = '0';
        _expression = '';
      }
      // مسح الحرف الأخير
      else if (value == '⌫') {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
      }
      // تغيير الإشارة
      else if (value == '±') {
        if (_display.startsWith('-')) {
          _display = _display.substring(1);
        } else if (_display != '0') {
          _display = '-' + _display;
        }
      }
      // النسبة
      else if (value == '%') {
        final n = double.tryParse(_display) ?? 0;
        _display = (n / 100).toString();
      }
      // الدوال العلمية
      else if (value == 'sin' || value == 'cos' || value == 'tan' ||
               value == 'log' || value == 'ln' || value == '√') {
        _applyScientific(value);
      }
      else if (value == 'x²') {
        final n = double.tryParse(_display) ?? 0;
        _display = (n * n).toString();
      }
      else if (value == 'x³') {
        final n = double.tryParse(_display) ?? 0;
        _display = (n * n * n).toString();
      }
      else if (value == '1/x') {
        final n = double.tryParse(_display) ?? 0;
        if (n != 0) {
          _display = (1 / n).toString();
        } else {
          _display = 'خطأ';
        }
      }
      else if (value == 'π') {
        _display = (3.141592653589793).toString();
      }
      else if (value == 'e') {
        _display = (2.718281828459045).toString();
      }
      else if (value == '!') {
        final n = int.tryParse(_display) ?? 0;
        if (n >= 0 && n <= 170) {
          double r = 1;
          for (int i = 2; i <= n; i++) {
            r *= i;
          }
          _display = r.toString();
        } else {
          _display = 'خطأ';
        }
      }
      else if (value == '(' || value == ')') {
        _expression += value;
      }
      // الذاكرة
      else if (value == 'M+') {
        _memory = (_memory ?? 0) + (double.tryParse(_display) ?? 0);
        _display = '0';
      }
      else if (value == 'M-') {
        _memory = (_memory ?? 0) - (double.tryParse(_display) ?? 0);
        _display = '0';
      }
      else if (value == 'MR') {
        if (_memory != null) _display = _memory.toString();
      }
      else if (value == 'MC') {
        _memory = null;
      }
    });
  }

  void _applyScientific(String fn) {
    final n = double.tryParse(_display);
    if (n == null) {
      _display = 'خطأ';
      return;
    }
    double result;
    switch (fn) {
      case 'sin':
        result = _sin(n);
        break;
      case 'cos':
        result = _cos(n);
        break;
      case 'tan':
        result = _tan(n);
        break;
      case 'log':
        result = n > 0 ? (_log10(n)) : double.nan;
        break;
      case 'ln':
        result = n > 0 ? (_ln(n)) : double.nan;
        break;
      case '√':
        result = n >= 0 ? (_sqrt(n)) : double.nan;
        break;
      default:
        result = double.nan;
    }
    _display = result.isNaN ? 'خطأ' : result.toString();
  }

  // دوال رياضية بدون dart:math
  double _sin(double x) {
    // تقدير بواسطة Taylor series
    double xr = x % (2 * 3.141592653589793);
    double term = xr;
    double sum = xr;
    for (int i = 1; i < 10; i++) {
      term *= -xr * xr / ((2 * i) * (2 * i + 1));
      sum += term;
    }
    return sum;
  }

  double _cos(double x) {
    double xr = x % (2 * 3.141592653589793);
    double term = 1.0;
    double sum = 1.0;
    for (int i = 1; i < 10; i++) {
      term *= -xr * xr / ((2 * i - 1) * (2 * i));
      sum += term;
    }
    return sum;
  }

  double _tan(double x) {
    return _sin(x) / _cos(x);
  }

  double _ln(double x) {
    if (x <= 0) return double.nan;
    // تقريب ln(x)
    double y = (x - 1) / (x + 1);
    double y2 = y * y;
    double sum = 0;
    double term = y;
    for (int i = 0; i < 100; i++) {
      sum += term / (2 * i + 1);
      term *= y2;
    }
    return 2 * sum;
  }

  double _log10(double x) {
    return _ln(x) / _ln(10);
  }

  double _sqrt(double x) {
    if (x < 0) return double.nan;
    if (x == 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  void _calculate() {
    try {
      final expr = _expression + _display;
      final result = _evaluate(expr);
      _lastResult = expr + ' = ' + result;
      _history.insert(0, {
        'expr': expr,
        'result': result,
      });
      if (_history.length > 50) _history.removeLast();
      _display = result;
      _expression = '';
    } catch (e) {
      _display = 'خطأ';
    }
  }

  String _evaluate(String expr) {
    // إزالة المسافات
    expr = expr.replaceAll(' ', '');
    // استبدال الرموز
    expr = expr.replaceAll('×', '*');
    expr = expr.replaceAll('÷', '/');
    // معالجة القسمة على صفر
    if (expr.contains('/0') && !expr.contains('/0.')) {
      return 'خطأ';
    }
    // تقييم بسيط
    final result = _parseExpression(expr);
    if (result.isNaN || result.isInfinite) {
      return 'خطأ';
    }
    // تنسيق النتيجة
    if (result == result.toInt().toDouble()) {
      return result.toInt().toString();
    }
    return result.toStringAsFixed(10).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  double _parseExpression(String expr) {
    // إزالة الأقواس الخارجية
    while (expr.startsWith('(') && expr.endsWith(')')) {
      expr = expr.substring(1, expr.length - 1);
    }
    // البحث عن آخر + أو -
    int depth = 0;
    for (int i = expr.length - 1; i >= 0; i--) {
      final c = expr[i];
      if (c == ')') depth++;
      if (c == '(') depth--;
      if (depth == 0 && (c == '+' || c == '-') && i > 0) {
        final left = _parseExpression(expr.substring(0, i));
        final right = _parseExpression(expr.substring(i + 1));
        return c == '+' ? left + right : left - right;
      }
    }
    // البحث عن آخر * أو /
    depth = 0;
    for (int i = expr.length - 1; i >= 0; i--) {
      final c = expr[i];
      if (c == ')') depth++;
      if (c == '(') depth--;
      if (depth == 0 && (c == '*' || c == '/')) {
        final left = _parseExpression(expr.substring(0, i));
        final right = _parseExpression(expr.substring(i + 1));
        if (c == '*') return left * right;
        if (right == 0) return double.nan;
        return left / right;
      }
    }
    // رقم
    return double.tryParse(expr) ?? 0;
  }

  Widget _btn(String label, {
    Color? color,
    Color? textColor,
    VoidCallback? onTap,
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap ?? () => _onBtn(label),
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicMode() {
    const blue = Color(0xFF1565C0);
    const orange = Color(0xFFEF6C00);
    return Column(
      children: [
        Row(children: [
          _btn('C', color: Colors.red.shade50, textColor: Colors.red),
          _btn('⌫', color: Colors.orange.shade50, textColor: orange),
          _btn('%', color: Colors.orange.shade50, textColor: orange),
          _btn('÷', color: blue, textColor: Colors.white),
        ]),
        Row(children: [
          _btn('7'),
          _btn('8'),
          _btn('9'),
          _btn('×', color: blue, textColor: Colors.white),
        ]),
        Row(children: [
          _btn('4'),
          _btn('5'),
          _btn('6'),
          _btn('-', color: blue, textColor: Colors.white),
        ]),
        Row(children: [
          _btn('1'),
          _btn('2'),
          _btn('3'),
          _btn('+', color: blue, textColor: Colors.white),
        ]),
        Row(children: [
          _btn('±'),
          _btn('0'),
          _btn('.'),
          _btn('=', color: orange, textColor: Colors.white),
        ]),
      ],
    );
  }

  Widget _buildScientificMode() {
    const blue = Color(0xFF1565C0);
    const orange = Color(0xFFEF6C00);
    const purple = Color(0xFF7B1FA2);
    return Column(
      children: [
        Row(children: [
          _btn('sin', color: purple.withOpacity(0.1), textColor: purple),
          _btn('cos', color: purple.withOpacity(0.1), textColor: purple),
          _btn('tan', color: purple.withOpacity(0.1), textColor: purple),
          _btn('(', color: purple.withOpacity(0.1), textColor: purple),
        ]),
        Row(children: [
          _btn('log', color: purple.withOpacity(0.1), textColor: purple),
          _btn('ln', color: purple.withOpacity(0.1), textColor: purple),
          _btn('√', color: purple.withOpacity(0.1), textColor: purple),
          _btn(')', color: purple.withOpacity(0.1), textColor: purple),
        ]),
        Row(children: [
          _btn('x²', color: purple.withOpacity(0.1), textColor: purple),
          _btn('x³', color: purple.withOpacity(0.1), textColor: purple),
          _btn('1/x', color: purple.withOpacity(0.1), textColor: purple),
          _btn('!', color: purple.withOpacity(0.1), textColor: purple),
        ]),
        Row(children: [
          _btn('π', color: purple.withOpacity(0.1), textColor: purple),
          _btn('e', color: purple.withOpacity(0.1), textColor: purple),
          _btn('C', color: Colors.red.shade50, textColor: Colors.red),
          _btn('⌫', color: Colors.orange.shade50, textColor: orange),
        ]),
        Row(children: [
          _btn('MC', color: purple.withOpacity(0.1), textColor: purple),
          _btn('MR', color: purple.withOpacity(0.1), textColor: purple),
          _btn('M+', color: purple.withOpacity(0.1), textColor: purple),
          _btn('M-', color: purple.withOpacity(0.1), textColor: purple),
        ]),
        Row(children: [
          _btn('%', color: Colors.orange.shade50, textColor: orange),
          _btn('7'),
          _btn('8'),
          _btn('9'),
          _btn('÷', color: blue, textColor: Colors.white),
        ]),
        Row(children: [
          _btn('±', color: Colors.grey.shade100),
          _btn('4'),
          _btn('5'),
          _btn('6'),
          _btn('×', color: blue, textColor: Colors.white),
        ]),
        Row(children: [
          _btn('.'),
          _btn('1'),
          _btn('2'),
          _btn('3'),
          _btn('-', color: blue, textColor: Colors.white),
        ]),
        Row(children: [
          _btn('=', color: orange, textColor: Colors.white, flex: 2),
          _btn('0'),
          _btn('+', color: blue, textColor: Colors.white, flex: 2),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('آلة حاسبة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isScientific ? Icons.calculate : Icons.functions),
            tooltip: _isScientific ? 'بسيطة' : 'علمية',
            onPressed: () => setState(() => _isScientific = !_isScientific),
          ),
          IconButton(
            icon: Icon(_showHistory ? Icons.history_toggle_off : Icons.history),
            tooltip: 'السجل',
            onPressed: () => setState(() => _showHistory = !_showHistory),
          ),
        ],
      ),
      body: Column(
        children: [
          // شاشة العرض
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_expression.isNotEmpty)
                  Text(
                    _expression,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Text(
                    _display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_memory != null)
                  Text(
                    'M: $_memory',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          // السجل
          if (_showHistory)
            Container(
              height: 100,
              color: Colors.grey.shade100,
              child: _history.isEmpty
                  ? const Center(child: Text('لا يوجد سجل'))
                  : ListView.builder(
                      controller: _historyScroll,
                      scrollDirection: Axis.horizontal,
                      itemCount: _history.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (_, i) {
                        final h = _history[i];
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(h['expr']!,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                              Text(h['result']!,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1565C0))),
                            ],
                          ),
                        );
                      },
                    ),
            ),

          // الأزرار
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: _isScientific ? _buildScientificMode() : _buildBasicMode(),
            ),
          ),
        ],
      ),
    );
  }
}


// ==================================================
// ResetPasswordScreen — شاشة إعادة تعيين كلمة السر
// ==================================================
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;
  bool _saving = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_passCtrl.text.length < 6) {
      showKitabiSnack(context, 'كلمة السر 6 أحرف على الأقل');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      showKitabiSnack(context, 'كلمتا السر غير متطابقتين');
      return;
    }

    setState(() => _saving = true);

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _passCtrl.text),
      );
      
      if (!mounted) return;
      showKitabiSnack(context, '✅ تم تغيير كلمة السر بنجاح');
      
      // ننتظر ثانيتين ثم نرجع لتسجيل الدخول
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      
      // نخرج من الجلسة الحالية
      await supabase.auth.signOut();
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Reset password error: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      showKitabiSnack(context, 'فشل تغيير كلمة السر: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('كلمة سر جديدة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.lock_reset,
                  size: 60, color: Colors.white),
            ),
            const SizedBox(height: 30),
            const Text(
              'اكتب كلمة السر الجديدة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'اختر كلمة سر قوية لا يعرفها أحد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 30),
            
            // كلمة السر الجديدة
            TextField(
              controller: _passCtrl,
              obscureText: !_showPass,
              decoration: InputDecoration(
                labelText: 'كلمة السر الجديدة',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showPass
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _showPass = !_showPass),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            
            // تأكيد كلمة السر
            TextField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة السر',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // زر الحفظ
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ كلمة السر'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// ResetPasswordScreen — شاشة إعادة تعيين كلمة السر
// ==================================================

// ==================================================
// EmailVerifiedScreen — شاشة تأكيد الإيميل بنجاح
// ==================================================
class EmailVerifiedScreen extends StatelessWidget {
  const EmailVerifiedScreen({super.key});

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
              // أيقونة النجاح
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00897B), Color(0xFF26A69A)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00897B).withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),

              // العنوان
              const Text(
                '🎉 تم تأكيد حسابك!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),

              // الوصف
              const Text(
                'حسابك مفعّل الآن. يمكنك تسجيل الدخول والاستفادة من جميع مميزات تطبيق كتابي.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF555555),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // زر تسجيل الدخول
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // نضمن تسجيل الخروج
                    try {
                      await supabase.auth.signOut();
                    } catch (_) {}

                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

// ==================================================
// TermsOfServiceScreen — شروط الاستخدام
// ==================================================
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('شروط الاستخدام',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.update,
                      color: Color(0xFF1565C0), size: 20),
                  SizedBox(width: 10),
                  Text('آخر تحديث: 16 أكتوبر 2026',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _section(
              'قبول الشروط',
              'باستخدامك تطبيق كتابي، فإنك توافق على هذه الشروط. '
                  'إذا لم توافق على أي جزء منها، يُرجى عدم استخدام التطبيق.',
            ),
            _section(
              'وصف الخدمة',
              'كتابي تطبيق تعليمي مجاني للطلاب الليبيين. '
                  'يوفر:\n\n'
                  '• مكتبة كتب رقمية\n'
                  '• اختبارات تعليمية\n'
                  '• معلم ذكي (AI)\n'
                  '• منتدى للتفاعل\n'
                  '• أدوات تعليمية إضافية',
            ),
            _section(
              'شروط الاستخدام',
              '1. يجب أن تكون طالباً أو معلماً في ليبيا.\n'
                  '2. يجب تقديم معلومات صحيحة عند التسجيل.\n'
                  '3. يجب الحفاظ على سرية كلمة السر.\n'
                  '4. يُمنع استخدام التطبيق لأغراض تجارية.\n'
                  '5. يُمنع محاولة اختراق التطبيق أو إساءة استخدامه.',
            ),
            _section(
              'السلوك المحظور',
              'يُمنع منعاً باتاً:\n\n'
                  '❌ نشر محتوى مسيء أو مخالف للأخلاق.\n'
                  '❌ التنمر أو التحرش بالآخرين.\n'
                  '❌ نشر معلومات مضللة.\n'
                  '❌ انتحال شخصية الآخرين.\n'
                  '❌ نشر رسائل دعائية (Spam).\n'
                  '❌ محاولة اختراق أو تعطيل التطبيق.',
            ),
            _section(
              'ملكية المحتوى',
              '• جميع محتويات التطبيق محمية بحقوق النشر.\n'
                  '• لا يمكنك نسخ أو إعادة نشر أي محتوى.\n'
                  '• المحتوى الذي تنشره (منشورات، تعليقات) يبقى ملكك.\n'
                  '• بموجب هذه الشروط، تمنحنا حق عرض المحتوى داخل التطبيق.',
            ),
            _section(
              'إيقاف الحساب',
              'نحتفظ بالحق في:\n\n'
                  '• إيقاف أو حظر أي حساب يخالف الشروط.\n'
                  '• حذف أي محتوى مخالف.\n'
                  '• رفض الخدمة لأي مستخدم دون إشعار مسبق.',
            ),
            _section(
              'إخلاء المسؤولية',
              'التطبيق يُقدَّم "كما هو". '
                  'رغم حرصنا على دقة المحتوى، لا نتحمل مسؤولية:\n\n'
                  '• أي أخطاء في المحتوى التعليمي.\n'
                  '• أي خسارة ناتجة عن استخدام التطبيق.\n'
                  '• أي انقطاع في الخدمة.',
            ),
            _section(
              'الأشتراكات Plus',
              '• الاشتراكات Plus اختيارية وتمنح مميزات إضافية.\n'
                  '• الاشتراك الحالي مجاني بالكامل.\n'
                  '• في المستقبل، قد تُضاف اشتراكات مدفوعة مع إشعار مسبق.',
            ),
            _section(
              'التعديلات',
              'نحتفظ بالحق في تعديل هذه الشروط في أي وقت. '
                  'سنُعلمك بالتغييرات الجوهرية عبر التطبيق. '
                  'استمرارك في استخدام التطبيق يعني موافقتك على الشروط المعدّلة.',
            ),
            _section(
              'القانون المطبق',
              'تخضع هذه الشروط للقوانين الليبية. '
                  'أي نزاع يُحلّ ودياً أولاً، ثم أمام المحاكم المختصة في ليبيا.',
            ),
            _section(
              'تواصل معنا',
              'لأي استفسار حول شروط الاستخدام:\n\n'
                  '📧 mhmdkfkwfalqmaty@gmail.com\n'
                  '📞 0922251374',
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(Icons.gavel, color: Colors.white, size: 45),
                  SizedBox(height: 12),
                  Text('استخدامك = موافقتك',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('يرجى قراءة الشروط بعناية قبل الاستخدام',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// AvatarHelper — إدارة الصور الرمزية
// ==================================================
class AvatarHelper {
  /// يحمّل رابط الصورة الرمزية لمستخدم
  static Future<String?> getAvatarUrl(String email) async {
    if (email.isEmpty) return null;
    try {
      final data = await supabase
          .from('users')
          .select('avatar_url')
          .eq('email', email)
          .limit(1);
      if (data.isEmpty) return null;
      final url = data[0]['avatar_url'];
      if (url == null || url.toString().isEmpty) return null;
      return url.toString();
    } catch (e) {
      debugPrint('getAvatarUrl error: $e');
      return null;
    }
  }

  /// يحمّل روابط صور عدة مستخدمين (bulk)
  static Future<Map<String, String>> getAvatarsMap(
      List<String> emails) async {
    if (emails.isEmpty) return {};
    try {
      final data = await supabase
          .from('users')
          .select('email, avatar_url')
          .inFilter('email', emails);
      final Map<String, String> map = {};
      for (var row in data) {
        final email = row['email']?.toString() ?? '';
        final url = row['avatar_url']?.toString() ?? '';
        if (email.isNotEmpty && url.isNotEmpty) {
          map[email] = url;
        }
      }
      return map;
    } catch (e) {
      debugPrint('getAvatarsMap error: $e');
      return {};
    }
  }

  /// يرفع صورة للمستخدم ويعيد الرابط
  static Future<String?> uploadAvatar({
    required String email,
    required File imageFile,
  }) async {
    try {
      // نقرأ الصورة كـ bytes
      final bytes = await imageFile.readAsBytes();

      // نحدد الامتداد
      final ext = imageFile.path.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // اسم الملف: {sanitized_email}_{timestamp}.{ext}
      final safeEmail = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName = '${safeEmail}_$timestamp.$ext';

      // نحذف الصورة القديمة إن وُجدت
      final oldData = await supabase
          .from('users')
          .select('avatar_url')
          .eq('email', email)
          .limit(1);

      if (oldData.isNotEmpty) {
        final oldUrl = oldData[0]['avatar_url']?.toString() ?? '';
        if (oldUrl.isNotEmpty) {
          try {
            // نستخرج اسم الملف القديم من الرابط
            final uri = Uri.parse(oldUrl);
            final oldFileName = uri.pathSegments.last;
            if (oldFileName.isNotEmpty) {
              await supabase.storage
                  .from('avatars')
                  .remove([oldFileName]);
            }
          } catch (e) {
            debugPrint('Delete old avatar error: $e');
          }
        }
      }

      // نرفع الصورة الجديدة
      await supabase.storage
          .from('avatars')
          .uploadBinary(fileName, bytes);

      // نجيب الرابط العام
      final publicUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);

      // نحدّث قاعدة البيانات
      await supabase
          .from('users')
          .update({'avatar_url': publicUrl})
          .eq('email', email);

      return publicUrl;
    } catch (e) {
      debugPrint('uploadAvatar error: $e');
      return null;
    }
  }

  /// يحذف صورة المستخدم
  static Future<bool> deleteAvatar(String email) async {
    try {
      final data = await supabase
          .from('users')
          .select('avatar_url')
          .eq('email', email)
          .limit(1);

      if (data.isEmpty) return false;

      final url = data[0]['avatar_url']?.toString() ?? '';
      if (url.isEmpty) return false;

      // نستخرج اسم الملف
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.last;

      // نحذف من Storage
      if (fileName.isNotEmpty) {
        await supabase.storage.from('avatars').remove([fileName]);
      }

      // نحدّث قاعدة البيانات
      await supabase
          .from('users')
          .update({'avatar_url': null})
          .eq('email', email);

      return true;
    } catch (e) {
      debugPrint('deleteAvatar error: $e');
      return false;
    }
  }

  /// Widget لعرض الصورة (مع fallback للحرف)
  static Widget buildAvatar({
    required String email,
    required String name,
    String? avatarUrl,
    double radius = 20,
    Color? backgroundColor,
  }) {
    final fallbackColor = backgroundColor ?? _colorFromName(name);
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: fallbackColor,
        child: Text(
          name.isNotEmpty ? name[0] : '؟',
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: fallbackColor,
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              name.isNotEmpty ? name[0] : '؟',
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Color _colorFromName(String name) {
    if (name.isEmpty) return const Color(0xFF1565C0);
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF00897B),
      const Color(0xFF7B1FA2),
      const Color(0xFFEF6C00),
      const Color(0xFF283593),
      const Color(0xFFD32F2F),
      const Color(0xFF00838F),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ==================================================
// SettingsScreen — الإعدادات الشاملة
// ==================================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // المظهر
  double _fontScale = 1.0;
  bool _reduceMotion = false;

  // الإشعارات
  bool _notifApp = true;
  bool _notifBooks = true;
  bool _notifQuizzes = true;
  bool _notifForum = true;
  bool _notifGeneral = true;

  // الخصوصية
  bool _hideActivity = false;
  bool _showEmailInProfile = true;

  // بيانات المستخدم
  String _userEmail = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontScale = prefs.getDouble('font_scale') ?? 1.0;
      _reduceMotion = prefs.getBool('reduce_motion') ?? false;
      _notifApp = prefs.getBool('notif_app') ?? true;
      _notifBooks = prefs.getBool('notif_books') ?? true;
      _notifQuizzes = prefs.getBool('notif_quizzes') ?? true;
      _notifForum = prefs.getBool('notif_forum') ?? true;
      _notifGeneral = prefs.getBool('notif_general') ?? true;
      _hideActivity = prefs.getBool('hide_activity') ?? false;
      _showEmailInProfile =
          prefs.getBool('show_email_in_profile') ?? true;
      _userEmail = prefs.getString('user_email') ?? '';
      _userName = prefs.getString('user_name') ?? '';
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  // ============ Actions ============

  void _toggleReduceMotion(bool v) async {
    setState(() => _reduceMotion = v);
    await _savePref('reduce_motion', v);
  }

  void _toggleNotifApp(bool v) async {
    setState(() => _notifApp = v);
    await _savePref('notif_app', v);
  }

  void _toggleNotifBooks(bool v) async {
    setState(() => _notifBooks = v);
    await _savePref('notif_books', v);
  }

  void _toggleNotifQuizzes(bool v) async {
    setState(() => _notifQuizzes = v);
    await _savePref('notif_quizzes', v);
  }

  void _toggleNotifForum(bool v) async {
    setState(() => _notifForum = v);
    await _savePref('notif_forum', v);
  }

  void _toggleNotifGeneral(bool v) async {
    setState(() => _notifGeneral = v);
    await _savePref('notif_general', v);
  }

  void _toggleHideActivity(bool v) async {
    setState(() => _hideActivity = v);
    await _savePref('hide_activity', v);
  }

  void _toggleShowEmail(bool v) async {
    setState(() => _showEmailInProfile = v);
    await _savePref('show_email_in_profile', v);
  }

  Future<void> _changeFontSize() async {
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('حجم الخط'),
        content: StatefulBuilder(
          builder: (ctx, setDlg) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _fontScale == 0.85
                    ? 'صغير'
                    : _fontScale == 1.0
                        ? 'عادي'
                        : _fontScale == 1.15
                            ? 'كبير'
                            : 'كبير جداً',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  _sizeChip(ctx, 0.85, 'صغير', setDlg),
                  _sizeChip(ctx, 1.0, 'عادي', setDlg),
                  _sizeChip(ctx, 1.15, 'كبير', setDlg),
                  _sizeChip(ctx, 1.3, 'كبير جداً', setDlg),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _fontScale = result);
      await _savePref('font_scale', result);
      // التحديث الفوري عبر ValueNotifier
      fontScaleNotifier.value = result;
      if (!mounted) return;
      showKitabiSnack(context, 'تم تغيير حجم الخط');
    }
  }

  Widget _sizeChip(
      BuildContext ctx, double size, String label, StateSetter setDlg) {
    final selected = _fontScale == size;
    return GestureDetector(
      onTap: () {
        setDlg(() {});
        Navigator.pop(ctx, size);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF1565C0)
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen()),
    );
  }

  void _showAccountInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person, color: Color(0xFF1565C0)),
            SizedBox(width: 10),
            Text('معلومات حسابي'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('الاسم', _userName),
            _infoRow('البريد',
                _userEmail.isEmpty ? 'غير مسجّل' : _userEmail),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'name': prefs.getString('user_name'),
        'email': prefs.getString('user_email'),
        'grade': prefs.getString('user_grade'),
        'muraqaba': prefs.getString('user_muraqaba'),
        'points': prefs.getInt('user_points'),
        'level': prefs.getInt('user_level'),
        'achievements': prefs.getInt('user_achievements'),
        'exported_at': DateTime.now().toIso8601String(),
      };

      // نحفظه في ملف
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/my_data_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(data));

      if (!mounted) return;
      Navigator.pop(context);
      showKitabiSnack(context, '✅ تم التصدير: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showKitabiSnack(context, 'فشل التصدير: $e');
    }
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('مسح الذاكرة المؤقتة'),
        content: const Text(
            'سيتم حذف البيانات المؤقتة والصور المخزنة. لن تفقد إعداداتك أو حسابك.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF6C00),
                foregroundColor: Colors.white),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        await cacheDir.delete(recursive: true);
      }
      if (!mounted) return;
      showKitabiSnack(context, '✅ تم مسح الذاكرة المؤقتة');
    } catch (e) {
      if (!mounted) return;
      showKitabiSnack(context, 'فشل المسح');
    }
  }

  void _showVersionInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'KITABI',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.menu_book,
            size: 40, color: Colors.white),
      ),
      children: const [
        Text('تطبيق تعليمي مجاني للطلاب الليبيين.'),
        SizedBox(height: 8),
        Text('جميع الخصائص مجانية بالكامل.'),
        SizedBox(height: 8),
        Text('© 2026 Kitabi Team'),
      ],
    );
  }

  void _shareApp() {
    Clipboard.setData(const ClipboardData(
      text: 'حمّل تطبيق كتابي الآن — تطبيق تعليمي مجاني للطلاب الليبيين! 📚',
    ));
    showKitabiSnack(context, '📋 تم نسخ نص المشاركة');
  }

  void _rateApp() {
    showKitabiSnack(context, '⭐ شكراً لتقييمك! (قريباً على المتاجر)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('الإعدادات',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          const SizedBox(height: 12),

          // ============ المظهر ============
          _sectionHeader('🎨 المظهر', const Color(0xFF7B1FA2)),
          _card([
            
            _tapTile(
              icon: Icons.text_fields,
              color: const Color(0xFF00897B),
              title: 'حجم الخط',
              subtitle: _fontScale == 0.9
                  ? 'صغير'
                  : _fontScale == 1.0
                      ? 'عادي'
                      : _fontScale == 1.15
                          ? 'كبير'
                          : 'كبير جداً',
              onTap: _changeFontSize,
            ),
            _divider(),
            _switchTile(
              icon: Icons.animation,
              color: const Color(0xFFEF6C00),
              title: 'تقليل الحركة',
              subtitle: 'تقليل تأثيرات الانتقال',
              value: _reduceMotion,
              onChanged: _toggleReduceMotion,
            ),
          ]),

          // ============ الإشعارات ============
          _sectionHeader('🔔 الإشعارات', const Color(0xFFD32F2F)),
          _card([
            _switchTile(
              icon: Icons.notifications_active,
              color: const Color(0xFFD32F2F),
              title: 'إشعارات التطبيق',
              subtitle: 'تمكين كل الإشعارات',
              value: _notifApp,
              onChanged: _toggleNotifApp,
            ),
            if (_notifApp) ...[
              _divider(),
              _switchTile(
                icon: Icons.menu_book,
                color: const Color(0xFF1565C0),
                title: 'كتب جديدة',
                subtitle: 'عند إضافة كتاب جديد',
                value: _notifBooks,
                onChanged: _toggleNotifBooks,
              ),
              _divider(),
              _switchTile(
                icon: Icons.assignment,
                color: const Color(0xFF00897B),
                title: 'اختبارات',
                subtitle: 'اختبارات جديدة',
                value: _notifQuizzes,
                onChanged: _toggleNotifQuizzes,
              ),
              _divider(),
              _switchTile(
                icon: Icons.forum,
                color: const Color(0xFF7B1FA2),
                title: 'المنتدى',
                subtitle: 'ردود وتعليقات جديدة',
                value: _notifForum,
                onChanged: _toggleNotifForum,
              ),
              _divider(),
              _switchTile(
                icon: Icons.campaign,
                color: const Color(0xFFEF6C00),
                title: 'إشعارات عامة',
                subtitle: 'إعلانات وأخبار',
                value: _notifGeneral,
                onChanged: _toggleNotifGeneral,
              ),
            ],
          ]),

          // ============ الحساب ============
          _sectionHeader('👤 الحساب', const Color(0xFF1565C0)),
          _card([
            _tapTile(
              icon: Icons.person_outline,
              color: const Color(0xFF1565C0),
              title: 'معلومات حسابي',
              subtitle: _userEmail.isEmpty ? 'غير مسجّل' : _userEmail,
              onTap: _showAccountInfo,
            ),
            _divider(),
            _tapTile(
              icon: Icons.lock_outline,
              color: const Color(0xFF00897B),
              title: 'تغيير كلمة السر',
              subtitle: 'تحديث كلمة السر الحالية',
              onTap: _showChangePassword,
            ),
          ]),

          // ============ البيانات ============
          _sectionHeader('💾 البيانات', const Color(0xFF6A1B9A)),
          _card([
            _tapTile(
              icon: Icons.download,
              color: const Color(0xFF1565C0),
              title: 'تصدير بياناتي',
              subtitle: 'تنزيل نسخة من بياناتك',
              onTap: _exportData,
            ),
            _divider(),
            _tapTile(
              icon: Icons.cleaning_services,
              color: const Color(0xFFEF6C00),
              title: 'مسح الذاكرة المؤقتة',
              subtitle: 'حذف الملفات المؤقتة',
              onTap: _clearCache,
            ),
          ]),

          // ============ الخصوصية ============
          _sectionHeader('🔒 الخصوصية', const Color(0xFF00897B)),
          _card([
            _tapTile(
              icon: Icons.privacy_tip_outlined,
              color: const Color(0xFF1565C0),
              title: 'سياسة الخصوصية',
              subtitle: 'كيف نحمي بياناتك',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
            _divider(),
            _tapTile(
              icon: Icons.gavel,
              color: const Color(0xFF00897B),
              title: 'شروط الاستخدام',
              subtitle: 'قواعد استخدام التطبيق',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TermsOfServiceScreen()),
                );
              },
            ),
            _divider(),
            _switchTile(
              icon: Icons.visibility_off,
              color: const Color(0xFF6A1B9A),
              title: 'إخفاء النشاط',
              subtitle: 'عدم إظهار نشاطك للآخرين',
              value: _hideActivity,
              onChanged: _toggleHideActivity,
            ),
            _divider(),
            _switchTile(
              icon: Icons.email_outlined,
              color: const Color(0xFF00838F),
              title: 'إظهار البريد في الملف',
              subtitle: 'عرض بريدك في ملفك الشخصي',
              value: _showEmailInProfile,
              onChanged: _toggleShowEmail,
            ),
          ]),

          // ============ حول ============
          _sectionHeader('ℹ️ حول التطبيق', const Color(0xFF5E35B1)),
          _card([
            _tapTile(
              icon: Icons.info_outline,
              color: const Color(0xFF5E35B1),
              title: 'الإصدار',
              subtitle: 'KITABI 1.0.0',
              onTap: _showVersionInfo,
            ),
            _divider(),
            _tapTile(
              icon: Icons.star_outline,
              color: const Color(0xFFFFA000),
              title: 'تقييم التطبيق',
              subtitle: 'ساعدنا بتقييمك ⭐',
              onTap: _rateApp,
            ),
            _divider(),
            _tapTile(
              icon: Icons.share_outlined,
              color: const Color(0xFF00897B),
              title: 'مشاركة التطبيق',
              subtitle: 'شارك مع أصدقائك',
              onTap: _shareApp,
            ),
            _divider(),
            _tapTile(
              icon: Icons.email,
              color: const Color(0xFF1565C0),
              title: 'تواصل معنا',
              subtitle: 'mhmdkfkwfalqmaty@gmail.com',
              onTap: () {
                Clipboard.setData(const ClipboardData(
                    text: 'mhmdkfkwfalqmaty@gmail.com'));
                showKitabiSnack(context, '📋 تم نسخ البريد');
              },
            ),
          ]),

          const SizedBox(height: 30),
          const Center(
            child: Text(
              'KITABI © 2026',
              style: TextStyle(
                  color: Color(0xFF999999), fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        indent: 60,
        endIndent: 15,
        color: Color(0xFFF0F0F0),
      );

  Widget _switchTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
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
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF888888))),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: color,
      ),
    );
  }

  Widget _tapTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
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
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 11, color: Color(0xFF888888))),
      trailing: const Icon(Icons.arrow_back_ios,
          size: 14, color: Color(0xFF555555)),
    );
  }
}

// ==================================================
// PomodoroScreen — مؤقت الدراسة (Pomodoro)
// ==================================================
class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  // إعدادات
  int _focusMinutes = 25;
  int _breakMinutes = 5;

  // الحالة
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _isBreak = false;
  Timer? _timer;

  // إحصائيات
  int _todaySessions = 0;
  int _todayMinutes = 0;
  int _totalSessions = 0;
  int _longestSession = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _todaySessions = prefs.getInt('pomodoro_today_sessions') ?? 0;
      _todayMinutes = prefs.getInt('pomodoro_today_minutes') ?? 0;
      _totalSessions = prefs.getInt('pomodoro_total_sessions') ?? 0;
      _longestSession = prefs.getInt('pomodoro_longest_session') ?? 0;
      _focusMinutes = prefs.getInt('pomodoro_focus_minutes') ?? 25;
      _breakMinutes = prefs.getInt('pomodoro_break_minutes') ?? 5;
    });
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _remainingSeconds = _focusMinutes * 60;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remainingSeconds <= 1) {
          _onTimerComplete();
        } else {
          setState(() => _remainingSeconds--);
        }
      });
    }
  }

  Future<void> _onTimerComplete() async {
    _timer?.cancel();
    setState(() => _isRunning = false);

    // صوت/اهتزاز
    HapticFeedback.heavyImpact();

    if (!_isBreak) {
      // انتهت جلسة تركيز
      final prefs = await SharedPreferences.getInstance();
      final sessions = (prefs.getInt('pomodoro_today_sessions') ?? 0) + 1;
      final minutes =
          (prefs.getInt('pomodoro_today_minutes') ?? 0) + _focusMinutes;
      final total = (prefs.getInt('pomodoro_total_sessions') ?? 0) + 1;
      final longest = prefs.getInt('pomodoro_longest_session') ?? 0;

      await prefs.setInt('pomodoro_today_sessions', sessions);
      await prefs.setInt('pomodoro_today_minutes', minutes);
      await prefs.setInt('pomodoro_total_sessions', total);
      if (_focusMinutes > longest) {
        await prefs.setInt('pomodoro_longest_session', _focusMinutes);
      }

      if (!mounted) return;
      setState(() {
        _todaySessions = sessions;
        _todayMinutes = minutes;
        _totalSessions = total;
        _longestSession = _focusMinutes > longest ? _focusMinutes : longest;
        _isBreak = true;
        _remainingSeconds = _breakMinutes * 60;
      });

      showKitabiSnack(context, '🎉 أكملت جلسة! وقت الراحة');
    } else {
      // انتهت الراحة
      if (!mounted) return;
      setState(() {
        _isBreak = false;
        _remainingSeconds = _focusMinutes * 60;
      });
      showKitabiSnack(context, '💪 وقت التركيز من جديد!');
    }
  }

  Future<void> _changeFocusMinutes() async {
    final values = [15, 20, 25, 30, 45, 60];
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('مدة التركيز'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((v) {
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, v),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: v == _focusMinutes
                      ? const Color(0xFFE91E63)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$v د',
                  style: TextStyle(
                    color: v == _focusMinutes
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pomodoro_focus_minutes', result);
      if (!mounted) return;
      setState(() {
        _focusMinutes = result;
        _remainingSeconds = result * 60;
      });
      _resetTimer();
    }
  }

  Future<void> _changeBreakMinutes() async {
    final values = [3, 5, 10, 15];
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('مدة الراحة'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((v) {
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, v),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: v == _breakMinutes
                      ? const Color(0xFF00897B)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$v د',
                  style: TextStyle(
                    color: v == _breakMinutes
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pomodoro_break_minutes', result);
      if (!mounted) return;
      setState(() => _breakMinutes = result);
    }
  }

  Future<void> _resetStats() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('إعادة تعيين الإحصائيات'),
        content: const Text('هل تريد مسح إحصائيات اليوم؟'),
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
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pomodoro_today_sessions');
    await prefs.remove('pomodoro_today_minutes');
    if (!mounted) return;
    setState(() {
      _todaySessions = 0;
      _todayMinutes = 0;
    });
    showKitabiSnack(context, '✅ تم مسح إحصائيات اليوم');
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _isBreak ? _breakMinutes * 60 : _focusMinutes * 60;
    final progress = total > 0 ? 1 - (_remainingSeconds / total) : 0.0;
    final accentColor =
        _isBreak ? const Color(0xFF00897B) : const Color(0xFFE91E63);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('مؤقت الدراسة ⏱️',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تعيين',
            onPressed: _resetTimer,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // الحالة
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isBreak ? '☕ وقت الراحة' : '🎯 وقت التركيز',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 30),

            // الدائرة
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        Text(
                          _isBreak
                              ? '$_breakMinutes دقيقة راحة'
                              : '$_focusMinutes دقيقة تركيز',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF555555)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // الأزرار
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // إعادة
                _circleBtn(
                  icon: Icons.refresh,
                  color: Colors.grey,
                  onTap: _resetTimer,
                ),
                const SizedBox(width: 20),

                // ابدأ/إيقاف
                GestureDetector(
                  onTap: _toggleTimer,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRunning ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // تخطي
                _circleBtn(
                  icon: Icons.skip_next,
                  color: Colors.grey,
                  onTap: _onTimerComplete,
                ),
              ],
            ),

            const SizedBox(height: 40),

            // الإعدادات
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings,
                          color: Color(0xFF1565C0), size: 22),
                      SizedBox(width: 10),
                      Text('الإعدادات',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer,
                        color: Color(0xFFE91E63)),
                    title: const Text('مدة التركيز'),
                    trailing: Text('$_focusMinutes دقيقة',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE91E63))),
                    onTap: _changeFocusMinutes,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.coffee,
                        color: Color(0xFF00897B)),
                    title: const Text('مدة الراحة'),
                    trailing: Text('$_breakMinutes دقائق',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00897B))),
                    onTap: _changeBreakMinutes,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // الإحصائيات
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart,
                          color: Color(0xFF1565C0), size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('الإحصائيات',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: _resetStats,
                        child: const Text('مسح اليوم',
                            style: TextStyle(
                                color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard('جلسات اليوم', '$_todaySessions',
                          Icons.today, const Color(0xFFE91E63)),
                      const SizedBox(width: 8),
                      _statCard('دقائق اليوم', '$_todayMinutes',
                          Icons.timer, const Color(0xFF00897B)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statCard('إجمالي الجلسات', '$_totalSessions',
                          Icons.trending_up, const Color(0xFF7B1FA2)),
                      const SizedBox(width: 8),
                      _statCard('أطول جلسة', '$_longestSession د',
                          Icons.emoji_events, const Color(0xFFFFA000)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

// ==================================================
// NotificationService — خدمة الإشعارات المحلية
// ==================================================
class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // تهيئة المنطقة الزمنية
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Tripoli'));

    // إعدادات Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // إعدادات iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    // طلب إذن على Android 13+
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// جدولة إشعار
  Future<int> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    int? id,
  }) async {
    await init();

    final notificationId =
        id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const androidDetails = AndroidNotificationDetails(
      'kitabi_schedule',
      'جدول الحصص',
      channelDescription: 'إشعارات جدول الحصص والامتحانات',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'schedule_$notificationId',
    );

    debugPrint('✅ Scheduled notification $notificationId at $scheduledDate');
    return notificationId;
  }

  /// جدولة إشعار متكرر (يومياً)
  Future<int> scheduleDailyNotification({
    required String title,
    required String body,
    required int hour,
    required int minute,
    int? id,
  }) async {
    await init();

    final notificationId =
        id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const androidDetails = AndroidNotificationDetails(
      'kitabi_daily',
      'تذكيرات يومية',
      channelDescription: 'تذكيرات يومية للدراسة',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    return notificationId;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// إلغاء إشعار
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    debugPrint('❌ Cancelled notification $id');
  }

  /// إلغاء جميع الإشعارات
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('❌ Cancelled all notifications');
  }

  /// عرض إشعار فوري (اختبار)
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'kitabi_instant',
      'إشعارات فورية',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}

// ==================================================
// ScheduleScreen — جدول الحصص الأسبوعي
// ==================================================
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDay = DateTime.now().weekday - 1; // 0 = الأحد

  // جدول: {day: {period: {subject, time, event, eventType, notifId}}}
  Map<String, Map<String, Map<String, dynamic>>> _schedule = {};

  final List<String> _days = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء',
    'الخميس', 'الجمعة', 'السبت',
  ];

  final List<String> _periods = [
    '1', '2', '3', '4', '5', '6', '7',
  ];

  final List<String> _defaultTimes = [
    '08:00', '09:00', '10:00', '11:00',
    '12:00', '13:00', '14:00',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 7, vsync: this, initialIndex: _selectedDay);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedDay = _tabController.index);
      }
    });
    _loadSchedule();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('schedule_data') ?? '{}';
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _schedule = decoded.map((day, periods) => MapEntry(
              day,
              (periods as Map<String, dynamic>).map((period, data) =>
                  MapEntry(period, Map<String, dynamic>.from(data))),
            ));
      });
    } catch (e) {
      debugPrint('Load schedule error: $e');
    }
  }

  Future<void> _saveSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('schedule_data', jsonEncode(_schedule));
  }

  Map<String, dynamic>? _getPeriod(String day, String period) {
    return _schedule[day]?[period];
  }

  bool _hasEvent(String day, String period) {
    final data = _getPeriod(day, period);
    return data != null && (data['event'] ?? '').toString().isNotEmpty;
  }

  Future<void> _openPeriodDialog(String day, String period) async {
    final existing = _getPeriod(day, period) ?? {};
    final subjectCtrl =
        TextEditingController(text: existing['subject'] ?? '');
    final timeCtrl = TextEditingController(
        text: existing['time'] ?? _defaultTimes[int.parse(period) - 1]);
    final eventCtrl =
        TextEditingController(text: existing['event'] ?? '');
    String eventType = existing['eventType'] ?? 'امتحان';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$period',
                    style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('$day — الحصة $period',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectCtrl,
                  decoration: InputDecoration(
                    labelText: 'اسم المادة',
                    prefixIcon: const Icon(Icons.book),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeCtrl,
                  decoration: InputDecoration(
                    labelText: 'وقت الحصة',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('🔔 إضافة حدث (اختياري)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                TextField(
                  controller: eventCtrl,
                  decoration: InputDecoration(
                    labelText: 'نوع الحدث (امتحان / واجب / ...)',
                    prefixIcon: const Icon(Icons.event),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: ['امتحان', 'واجب', 'مراجعة', 'اختبار قصير']
                      .map((t) => ChoiceChip(
                            label: Text(t),
                            selected: eventType == t,
                            onSelected: (v) => setDlg(() => eventType = t),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final data = {
                  'subject': subjectCtrl.text.trim(),
                  'time': timeCtrl.text.trim(),
                  'event': eventCtrl.text.trim(),
                  'eventType': eventType,
                };
                _schedule.putIfAbsent(day, () => {});
                _schedule[day]![period] = data;
                await _saveSchedule();
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      final eventText = eventCtrl.text.trim();
      if (eventText.isNotEmpty) {
        _promptNotification(
          day: day,
          period: period,
          subject: subjectCtrl.text.trim(),
          event: eventText,
        );
      }
    }
  }

  Future<void> _promptNotification({
    required String day,
    required String period,
    required String subject,
    required String event,
  }) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active,
                color: Color(0xFFE91E63), size: 28),
            SizedBox(width: 10),
            Text('تذكير بالحدث'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$event — $subject',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('متى تريد التذكير؟',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            _choiceBtn(ctx, 'بعد ساعة', '1h'),
            _choiceBtn(ctx, 'بعد 24 ساعة', '24h'),
            _choiceBtn(ctx, 'بعد 3 أيام', '3d'),
            _choiceBtn(ctx, 'بعد أسبوع', '1w'),
            _choiceBtn(ctx, 'وقت مخصص', 'custom'),
            _choiceBtn(ctx, 'بدون تذكير', 'skip'),
          ],
        ),
      ),
    );

    if (choice == null || choice == 'skip') return;

    DateTime scheduled;

    if (choice == 'custom') {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (picked == null) return;
      if (!mounted) return;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time == null) return;

      scheduled =
          DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
    } else if (choice == '1h') {
      scheduled = DateTime.now().add(const Duration(hours: 1));
    } else if (choice == '24h') {
      scheduled = DateTime.now().add(const Duration(hours: 24));
    } else if (choice == '3d') {
      scheduled = DateTime.now().add(const Duration(days: 3));
    } else {
      scheduled = DateTime.now().add(const Duration(days: 7));
    }

    final id = await NotificationService().scheduleNotification(
      title: '🔔 $event — $subject',
      body: 'تذكير: $event في مادة $subject (حصة $period، $day)',
      scheduledDate: scheduled,
    );

    // حفظ الإشعار
    _schedule[day]![period]!['notifId'] = id;
    _schedule[day]![period]!['notifTime'] = scheduled.toIso8601String();
    await _saveSchedule();

    if (!mounted) return;
    showKitabiSnack(
      context,
      '✅ سيصلك إشعار في ${_formatDateTime(scheduled)}',
    );
  }

  Widget _choiceBtn(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(ctx, value),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.centerRight,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime d) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${d.day} ${months[d.month - 1]} - ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _clearPeriod(String day, String period) async {
    _schedule[day]?.remove(period);
    await _saveSchedule();
    if (mounted) setState(() {});
  }

  Future<void> _clearDay(String day) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('مسح جدول $day؟'),
        content: const Text('سيتم مسح جميع الحصص لهذا اليوم.'),
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
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _schedule.remove(day);
      await _saveSchedule();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('جدول الحصص 📅',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'مسح اليوم',
            onPressed: () => _clearDay(_days[_selectedDay]),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) => _buildDayView(day)).toList(),
      ),
    );
  }

  Widget _buildDayView(String day) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _periods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final period = _periods[i];
        return _buildPeriodCard(day, period);
      },
    );
  }

  Widget _buildPeriodCard(String day, String period) {
    final data = _getPeriod(day, period);
    final subject = data?['subject']?.toString() ?? '';
    final time = data?['time']?.toString() ??
        _defaultTimes[int.parse(period) - 1];
    final event = data?['event']?.toString() ?? '';
    final hasEvent = event.isNotEmpty;
    final isEmpty = subject.isEmpty;

    return GestureDetector(
      onTap: () => _openPeriodDialog(day, period),
      onLongPress: () => _clearPeriod(day, period),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isEmpty
              ? Colors.grey.shade50
              : (hasEvent ? const Color(0xFFFFF3E0) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEmpty
                ? Colors.grey.shade200
                : (hasEvent
                    ? const Color(0xFFEF6C00)
                    : const Color(0xFF1565C0).withOpacity(0.2)),
            width: isEmpty ? 1 : 1.5,
          ),
          boxShadow: isEmpty
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: isEmpty
                    ? LinearGradient(colors: [
                        Colors.grey.shade300,
                        Colors.grey.shade400,
                      ])
                    : const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                      ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                period,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(time,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEmpty ? 'اضغط لإضافة مادة' : subject,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isEmpty
                          ? Colors.grey.shade500
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (hasEvent) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF6C00).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event,
                              size: 12, color: Color(0xFFEF6C00)),
                          const SizedBox(width: 4),
                          Text(
                            event,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFEF6C00),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (data?['notifId'] != null)
              const Icon(Icons.notifications_active,
                  color: Color(0xFFE91E63), size: 22)
            else if (isEmpty)
              const Icon(Icons.add_circle_outline,
                  color: Color(0xFF1565C0), size: 24)
            else
              const Icon(Icons.edit,
                  color: Color(0xFF999999), size: 20),
          ],
        ),
      ),
    );
  }
}
