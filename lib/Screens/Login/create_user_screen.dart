import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/Database/database_service.dart';
import '../../services/api_sync_service.dart';
import '../../models/user.dart';
import '../../screens/Home/Home_screen.dart';
import '../../widgets/Common/standard_text_field.dart';
import '../../widgets/Common/purple_button.dart';

/// Obrazovka na vytvorenie nového používateľa (volaná z prihlasovacej stránky).
/// Umožní zvoliť: prístup k existujúcej DB alebo vytvorenie novej databázy.
class CreateUserScreen extends StatefulWidget {
  final RouteObserver<ModalRoute<void>>? routeObserver;

  const CreateUserScreen({super.key, this.routeObserver});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController(text: '');
  final TextEditingController _nameController = TextEditingController(text: '');
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(text: '');
  final TextEditingController _phoneController = TextEditingController(text: '+421 ');
  final TextEditingController _deptController = TextEditingController(text: '');
  final TextEditingController _dbPathController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();
  bool _isLoading = false;

  /// true = prístup k existujúcej DB, false = vytvoriť novú DB
  bool _useExistingDb = true;
  /// Rola nového používateľa (len pri existujúcej DB)
  String _newUserRole = 'user';

  @override
  void initState() {
    super.initState();
    if (!_useExistingDb) _setDefaultDbPath();
  }

  Future<void> _setDefaultDbPath() async {
    final dbService = DatabaseService();
    final defaultPath = await dbService.getDefaultDatabasePath();
    if (mounted) setState(() => _dbPathController.text = defaultPath);
  }

  Future<void> _pickDirectory() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null && mounted) {
      setState(() => _dbPathController.text = result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_useExistingDb && _dbPathController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadajte priečinok pre novú databázu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_useExistingDb && _adminPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadajte heslo administrátora.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbService = DatabaseService();
      final newRole = _useExistingDb ? _newUserRole : 'admin';
      final user = User(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        role: newRole,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        department: _deptController.text.trim(),
        avatarUrl: 'https://i.pravatar.cc/150?u=${_usernameController.text}',
        joinDate: DateTime.now(),
      );

      if (_useExistingDb) {
        final adminUser = await dbService.getFirstAdminUser();
        if (adminUser == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('V databáze nie je žiadny administrátor.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        if (adminUser.password != _adminPasswordController.text) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Nesprávne heslo administrátora.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        await dbService.insertUser(user);
        syncUserToBackend(user);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Používateľ "${user.fullName}" bol vytvorený. Môžete sa prihlásiť.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        final prefs = await SharedPreferences.getInstance();
        final path = _dbPathController.text.trim();
        await prefs.setString('db_path', path);
        await dbService.setCustomPath(path);
        await dbService.initializeWithAdmin(user);

        final createdUser = await dbService.getUserByUsername(user.username);
        if (createdUser == null) {
          throw Exception('Používateľ sa nepodarilo načítať po vytvorení.');
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              user: createdUser,
              routeObserver: widget.routeObserver,
            ),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nová databáza vytvorená. Vitajte, ${createdUser.fullName}.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    _dbPathController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.person_add_rounded, size: 56, color: Colors.indigo),
                      const SizedBox(height: 12),
                      const Text(
                        'Vytvoriť používateľa',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vyplňte údaje a zvoľte, či má mať používateľ prístup k aktuálnej databáze alebo novú.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Výber: existujúca DB vs nová DB
                      const Text('Prístup k databáze', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      RadioListTile<bool>(
                        title: const Text('Prístup k existujúcej databáze'),
                        subtitle: const Text('Používateľ bude mať prístup k aktuálnej DB'),
                        value: true,
                        groupValue: _useExistingDb,
                        onChanged: (v) => setState(() {
                          _useExistingDb = true;
                        }),
                      ),
                      RadioListTile<bool>(
                        title: const Text('Vytvoriť novú databázu'),
                        subtitle: const Text('Vytvorí sa nová DB a používateľ bude jej jediný admin'),
                        value: false,
                        groupValue: _useExistingDb,
                        onChanged: (v) => setState(() {
                          _useExistingDb = false;
                          if (_dbPathController.text.isEmpty) _setDefaultDbPath();
                        }),
                      ),
                      if (_useExistingDb) ...[
                        const SizedBox(height: 16),
                        StandardTextField(
                          controller: _adminPasswordController,
                          labelText: 'Heslo administrátora',
                          icon: Icons.admin_panel_settings,
                          isPassword: true,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        const Text('Rola nového používateľa', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'user', label: Text('User (Skladník)')),
                            ButtonSegment(value: 'admin', label: Text('Admin (Administrátor)')),
                          ],
                          selected: {_newUserRole},
                          onSelectionChanged: (Set<String> selected) {
                            setState(() => _newUserRole = selected.first);
                          },
                        ),
                      ],
                      if (!_useExistingDb) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: StandardTextField(
                                controller: _dbPathController,
                                labelText: 'Priečinok pre novú databázu',
                                icon: Icons.folder,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _pickDirectory,
                              icon: const Icon(Icons.folder_open),
                              style: IconButton.styleFrom(backgroundColor: Colors.indigo),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: StandardTextField(
                              controller: _usernameController,
                              labelText: 'Login (Username)',
                              icon: Icons.alternate_email,
                              validator: (v) => v!.trim().isEmpty ? 'Zadajte login' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StandardTextField(
                              controller: _passwordController,
                              labelText: 'Heslo',
                              icon: Icons.lock,
                              isPassword: true,
                              obscureText: true,
                              validator: (v) => v!.length < 4 ? 'Min. 4 znaky' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StandardTextField(
                        controller: _nameController,
                        labelText: 'Celé meno',
                        icon: Icons.person,
                        validator: (v) => v!.trim().isEmpty ? 'Zadajte meno' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: StandardTextField(
                              controller: _emailController,
                              labelText: 'Email',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v!.trim().isEmpty ? 'Zadajte email' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StandardTextField(
                              controller: _phoneController,
                              labelText: 'Telefón',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      StandardTextField(
                        controller: _deptController,
                        labelText: 'Oddelenie / Pozícia',
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 24),
                      PurpleButton(
                        text: _useExistingDb ? 'VYTVORIŤ POUŽÍVATEĽA' : 'VYTVORIŤ DB A VSTÚPIŤ',
                        isLoading: _isLoading,
                        onPressed: _submit,
                        backgroundColor: Colors.indigo,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Späť na prihlásenie'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
