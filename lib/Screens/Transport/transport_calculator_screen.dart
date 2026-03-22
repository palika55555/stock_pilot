import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/transport/transport_calculator_theme.dart';
import '../../widgets/transport/transport_calculator_widget.dart';

class TransportCalculatorScreen extends StatelessWidget {
  const TransportCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Výpočet nákladov na dopravu',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: TransportCalculatorTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: TransportCalculatorTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    TransportCalculatorTheme.surfaceCard.withOpacity(0.92),
                    TransportCalculatorTheme.bgDeep.withOpacity(0.88),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: TransportCalculatorTheme.accentAmber.withOpacity(0.22),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: const TransportCalculatorWidget(),
    );
  }
}
