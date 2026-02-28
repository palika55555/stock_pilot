import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/Database/database_service.dart';
import '../../models/user.dart';
import '../login/login_page.dart';
import '../../widgets/common/standard_text_field.dart';
import '../../widgets/common/purple_button.dart';

class FirstStartupScreen extends StatefulWidget {
  const FirstStartupScreen({super.key});

  @override
  State<FirstStartupScreen> createState() => _FirstStartupScreenState();
}

class _FirstStartupScreenState extends State<FirstStartupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _adminUsernameController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _adminNameController = TextEditingController(
    text: 'Pavol Administrátor',
  );
  final TextEditingController _adminPasswordController =
      TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController(
    text: 'admin@stockpilot.sk',
  );
  final TextEditingController _adminPhoneController = TextEditingController(
    text: '+421 ',
  );
  final TextEditingController _adminDeptController = TextEditingController(
    text: 'Vedenie',
  );
  final TextEditingController _dbPathController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setDefaultPath();
  }

  Future<void> _setDefaultPath() async {
    final dbService = DatabaseService();
    final defaultPath = await dbService.getDefaultDatabasePath();
    setState(() {
      _dbPathController.text = defaultPath;
    });
  }

  Future<void> _pickDirectory() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _dbPathController.text = result;
      });
    }
  }

  Future<void> _completeSetup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final prefs = await SharedPreferences.getInstance();

        // Uložíme cestu k DB do nastavení
        await prefs.setString('db_path', _dbPathController.text);

        // Inicializujeme DB na novej ceste
        final dbService = DatabaseService();
        await dbService.setCustomPath(_dbPathController.text);

        // Vytvoríme admin používateľa s novými údajmi
        final adminUser = User(
          username: _adminUsernameController.text,
          password: _adminPasswordController.text,
          fullName: _adminNameController.text,
          role: 'admin',
          email: _adminEmailController.text,
          phone: _adminPhoneController.text,
          department: _adminDeptController.text,
          avatarUrl:
              'https://i.pravatar.cc/150?u=${_adminUsernameController.text}',
          joinDate: DateTime.now(),
        );

        // Inicializujeme DB s týmto adminom
        await dbService.initializeWithAdmin(adminUser);

        // Označíme setup za dokončený
        await prefs.setBool('is_first_run', false);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chyba pri nastavovaní: $e'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 10),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 60,
                        color: Colors.indigo,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Prvotné nastavenie",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Nastavte si údaje administrátora a úložisko",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Expanded(
                            child: StandardTextField(
                              controller: _adminUsernameController,
                              labelText: 'Login (Username)',
                              icon: Icons.alternate_email,
                              validator: (v) =>
                                  v!.isEmpty ? 'Zadajte login' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StandardTextField(
                              controller: _adminPasswordController,
                              labelText: 'Heslo',
                              icon: Icons.lock,
                              isPassword: true,
                              obscureText: true,
                              validator: (v) =>
                                  v!.length < 4 ? 'Minimálne 4 znaky' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      StandardTextField(
                        controller: _adminNameController,
                        labelText: 'Celé meno administrátora',
                        icon: Icons.person,
                        validator: (v) => v!.isEmpty ? 'Zadajte meno' : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: StandardTextField(
                              controller: _adminEmailController,
                              labelText: 'Email',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                                  v!.isEmpty ? 'Zadajte email' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: StandardTextField(
                              controller: _adminPhoneController,
                              labelText: 'Telefón',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      StandardTextField(
                        controller: _adminDeptController,
                        labelText: 'Oddelenie / Pozícia',
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 24),

                      const Divider(),
                      const SizedBox(height: 24),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Úložisko databázy",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: StandardTextField(
                              controller: _dbPathController,
                              labelText: 'Priečinok pre DB',
                              icon: Icons.folder,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _pickDirectory,
                            icon: const Icon(Icons.folder_open),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      PurpleButton(
                        text: "DOKONČIŤ NASTAVENIE",
                        isLoading: _isLoading,
                        onPressed: _completeSetup,
                        backgroundColor: Colors.indigo,
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
