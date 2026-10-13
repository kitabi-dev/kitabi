import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KitabiApp());
}

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
              child: const Icon(
                Icons.menu_book_rounded,
                size: 80,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'KITABI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'كتابي',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
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
    'مراقبة طرابلس',
    'مراقبة بنغازي',
    'مراقبة مصراتة',
    'مراقبة الزاوية',
    'مراقبة قصر الأخيار',
    'مراقبة الخمس',
    'مراقبة زليتن',
    'مراقبة سبها',
    'مراقبة البيضاء',
    'مراقبة درنة',
  ];

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showMsg('اكتب اسمك');
      return;
    }
    if (_selectedGrade == null) {
      _showMsg('اختر صفك');
      return;
    }
    if (_selectedMuraqaba == null) {
      _showMsg('اختر مراقبتك');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('user_grade', _selectedGrade!);
    await prefs.setString('user_muraqaba', _selectedMuraqaba!);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _showMsg(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.person_add_alt_1,
                size: 80, color: Color(0xFF1565C0)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'الاسم',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              decoration: InputDecoration(
                labelText: 'الصف الدراسي',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.school),
              ),
              items: _grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedGrade = v),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedMuraqaba,
              decoration: InputDecoration(
                labelText: 'المراقبة',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.location_city),
              ),
              items: _muraqabat
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMuraqaba = v),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'دخول',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final List<Widget> _tabs = const [
    HomeTab(),
    LibraryTab(),
    NotificationsTab(),
    AccountTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'المكتبة',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'الإشعارات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KITABI'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
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
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 45),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تعلّم مع معلمك AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'قريباً في الإصدار 0.2',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book,
                        size: 60, color: Color(0xFF1565C0)),
                    const SizedBox(height: 15),
                    const Text(
                      'المكتبة',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'كل الكتب في مكان واحد',
                      style: TextStyle(color: Colors.grey),
                    ),
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

class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  static const List<String> _grades = [
    'أول ابتدائي', 'ثاني ابتدائي', 'ثالث ابتدائي',
    'رابع ابتدائي', 'خامس ابتدائي', 'سادس ابتدائي',
    'أول إعدادي', 'ثاني إعدادي', 'ثالث إعدادي',
    'أولى ثانوي', 'ثانية ثانوي', 'ثالثة ثانوي',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المكتبة'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: _grades.length,
        itemBuilder: (context, i) {
          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_grades[i])),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.school,
                      size: 45, color: Color(0xFF1565C0)),
                  const SizedBox(height: 10),
                  Text(
                    _grades[i],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 80, color: Colors.grey),
            SizedBox(height: 15),
            Text('لا توجد إشعارات حالياً',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  String _name = '';
  String _grade = '';
  String _muraqaba = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? '';
      _grade = prefs.getString('user_grade') ?? '';
      _muraqaba = prefs.getString('user_muraqaba') ?? '';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF1565C0),
                    child: Text(
                      _name.isNotEmpty ? _name[0] : '؟',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('الصف: $_grade'),
                  Text('المراقبة: $_muraqaba'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('عن التطبيق'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
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
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('غرفة التحكم'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ControlRoomScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('تسجيل خروج',
                  style: TextStyle(color: Colors.red, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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

  void _login() {
    if (_idController.text.trim() == '0922251374' &&
        _passController.text.trim() == 'العلم نور') {
      setState(() => _logged = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات خاطئة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('غرفة التحكم'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: _logged ? _buildPanel() : _buildLogin(),
    );
  }

  Widget _buildLogin() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.admin_panel_settings,
              size: 80, color: Color(0xFF1565C0)),
          const SizedBox(height: 30),
          TextField(
            controller: _idController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'الرقم',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'كلمة السر',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('دخول',
                  style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        Card(
          color: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const ListTile(
            leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('مرحباً بك في غرفة التحكم'),
            subtitle: Text('v0.1 — قريباً المزيد من المميزات'),
          ),
        ),
        const SizedBox(height: 15),
        _card('المستخدمون', 'عرض وإدارة المستخدمين', Icons.people),
        _card('رفع الكتب', 'إضافة كتب جديدة', Icons.upload_file),
        _card('إرسال إشعار', 'إرسال إشعار للطلاب', Icons.send),
        _card('تغيير كلمة السر', 'تحديث كلمة سر الغرفة', Icons.key),
      ],
    );
  }

  Widget _card(String title, String sub, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1565C0)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title — قريباً')),
          );
        },
      ),
    );
  }
}
