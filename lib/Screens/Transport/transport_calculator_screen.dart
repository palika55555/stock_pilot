import 'package:flutter/material.dart';
import '../../widgets/transport/transport_calculator_widget.dart';

class TransportCalculatorScreen extends StatelessWidget {
  const TransportCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výpočet nákladov na dopravu'),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
      ),
      body: const TransportCalculatorWidget(),
    );
  }
}
