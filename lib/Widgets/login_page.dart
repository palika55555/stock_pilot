import 'dart:ui';
import 'package:flutter/material.dart';
import '../Screens/Home/Home_screen.dart';
import '../Services/database_service.dart';
import '../Models/user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isObscured = true;
  bool _isLoading = false;
  final DatabaseService _dbService = DatabaseService();

  // Kontroléry pre vstup
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Skúsime nájsť používateľa v DB
      User? user = await _dbService.getUserByUsername(_loginController.text);

      if (mounted) {
        setState(() => _isLoading = false);

        if (user != null && user.password == _passwordController.text) {
          // Navigácia na HomeScreen s reálnymi dátami používateľa
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(user: user),
            ),
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Prihlásený ako ${user.fullName}'),
              backgroundColor: user.role == 'admin' ? Colors.redAccent : Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nesprávny login alebo heslo'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Pozadie s farebnými prechodmi (Gradient)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Dekoratívne kruhy na pozadí pre hĺbku
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(radius: 150, backgroundColor: Colors.white10),
          ),
          
          // 2. Samotný Login Formulár
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inventory_2_rounded, size: 80, color: Colors.white),
                          const SizedBox(height: 16),
                          const Text(
                            "Skladový Systém",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Text(
                            "Prihláste sa pre pokračovanie",
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 40),
                          
                          // Pole pre Login
                          _buildTextField(
                            controller: _loginController,
                            label: "Login",
                            icon: Icons.person_outline,
                            validator: (v) => v!.isEmpty ? "Zadajte login" : null,
                          ),
                          const SizedBox(height: 20),
                          
                          // Pole pre Heslo
                          _buildTextField(
                            controller: _passwordController,
                            label: "Heslo",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            obscureText: _isObscured,
                            onToggleVisibility: () => setState(() => _isObscured = !_isObscured),
                            validator: (v) => v!.length < 4 ? "Heslo musí mať aspoň 4 znaky" : null,
                          ),
                          const SizedBox(height: 40),
                          
                          // Login Tlačidlo s efektom
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.blue[900],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 5,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text("PRIHLÁSIŤ SA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        ],
      ),
    );
  }

  // Pomocný widget pre input polia
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                onPressed: onToggleVisibility,
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}