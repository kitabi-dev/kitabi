import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============ نموذج إحصائيات المستخدم ============
class UserStats {
  static Future<Map<String, int>> get() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'points': prefs.getInt('user_points') ?? 0,
      'level': prefs.getInt('user_level') ?? 1,
      'achievements': prefs.getInt('user_achievements') ?? 0,
      'lessons': prefs.getInt('user_lessons') ?? 0,
    };
  }

  // إضافة نقاط عند فعل معين
  static Future<void> addPoints(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('user_points') ?? 0;
    final newVal = current + amount;
    await prefs.setInt('user_points', newVal);

    // حساب المستوى تلقائياً (كل 100 نقطة = مستوى)
    final level = (newVal ~/ 100) + 1;
    await prefs.setInt('user_level', level);

    // الإنجازات: كل مستوى = إنجاز
    await prefs.setInt('user_achievements', level - 1);
  }

  static Future<void> addLesson() async {
    final prefs = await SharedPreferences.getInstance();
    final lessons = (prefs.getInt('user_lessons') ?? 0) + 1;
    await prefs.setInt('user_lessons', lessons);
    await addPoints(10); // كل درس = 10 نقاط
  }
}

// ============ إعدادات Supabase ============
const String kSupabaseUrl = 'https://vlyfghfoelbbbdljbvcr.supabase.co';
const String kSupabaseAnonKey = 'sb_publishable_d4ZrC9cHXb8YvzyvlRkeCA_GOMtyzgt';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Supabase
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

// وصول سريع لـ Supabase
final supabase = Supabase.instance.client;

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

// ============ Splash ============
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
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    if (!mounted) return;
    if (name == null || name.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
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

// ============ Register ============
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  String? _selectedGrade;
  String? _selectedMuraqaba;

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
      _msg('اكتب اسمك');
      return;
    }
    if (_selectedGrade == null) {
      _msg('اختر صفك');
      return;
    }
    if (_selectedMuraqaba == null) {
      _msg('اختر مراقبتك');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('user_grade', _selectedGrade!);
    await prefs.setString('user_muraqaba', _selectedMuraqaba!);
    // مكافأة ترحيب: 50 نقطة
    final currentPts = prefs.getInt('user_points') ?? 0;
    if (currentPts == 0) {
      await prefs.setInt('user_points', 50);
      await prefs.setInt('user_level', 1);
      await prefs.setInt('user_achievements', 0);
    }

    // حفظ المستخدم في Supabase
    try {
      final existing = await supabase
          .from('users')
          .select('id')
          .eq('name', _nameController.text.trim())
          .limit(1);
      if (existing.isEmpty) {
        await supabase.from('users').insert({
          'name': _nameController.text.trim(),
          'grade': _selectedGrade,
          'muraqaba': _selectedMuraqaba,
          'points': 50,
          'level': 1,
          'achievements': 0,
        });
      }
    } catch (e) {
      debugPrint('Supabase insert error: \$e');
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _msg(String m) => showKitabiSnack(context, m);

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
                        fontSize: 26, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text('سجل بياناتك لتبدأ رحلتك التعليمية',
                    style: TextStyle(fontSize: 15, color: Color(0xFF555555))),
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
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('دخول',
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
        borderSide: BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
      ),
    );
  }
}

// ============ Home Shell with Custom Bottom Nav ============
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
              _navItem(2, Icons.notifications_outlined,
                  Icons.notifications, 'الإشعارات'),
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
                    color: selected ? Colors.white : Colors.white70,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.w400,
                    color: selected ? Colors.white : Colors.white70,
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

// ============ Home Tab (Redesigned) ============
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
          // ===== Header =====
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
                              letterSpacing: 3)),
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

          // ===== Hero Banner =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.75),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ===== 6 مربعات ملوّنة =====
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
                _quickBtn(
                  context,
                  'المكتبة',
                  Icons.menu_book_rounded,
                  const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                  onStartLearning,
                ),
                _quickBtn(
                  context,
                  'الدورات',
                  Icons.school_rounded,
                  const LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF26A69A)]),
                  () => showKitabiSnack(context, 'الدورات — قريباً'),
                ),
                _quickBtn(
                  context,
                  'المعلم الذكي',
                  Icons.smart_toy_rounded,
                  const LinearGradient(
                      colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)]),
                  () => showKitabiSnack(context, 'المعلم الذكي — قريباً'),
                ),
                _quickBtn(
                  context,
                  'المنتدى',
                  Icons.forum_rounded,
                  const LinearGradient(
                      colors: [Color(0xFF283593), Color(0xFF3F51B5)]),
                  () => showKitabiSnack(context, 'المنتدى — قريباً'),
                ),
                _quickBtn(
                  context,
                  'الاختبارات',
                  Icons.assignment_rounded,
                  const LinearGradient(
                      colors: [Color(0xFFEF6C00), Color(0xFFFFA726)]),
                  () => showKitabiSnack(context, 'الاختبارات — قريباً'),
                ),
                _quickBtn(
                  context,
                  'ملاحظاتي',
                  Icons.sticky_note_2_rounded,
                  const LinearGradient(
                      colors: [Color(0xFF00838F), Color(0xFF00ACC1)]),
                  () => showKitabiSnack(context, 'ملاحظاتي — قريباً'),
                ),
                _quickBtn(
                  context,
                  'فيديوهات',
                  Icons.play_circle_fill_rounded,
                  const LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFFEF5350)]),
                  () => showKitabiSnack(context, 'الفيديوهات — قريباً'),
                ),
                _quickBtn(
                  context,
                  'كتب محلولة',
                  Icons.checklist_rtl_rounded,
                  const LinearGradient(
                      colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
                  () => showKitabiSnack(context, 'الكتب المحلولة — قريباً'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ===== أحدث الدروس =====
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('أحدث الدروس',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
          ),
          const SizedBox(height: 12),

          // === بطاقة الدرس الأولى ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.calculate_rounded,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الرياضيات — الفصل الأول',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A))),
                        SizedBox(height: 5),
                        Text('الأساس والغلاف',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF555555))),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Color(0xFF1565C0), size: 22),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // === بطاقة الدرس الثانية ===
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.science_rounded,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('العلوم الطبيعية',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A))),
                        SizedBox(height: 5),
                        Text('مقدمة في الأحياء',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF555555))),
                      ],
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B1FA2).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Color(0xFF7B1FA2), size: 22),
                  ),
                ],
              ),
            ),
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
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ Library Tab (Redesigned) ============
class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  // المواد حسب كل صف
  static const Map<String, List<String>> _subjectsByGrade = {
    'أول ابتدائي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب',
    ],
    'ثاني ابتدائي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب',
    ],
    'ثالث ابتدائي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم',
    ],
    'رابع ابتدائي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
    'خامس ابتدائي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
    'سادس ابتدائي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
    'أول إعدادي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
    'ثاني إعدادي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
    'ثالث إعدادي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
    'أولى ثانوي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
    'ثانية ثانوي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
    'ثالثة ثانوي': [
      'الرياضيات', 'اللغة العربية', 'اللغة الإنجليزية',
      'التربية الإسلامية', 'الحاسوب', 'العلوم', 'الاجتماعيات',
    ],
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
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 4, 20,
                MediaQuery.of(context).padding.bottom + 110),
            itemCount: _grades.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              final g = _grades[i];
              final subjects =
                  _subjectsByGrade[g['name']] ?? const <String>[];
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
                    onTap: () {
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
                                Text(
                                  g['name'],
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${subjects.length} مواد',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF555555),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0)
                                  .withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 14,
                              color: Color(0xFF1565C0),
                            ),
                          ),
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
                        showKitabiSnack(context, '$s — قريباً');
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
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                size: 13,
                                color: color,
                              ),
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

// ============ Notifications ============
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
                            itemBuilder: (context, i) {
                              final n = _notifications[i];
                              return _notifCard(n);
                            },
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
                child: Text(
                  n['title'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            n['body'] ?? '',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF333333),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatDate(n['created_at']),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF888888),
            ),
          ),
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                ),
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

// ============ Account Tab (Redesigned) ============
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
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
                          border: Border.all(color: Colors.white, width: 3),
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
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _grade.isNotEmpty ? _grade : 'طالب',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                    blurRadius: 15,
                  ),
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
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF1A1A1A),
        ),
      ),
      trailing: const Icon(Icons.arrow_back_ios,
          size: 14, color: Color(0xFF555555)),
      onTap: onTap,
    );
  }

  Widget _menuDivider() => const Divider(
      height: 1, indent: 70, endIndent: 15, color: Color(0xFFF0F0F0));
}

// ============ Control Room ============
class ControlRoomScreen extends StatefulWidget {
  const ControlRoomScreen({super.key});
  @override
  State<ControlRoomScreen> createState() => _ControlRoomScreenState();
}

class _ControlRoomScreenState extends State<ControlRoomScreen> {
  final _idController = TextEditingController();
  final _passController = TextEditingController();
  bool _logged = false;

  // قائمة المستخدمين (مؤقتة — لاحقاً من قاعدة البيانات)
  final List<Map<String, String>> _users = [];

  void _login() {
    if (_idController.text.trim() == '0922251374' &&
        _passController.text.trim() == 'العلم نور') {
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

  // ============ شاشة تسجيل الدخول ============
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
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'كلمة السر',
              prefixIcon: const Icon(Icons.lock),
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

  // ============ لوحة التحكم ============
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

        // ===== الشبكة: 2x3 =====
        Row(
          children: [
            Expanded(
              child: _bigCard(
                'المستخدمون',
                '${_users.length}',
                Icons.people_alt_rounded,
                const Color(0xFF1565C0),
                () => _showUsers(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard(
                'رفع الكتب',
                'جديد',
                Icons.upload_file_rounded,
                const Color(0xFF00897B),
                () => showKitabiSnack(context, 'رفع الكتب — قريباً'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bigCard(
                'إرسال إشعار',
                'لكل الطلاب',
                Icons.send_rounded,
                const Color(0xFF7B1FA2),
                () => _showSendNotification(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard(
                'كلمة السر',
                'تغيير',
                Icons.key_rounded,
                const Color(0xFFEF6C00),
                () => _changePassword(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bigCard(
                'الاختبارات',
                'إدارة',
                Icons.assignment_rounded,
                const Color(0xFFD32F2F),
                () => showKitabiSnack(context, 'الاختبارات — قريباً'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bigCard(
                'الإحصائيات',
                'تحليل',
                Icons.bar_chart_rounded,
                const Color(0xFF283593),
                () => showKitabiSnack(context, 'الإحصائيات — قريباً'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ===== قائمة خيارات إضافية =====
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            children: [
              _listItem(Icons.group_add_rounded, 'إدارة المستخدمين',
                  const Color(0xFF1565C0), _showUsers),
              _divider(),
              _listItem(Icons.campaign_rounded, 'إشعار جماعي',
                  const Color(0xFF7B1FA2), _showSendNotification),
              _divider(),
              _listItem(Icons.lock_reset_rounded, 'تغيير كلمة السر',
                  const Color(0xFFEF6C00), _changePassword),
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

  // ============ بطاقة كبيرة ============
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

  // ============ عنصر قائمة ============
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

  // ============ الحوارات ============
  void _showUsers() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
            const SizedBox(height: 20),
            const Text('إدارة المستخدمين',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 20),
            if (_users.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 60, color: Color(0xFF555555)),
                    SizedBox(height: 12),
                    Text('لا يوجد مستخدمون مسجلون بعد',
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF555555))),
                    SizedBox(height: 6),
                    Text('سيظهر هنا كل من يسجل في التطبيق',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF888888))),
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showSendNotification() {
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
                    DropdownMenuItem(
                        value: 'مراقبة', child: Text('مراقبة')),
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
                  if (!mounted) return;
                  showKitabiSnack(
                      context, '✅ تم إرسال الإشعار بنجاح');
                } catch (e) {
                  if (!mounted) return;
                  showKitabiSnack(context, '❌ فشل الإرسال');
                  debugPrint('Send notification error: \$e');
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

  void _changePassword() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'كلمة السر الحالية',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'كلمة السر الجديدة',
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
            onPressed: () {
              if (oldPassCtrl.text.trim() != 'العلم نور') {
                showKitabiSnack(context, 'كلمة السر الحالية خاطئة');
                return;
              }
              if (newPassCtrl.text.trim().length < 4) {
                showKitabiSnack(context, 'كلمة السر قصيرة (4 أحرف على الأقل)');
                return;
              }
              Navigator.pop(dialogCtx);
              showKitabiSnack(context, 'تم تغيير كلمة السر بنجاح');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF6C00),
              foregroundColor: Colors.white,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ============ Custom SnackBar (من اليمين، حواف من اليسار فقط) ============
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
