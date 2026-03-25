import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_pilot/models/app_notification.dart';
import 'package:stock_pilot/models/user.dart';
import 'package:stock_pilot/services/Database/database_service.dart';
import 'package:stock_pilot/services/Notifications/notification_service.dart';

class ComposeMessageDialog extends StatefulWidget {
  const ComposeMessageDialog({super.key});

  @override
  State<ComposeMessageDialog> createState() => _ComposeMessageDialogState();
}

class _ComposeMessageDialogState extends State<ComposeMessageDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  MessagePriority _priority = MessagePriority.info;

  List<User> _users = [];
  Set<String> _selected = {};
  bool _allSelected = false;
  bool _loading = true;
  bool _sending = false;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUsername = prefs.getString('current_user_username');
    final users = await DatabaseService().getAllUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  void _toggleAll(bool? value) {
    setState(() {
      _allSelected = value ?? false;
      _selected = _allSelected ? _users.map((u) => u.username).toSet() : {};
    });
  }

  void _toggleUser(String username, bool? value) {
    setState(() {
      if (value == true) {
        _selected.add(username);
      } else {
        _selected.remove(username);
      }
      _allSelected = _selected.length == _users.length;
    });
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zadajte nadpis aj text správy')),
      );
      return;
    }

    if (!_allSelected && _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vyberte aspoň jedného príjemcu')),
      );
      return;
    }

    // Broadcast confirmation
    if (_allSelected) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Odoslať všetkým?'),
          content: const Text('Odoslať správu všetkým používateľom?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Zrušiť'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Odoslať'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _sending = true);

    await NotificationService().createUserMessage(
      senderUsername: _currentUsername ?? '',
      title: title,
      body: body,
      priority: _priority,
      targetUsernames: _allSelected ? null : _selected.toList(),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nová správa'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Nadpis *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyController,
                      maxLength: 500,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Text správy *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Priorita',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<MessagePriority>(
                      segments: const [
                        ButtonSegment(
                          value: MessagePriority.info,
                          label: Text('Info'),
                        ),
                        ButtonSegment(
                          value: MessagePriority.warning,
                          label: Text('Upozornenie'),
                        ),
                        ButtonSegment(
                          value: MessagePriority.urgent,
                          label: Text('Urgentné'),
                        ),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (s) =>
                          setState(() => _priority = s.first),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Príjemcovia',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    CheckboxListTile(
                      title: const Text('Všetci'),
                      value: _allSelected,
                      onChanged: _toggleAll,
                      dense: true,
                    ),
                    const Divider(height: 1),
                    ..._users.map(
                      (u) => CheckboxListTile(
                        title: Text(
                          u.fullName.isNotEmpty ? u.fullName : u.username,
                        ),
                        subtitle: Text(
                          u.username,
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: _selected.contains(u.username),
                        onChanged: (v) => _toggleUser(u.username, v),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: const Text('Zrušiť'),
        ),
        FilledButton(
          onPressed: (_sending || _loading) ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Odoslať'),
        ),
      ],
    );
  }
}
