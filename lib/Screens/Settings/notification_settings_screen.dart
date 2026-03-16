import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../services/Database/database_service.dart';

/// Nastavenia notifikácií: tiché hodiny, interval pripomienky, prah zmeny ceny.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final DatabaseService _db = DatabaseService();
  String? _username;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  int _pendingReminderHours = 24;
  double _priceChangeThresholdPercent = 20.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('current_user_username');
    if (username == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final prefsMap = await _db.getNotificationPreferences(username);
    if (mounted) {
      setState(() {
        _username = username;
        _quietStart = _parseTime(prefsMap?['quiet_hours_start'] as String?);
        _quietEnd = _parseTime(prefsMap?['quiet_hours_end'] as String?);
        _pendingReminderHours = prefsMap?['pending_reminder_hours'] as int? ?? 24;
        _priceChangeThresholdPercent =
            (prefsMap?['price_change_threshold_percent'] as num?)?.toDouble() ?? 20.0;
        _loading = false;
      });
    }
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null || s.length < 5) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_username == null) return;
    await _db.saveNotificationPreferences(
      _username!,
      quietHoursStart: _quietStart != null ? _formatTime(_quietStart!) : null,
      quietHoursEnd: _quietEnd != null ? _formatTime(_quietEnd!) : null,
      pendingReminderHours: _pendingReminderHours,
      priceChangeThresholdPercent: _priceChangeThresholdPercent,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nastavenia notifikácií uložené'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _pickQuietStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _quietStart ?? const TimeOfDay(hour: 22, minute: 0),
    );
    if (picked != null && mounted) setState(() => _quietStart = picked);
  }

  Future<void> _pickQuietEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _quietEnd ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null && mounted) setState(() => _quietEnd = picked);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nastavenia notifikácií')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Nastavenia notifikácií'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Uložiť'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Tiché hodiny (žiadne e-mailové notifikácie)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickQuietStart,
                  child: Text(_quietStart != null ? _formatTime(_quietStart!) : 'Od (napr. 22:00)'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickQuietEnd,
                  child: Text(_quietEnd != null ? _formatTime(_quietEnd!) : 'Do (napr. 07:00)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Pripomienka: príjemka čaká na schválenie (hodiny)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _pendingReminderHours.toDouble(),
            min: 1,
            max: 72,
            divisions: 71,
            label: '$_pendingReminderHours h',
            onChanged: (v) => setState(() => _pendingReminderHours = v.round()),
          ),
          Text('Interval: $_pendingReminderHours hodín', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 24),
          const Text(
            'Upozornenie na zmenu ceny: prah (%)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _priceChangeThresholdPercent,
            min: 5,
            max: 50,
            divisions: 9,
            label: '${_priceChangeThresholdPercent.toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _priceChangeThresholdPercent = v),
          ),
          Text(
            'Upozorniť pri zmene ceny o ${_priceChangeThresholdPercent.toStringAsFixed(0)}% oproti poslednému nákupu',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
