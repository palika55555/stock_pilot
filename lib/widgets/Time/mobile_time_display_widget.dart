import 'package:flutter/material.dart';
import 'dart:async';

class MobileTimeDisplayWidget extends StatefulWidget {
  const MobileTimeDisplayWidget({super.key});

  @override
  State<MobileTimeDisplayWidget> createState() =>
      _MobileTimeDisplayWidgetState();
}

class _MobileTimeDisplayWidgetState extends State<MobileTimeDisplayWidget> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String hour = _now.hour.toString().padLeft(2, '0');
    final String minute = _now.minute.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, color: Colors.grey[600], size: 16),
          const SizedBox(width: 6),
          Text(
            '$hour:$minute',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
