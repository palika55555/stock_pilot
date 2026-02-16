import 'package:flutter/material.dart';
import '../../services/Database/database_service.dart';
import '../../models/user.dart';
import '../../screens/Home/Home_screen.dart';
import '../../widgets/Common/standard_text_field.dart';
import '../../widgets/Common/purple_button.dart';

/// Zobrazí sa pri spustení aplikácie, ak v databáze ešte nie je žiadny používateľ.
/// Umožní vytvoriť prvého používateľa a následne vstúpiť do aplikácie.
class CreateFirstUserScreen extends StatefulWidget {
  final RouteObserver<ModalRoute<void>>? routeObserver;

  const CreateFirstUserScreen({super.key, this.routeObserver});

  @override
  State<CreateFirstUserScreen> createState() => _CreateFirstUserScreenState();
}

class _CreateFirstUserScreenState extends State<CreateFirstUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController(text: 'admin');
  final TextEditingController _nameController = TextEditingController(text: 'Administrátor');
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(text: 'admin@stockpilot.sk');
  final TextEditingController _phoneController = TextEditingController(text: '+421 ');
  final TextEditingController _deptController = TextEditingController(text: 'Vedenie');
  bool _isLoading = false;

  Future<void> _createUserAndEnter() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final dbService = DatabaseService();
        final user = User(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          role: 'admin',
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          department: _deptController.text.trim(),
          avatarUrl: 'https://i.pravatar.cc/150?u=${_usernameController.text}',
          joinDate: DateTime.now(),
        );

        await dbService.insertUser(user);

        // Načítame používateľa s ID z DB (insertUser vráti id, ale User z toMap ho nemusí mať)
        final createdUser = await dbService.getUserByUsername(user.username);
        if (createdUser == null) {
          throw Exception('Používateľ sa nepodarilo načítať po vytvorení.');
        }

        if (mounted) {
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
              content: Text('Vitajte, ${createdUser.fullName}. Prvý používateľ bol vytvorený.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chyba pri vytváraní používateľa: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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
                        Icons.person_add_rounded,
                        size: 60,
                        color: Colors.indigo,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Vytvorte prvého používateľa',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'V databáze ešte nie je žiadny účet. Vyplňte údaje a vstúpte do aplikácie.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
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
                              validator: (v) => v!.length < 4 ? 'Minimálne 4 znaky' : null,
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
                      const SizedBox(height: 32),
                      PurpleButton(
                        text: 'VYTVORIŤ A VSTÚPIŤ DO APLIKÁCIE',
                        isLoading: _isLoading,
                        onPressed: _createUserAndEnter,
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
