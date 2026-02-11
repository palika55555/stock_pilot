import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Centrálna služba pre klávesové skratky aplikácie.
/// Definuje všetky skratky na jednom mieste; obrazovky len registrovaním
/// handlerov určia, čo sa pri skratke stane.
class AppShortcutsService {
  AppShortcutsService._();

  // --- Identifikátory akcií (pridávaj ďalšie podľa potreby) ---
  static const String actionClearDatabase = 'clear_database';

  // --- Definície skratiek (LogicalKeySet -> actionId) ---
  static final Map<ShortcutActivator, String> _shortcutMap = {
    LogicalKeySet(
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyB,
    ): actionClearDatabase,
  };

  static final Map<String, void Function(BuildContext)> _handlers = {};

  /// Zaregistruj handler pre danú akciu. Volaj z initState obrazovky.
  static void register(String actionId, void Function(BuildContext) handler) {
    _handlers[actionId] = handler;
  }

  /// Zruš registráciu handlera. Volaj z dispose obrazovky.
  static void unregister(String actionId) {
    _handlers.remove(actionId);
  }

  /// Zavolaj handler pre danú akciu (používa widget Shortcuts/Actions).
  static void invoke(String actionId, BuildContext context) {
    _handlers[actionId]?.call(context);
  }

  /// Vráti mapu skratka -> Intent pre Shortcuts widget.
  static Map<ShortcutActivator, Intent> get shortcuts {
    return _shortcutMap.map(
      (keys, actionId) => MapEntry(keys, _AppShortcutIntent(actionId)),
    );
  }
}

/// Intent nesúci id akcie; používa sa v Shortcuts + Actions.
class _AppShortcutIntent extends Intent {
  final String actionId;
  const _AppShortcutIntent(this.actionId);
}

/// Widget, ktorý obalí strom a zaregistruje všetky skratky z AppShortcutsService.
/// Handler sa vykoná s contextom tohto widgetu (root), takže musíme predať
/// context do invoke. Riešenie: v CallbackAction máme prístup k contextu cez
/// Actions.invoke(context, intent). Takže v Actions potrebujeme context – ten
/// máme v build(BuildContext context) widgetu AppShortcuts. Takže v
/// CallbackAction.onInvoke potrebujeme ten context. Problém je, že
/// CallbackAction je vytvorená v getteri a nemá prístup k contextu.
/// Riešenie: AppShortcuts bude StatefulWidget alebo použijeme builder:
/// Shortcuts(child: Actions(actions: { _AppShortcutIntent: CallbackAction(
///   onInvoke: (intent) { AppShortcutsService.invoke((intent as _AppShortcutIntent).actionId, context); return null; }
/// ) }, child: child)). Ale context v onInvoke nie je ten istý ako build context...
/// V CallbackAction.onInvoke dostaneme len intent. Context musíme dostať inak.
/// Možnosti: 1) GlobalKey<AppShortcutsState> a currentContext 2) Predať context
/// do služby pri registrácii – nie, handler už context potrebuje pri volaní.
/// 3) V Actions, keď sa volá invoke, Flutter predáva context do Action.invoke(context, intent).
/// Takže ak vytvoríme vlastnú Action subclass, dostaneme context! CallbackAction
/// má onInvoke: (intent) => null, ale existuje aj Action.invoke(context, intent).
/// Pozriem sa na to – v Actions widget sa volá action.invoke(context, intent).
/// Takže ak máme CallbackAction s onInvoke: (intent) { ... }, nemáme tam context.
/// Musíme použiť vlastnú Action<Intent> ktorá v invoke(context, intent) zavolá
/// AppShortcutsService.invoke(..., context). Takže vytvoríme vlastnú triedu
/// ktorá extends Action<_AppShortcutIntent> a v invoke(context, intent) zavoláme
/// service.invoke(intent.actionId, context). To znamená, že actions nemôžu byť
/// statický getter na service, ale musia byť vytvorené v build metode widgetu
/// kde máme context. Takže AppShortcuts bude widget ktorý v build vytvorí
/// Shortcuts + Actions s CallbackAction ktorá má prístup k context.
class AppShortcuts extends StatelessWidget {
  final Widget child;

  const AppShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: AppShortcutsService.shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AppShortcutIntent: CallbackAction<_AppShortcutIntent>(
            onInvoke: (intent) {
              AppShortcutsService.invoke(intent.actionId, context);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}
