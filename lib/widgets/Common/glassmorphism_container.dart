import 'dart:ui';
import 'package:flutter/material.dart';

/// Znovupoužiteľný Glassmorphism container widget
/// Používa sa na vytvorenie skleneného efektu s blur a priehľadnosťou
class GlassmorphismContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blurSigma;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const GlassmorphismContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 24.0,
    this.blurSigma = 20.0,
    this.borderColor,
    this.borderWidth = 1.0,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient:
                gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.22),
                    Colors.white.withOpacity(0.07),
                  ],
                ),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.35),
              width: borderWidth,
            ),
            boxShadow:
                boxShadow ??
                [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                    spreadRadius: -2,
                  ),
                ],
          ),
          child: child,
        ),
      ),
    );
  }
}
