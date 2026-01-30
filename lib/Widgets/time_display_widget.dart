import 'package:flutter/material.dart';
import 'dart:async';

class TimeDisplayWidget extends StatefulWidget {
  const TimeDisplayWidget({super.key});

  @override
  State<TimeDisplayWidget> createState() => _TimeDisplayWidgetState();
}

class _TimeDisplayWidgetState extends State<TimeDisplayWidget> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    
    final days = ['Pon', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Máj', 'Jún', 'Júl', 'Aug', 'Sep', 'Okt', 'Nov', 'Dec'];
    final dateString = "${days[_now.weekday - 1]}, ${_now.day}. ${months[_now.month - 1]}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text(
                  "$hour:$minute",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2D3436)),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
          Text(
            dateString.toUpperCase(),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.blueAccent.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}