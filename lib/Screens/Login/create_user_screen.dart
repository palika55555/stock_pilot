import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/Database/database_service.dart';
import '../../services/api_sync_service.dart';
import '../../models/user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/welcome/welcome_reveal_screen.dart';

/// Obrazovka na vytvorenie nového používateľa (volaná z prihlasovacej stránky).
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
  bool _useExistingDb = true;
  String _newUserRole = 'user';
  bool _adminPasswordObscured = true;
  bool _passwordObscured = true;

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
            backgroundColor: AppColors.success,
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
        await syncUserToBackend(createdUser);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (context) => WelcomeRevealScreen(
              user: createdUser,
              routeObserver: widget.routeObserver,
              postHomeSnackText:
                  'Nová databáza vytvorená. Vitajte, ${createdUser.fullName}.',
              postHomeSnackColor: AppColors.success,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba: $e'),
            backgroundColor: AppColors.danger,
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
        color: const Color(0xFF0F0F12),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1F),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.accentGold.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withOpacity(0.1),
                      blurRadius: 36,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.person_add_rounded,
                            size: 44,
                            color: AppColors.accentGold,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Vytvoriť používateľa',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Vyplňte údaje a zvoľte, či má mať používateľ prístup k aktuálnej databáze alebo novú.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'Prístup k databáze',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _RadioOption<bool>(
                            value: true,
                            groupValue: _useExistingDb,
                            title: 'Prístup k existujúcej databáze',
                            subtitle: 'Používateľ bude mať prístup k aktuálnej DB',
                            onChanged: (v) => setState(() => _useExistingDb = true),
                          ),
                          const SizedBox(height: 6),
                          _RadioOption<bool>(
                            value: false,
                            groupValue: _useExistingDb,
                            title: 'Vytvoriť novú databázu',
                            subtitle: 'Vytvorí sa nová DB a používateľ bude jej jediný admin',
                            onChanged: (v) => setState(() {
                              _useExistingDb = false;
                              if (_dbPathController.text.isEmpty) _setDefaultDbPath();
                            }),
                          ),

                          if (_useExistingDb) ...[
                            const SizedBox(height: 20),
                            _FormLabel(text: 'Heslo administrátora'),
                            const SizedBox(height: 8),
                            _FormField(
                              controller: _adminPasswordController,
                              hint: 'Heslo administrátora',
                              obscureText: _adminPasswordObscured,
                              suffix: IconButton(
                                icon: Icon(
                                  _adminPasswordObscured
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _adminPasswordObscured = !_adminPasswordObscured),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(40, 40),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Rola nového používateľa',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF252830),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderDefault),
                              ),
                              child: SegmentedButton<String>(
                                segments: [
                                  ButtonSegment(
                                    value: 'user',
                                    label: Text(
                                      'User (Skladník)',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                                  ),
                                  ButtonSegment(
                                    value: 'admin',
                                    label: Text(
                                      'Admin',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    icon: const Icon(Icons.admin_panel_settings_rounded, size: 18),
                                  ),
                                ],
                                selected: {_newUserRole},
                                onSelectionChanged: (Set<String> selected) {
                                  setState(() => _newUserRole = selected.first);
                                },
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.resolveWith((states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return AppColors.accentGold;
                                    }
                                    return Colors.transparent;
                                  }),
                                  foregroundColor: MaterialStateProperty.resolveWith((states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return const Color(0xFF0F0F12);
                                    }
                                    return AppColors.textSecondary;
                                  }),
                                  padding: const MaterialStatePropertyAll(
                                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  shape: MaterialStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          if (!_useExistingDb) ...[
                            const SizedBox(height: 16),
                            _FormLabel(text: 'Priečinok pre novú databázu'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _FormField(
                                    controller: _dbPathController,
                                    hint: 'Cesta k priečinku',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: _pickDirectory,
                                  icon: const Icon(Icons.folder_open_rounded),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.accentGold,
                                    foregroundColor: const Color(0xFF0F0F12),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),
                          Divider(color: AppColors.borderDefault, height: 1),
                          const SizedBox(height: 20),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _FormLabel(text: 'Login (Username)'),
                                    const SizedBox(height: 8),
                                    _FormField(
                                      controller: _usernameController,
                                      hint: 'Login',
                                      validator: (v) =>
                                          v!.trim().isEmpty ? 'Zadajte login' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _FormLabel(text: 'Heslo'),
                                    const SizedBox(height: 8),
                                    _FormField(
                                      controller: _passwordController,
                                      hint: 'Heslo',
                                      obscureText: _passwordObscured,
                                      suffix: IconButton(
                                        icon: Icon(
                                          _passwordObscured
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                            () => _passwordObscured = !_passwordObscured),
                                        style: IconButton.styleFrom(
                                          minimumSize: const Size(40, 40),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      validator: (v) =>
                                          v!.length < 4 ? 'Min. 4 znaky' : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FormLabel(text: 'Celé meno'),
                          const SizedBox(height: 8),
                          _FormField(
                            controller: _nameController,
                            hint: 'Celé meno',
                            validator: (v) => v!.trim().isEmpty ? 'Zadajte meno' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _FormLabel(text: 'Email'),
                                    const SizedBox(height: 8),
                                    _FormField(
                                      controller: _emailController,
                                      hint: 'Email',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) =>
                                          v!.trim().isEmpty ? 'Zadajte email' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _FormLabel(text: 'Telefón'),
                                    const SizedBox(height: 8),
                                    _FormField(
                                      controller: _phoneController,
                                      hint: 'Telefón',
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _FormLabel(text: 'Oddelenie / Pozícia'),
                          const SizedBox(height: 8),
                          _FormField(
                            controller: _deptController,
                            hint: 'Oddelenie',
                          ),
                          const SizedBox(height: 28),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentGold,
                                foregroundColor: const Color(0xFF0F0F12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF0F0F12),
                                      ),
                                    )
                                  : Text(
                                      _useExistingDb
                                          ? 'Vytvoriť používateľa'
                                          : 'Vytvoriť DB a vstúpiť',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Späť na prihlásenie',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _RadioOption<T> extends StatelessWidget {
  final T value;
  final T groupValue;
  final String title;
  final String subtitle;
  final ValueChanged<T?> onChanged;

  const _RadioOption({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentGold.withOpacity(0.12)
              : const Color(0xFF252830),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accentGold.withOpacity(0.5) : AppColors.borderDefault,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: AppColors.accentGold,
              fillColor: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) return AppColors.accentGold;
                return AppColors.textSecondary;
              }),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.phone
          ? [FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-]'))]
          : null,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF252830),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
      ),
    );
  }
}
