import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ai_assistant_service.dart';
import '../../theme/app_theme.dart';
import 'assistant_navigation.dart';

class AiAssistantScreen extends StatefulWidget {
  final String userRole;

  const AiAssistantScreen({super.key, required this.userRole});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatTurn> _turns = [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _turns.add(_ChatTurn.user(text));
      _loading = true;
    });
    _scrollToBottom();

    final payload = <Map<String, String>>[];
    for (final t in _turns) {
      if (t.isUser) {
        payload.add({'role': 'user', 'content': t.text});
      } else {
        payload.add({'role': 'assistant', 'content': t.text});
      }
    }

    try {
      final result = await AiAssistantService.sendMessage(payload);
      if (!mounted) return;
      setState(() {
        _turns.add(_ChatTurn.assistant(result.reply));
        _loading = false;
      });
      _scrollToBottom();

      if (result.actions.isNotEmpty) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (final a in result.actions) {
            if (a.type == 'navigate' && a.screen != null) {
              openAssistantTargetScreen(context, a.screen!, widget.userRole);
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Asistent',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _turns.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (_loading && i == _turns.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _bubble(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentGold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '…',
                              style: GoogleFonts.outfit(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        isUser: false,
                      ),
                    ),
                  );
                }
                final turn = _turns[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: _bubble(
                      isUser: turn.isUser,
                      child: Text(
                        turn.text,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          height: 1.35,
                          color: turn.isUser ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Opýtajte sa alebo napr. „otvor faktúry“…',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.bgInput,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.borderDefault),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.borderDefault),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.accentGold.withValues(alpha: 0.8),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.bgPrimary,
                  ),
                  onPressed: _loading ? null : _send,
                  icon: const Icon(Icons.send_rounded, size: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble({required Widget child, required bool isUser}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.88),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isUser ? AppColors.accentGold : AppColors.bgElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: AppColors.borderDefault),
        ),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: child),
      ),
    );
  }
}

class _ChatTurn {
  final bool isUser;
  final String text;

  _ChatTurn.user(this.text) : isUser = true;
  _ChatTurn.assistant(this.text) : isUser = false;
}
