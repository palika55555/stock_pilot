import 'dart:io' show File;
import 'dart:ui';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Providers/theme_locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/Database/database_service.dart';
import '../../services/auto_lock_service.dart';
import '../../services/api_sync_service.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import 'company_edit_screen.dart';
import 'receipt_pdf_style_screen.dart';
import 'product_kinds_screen.dart';
import 'notification_settings_screen.dart';
import 'oberon_import_screen.dart';
import 'monthly_closing_screen.dart';

class SettingsPage extends StatefulWidget {
  /// Rola prihláseného používateľa ('admin' alebo 'user'). Určuje napr. zobrazenie položky „Vymazať dáta z DB”.
  final String userRole;

  const SettingsPage({super.key, required this.userRole});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String? _dbPath;
  int _autoLockMinutes = 0;

  static const List<int> _autoLockOptions = [0, 5, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final lockMinutes = await AutoLockService.loadTimeout();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _dbPath = prefs.getString('db_path');
      _autoLockMinutes = lockMinutes;
    });
  }

  String _autoLockLabel(int minutes) {
    if (minutes == 0) return 'Vypnuté';
    if (minutes == 60) return '1 hodina';
    return '$minutes minút';
  }

  Future<void> _showAutoLockDialog() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-odhlásenie'),
        children: _autoLockOptions.map((m) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, m),
            child: Row(
              children: [
                Expanded(child: Text(_autoLockLabel(m))),
                if (m == _autoLockMinutes)
                  Icon(Icons.check, color: AppColors.accentGold, size: 20),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null) return;
    await AutoLockService.saveTimeout(selected);
    AutoLockService.instance.updateTimeout(selected);
    setState(() => _autoLockMinutes = selected);
    if (!mounted) return;
    if (selected > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pri nečinnosti budete po ${_autoLockLabel(selected)} automaticky odhlásení. '
            'Minútu pred odhlásením zobrazíme upozornenie – môžete predĺžiť reláciu.',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Automatické odhlásenie po nečinnosti je vypnuté.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<String?> _showCodePrompt({
    required String title,
    required String hint,
    bool obscure = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušiť')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Potvrdiť')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _show2faDialog() async {
    final token = await getBackendTokenAsync();
    if (token == null || token.isEmpty || !mounted) return;
    final statusRes = await http.get(
      Uri.parse('${AppConfig.apiBase}/auth/2fa/status'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final statusData = jsonDecode(statusRes.body) as Map<String, dynamic>;
    final enabled = statusRes.statusCode == 200 && statusData['enabled'] == true;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('2FA status'),
        content: Text(enabled ? '2FA je aktívne.' : '2FA aktivujete pri ďalšom prihlásení.'),
        actions: [
          if (enabled)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final code = await _showCodePrompt(title: 'TOTP kód', hint: '123456 alebo XXXX-XXXX');
                if (code == null || code.isEmpty || !mounted) return;
                final regenRes = await http.post(
                  Uri.parse('${AppConfig.apiBase}/auth/2fa/backup-codes/regenerate'),
                  headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                  body: jsonEncode({
                    if (code.contains('-')) 'backupCode': code else 'totpCode': code,
                  }),
                );
                final regenData = jsonDecode(regenRes.body) as Map<String, dynamic>;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(regenRes.statusCode == 200
                        ? 'Backup kódy regenerované: ${(regenData['backupCodes'] as List?)?.join(', ') ?? ''}'
                        : (regenData['error']?.toString() ?? 'Operácia zlyhala')),
                  ),
                );
              },
              child: const Text('Regenerovať backup kódy'),
            ),
          if (enabled)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final password = await _showCodePrompt(title: 'Heslo', hint: '••••••', obscure: true);
                if (password == null || password.isEmpty || !mounted) return;
                final code = await _showCodePrompt(title: 'TOTP/backup kód', hint: '123456 alebo XXXX-XXXX');
                if (code == null || code.isEmpty || !mounted) return;
                final disableRes = await http.post(
                  Uri.parse('${AppConfig.apiBase}/auth/2fa/disable'),
                  headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                  body: jsonEncode({
                    'password': password,
                    if (code.contains('-')) 'backupCode': code else 'totpCode': code,
                  }),
                );
                final disableData = jsonDecode(disableRes.body) as Map<String, dynamic>;
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(disableRes.statusCode == 200
                        ? '2FA bolo vypnuté.'
                        : (disableData['error']?.toString() ?? 'Vypnutie zlyhalo')),
                  ),
                );
              },
              child: const Text('Vypnúť 2FA'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zavrieť')),
        ],
      ),
    );
  }

  Future<void> _saveNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _showClearDatabaseDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearDatabase),
        content: Text(l10n.clearDatabaseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await DatabaseService().clearAllData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.clearDatabaseDone)),
    );
  }

  /// Admin: vytvorí zálohu DB a umožní ju stiahnuť (uložiť súbor).
  Future<void> _downloadDatabaseBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final dbPath = await DatabaseService().getDatabasePath();
    if (dbPath == null || dbPath.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupDatabaseError)),
        );
      }
      return;
    }
    final file = File(dbPath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupDatabaseError)),
        );
      }
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'stock_pilot_zaloha_$dateStr.db';
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.backupDatabaseDownload,
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['db'],
      );
      if (!context.mounted) return;
      if (savedPath != null && savedPath.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupDatabaseSuccess)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.backupDatabaseError} $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeLocaleProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bgPrimary,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard.withOpacity(0.9),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.borderSubtle,
                    width: 1,
                  ),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                title: Text(
                  l10n.settings,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;
          final categories = _buildSettingsCategories(
            context,
            l10n,
            themeProvider,
          );
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 28 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),
                  _buildSettingsIntro(context, l10n),
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: categories.take(3).toList(),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: categories.skip(3).toList(),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: categories,
                    ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getLanguageDisplayName(String code, AppLocalizations l10n) {
    switch (code) {
      case 'sk':
        return l10n.languageSlovak;
      case 'cs':
        return l10n.languageCzech;
      case 'en':
        return l10n.languageEnglish;
      default:
        return code;
    }
  }

  Widget _buildSettingsIntro(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgElevated,
              AppColors.bgCard.withValues(alpha: 0.92),
            ],
          ),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGoldSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentGold.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentGold,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settings,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upravte vzhľad, dáta, firmu a bezpečnosť na jednom mieste.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSettingsCategories(
    BuildContext context,
    AppLocalizations l10n,
    ThemeLocaleProvider themeProvider,
  ) {
    return [
      _buildCategoryBlock(
        title: 'Vzhľad a systém',
        subtitle: 'Téma, jazyk a upozornenia',
        icon: Icons.palette_outlined,
        accent: AppColors.accentGold,
        sections: [
          _buildSubGroup(
            label: 'Vzhľad',
            tiles: [
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: l10n.darkMode,
                subtitle: l10n.darkModeSubtitle,
                value: themeProvider.isDarkMode,
                onChanged: (v) => themeProvider.setDarkMode(v),
              ),
              _buildListTile(
                icon: Icons.language_outlined,
                title: l10n.language,
                trailing: _getLanguageDisplayName(
                  themeProvider.locale.languageCode,
                  l10n,
                ),
                onTap: () => _showLanguageDialog(context, themeProvider),
              ),
            ],
          ),
          _buildSubGroup(
            label: 'Upozornenia',
            tiles: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: l10n.notifications,
                subtitle: l10n.notificationsSubtitle,
                value: _notificationsEnabled,
                onChanged: _saveNotifications,
              ),
              _buildListTile(
                icon: Icons.settings_suggest_outlined,
                title: 'Detailné nastavenia',
                trailing: 'Tiché hodiny, pripomienky',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      _buildCategoryBlock(
        title: 'Dáta a úložisko',
        subtitle: 'Databáza, zálohy a údržba',
        icon: Icons.cloud_done_outlined,
        accent: AppColors.info,
        sections: [
          _buildSubGroup(
            label: 'Lokálna databáza',
            tiles: [
              _buildListTile(
                icon: Icons.folder_outlined,
                title: l10n.databaseLocation,
                trailing: _dbPath != null
                    ? _shortPath(_dbPath!)
                    : l10n.defaultPath,
                onTap: () => _showDbPathInfo(),
              ),
              _buildListTile(
                icon: Icons.event_busy_outlined,
                title: l10n.monthlyClosingsTitle,
                trailing: l10n.monthlyClosingsOpenScreen,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => MonthlyClosingScreen(
                        userRole: widget.userRole,
                      ),
                    ),
                  );
                },
              ),
              if (widget.userRole == 'admin') ...[
                _buildListTile(
                  icon: Icons.backup_rounded,
                  title: l10n.backupDatabaseDownload,
                  trailing: l10n.backupDatabaseAction,
                  onTap: () => _downloadDatabaseBackup(context),
                ),
                _buildListTile(
                  icon: Icons.delete_forever_outlined,
                  title: l10n.clearDatabase,
                  trailing: l10n.delete,
                  onTap: () => _showClearDatabaseDialog(context),
                ),
                _buildListTile(
                  icon: Icons.input_rounded,
                  title: 'Import z Oberon (SQLite)',
                  trailing: 'Mapovanie stĺpcov',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => const OberonImportScreen(),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
      _buildCategoryBlock(
        title: 'Firma a prevádzka',
        subtitle: 'Údaje firmy, PDF a sklady',
        icon: Icons.apartment_rounded,
        accent: AppColors.accentPurple,
        sections: [
          _buildSubGroup(
            label: 'Organizácia',
            tiles: [
              _buildListTile(
                icon: Icons.edit_outlined,
                title: l10n.ourCompany,
                trailing: l10n.saveChanges,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CompanyEditScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          _buildSubGroup(
            label: 'Dokumenty a tlač',
            tiles: [
              _buildListTile(
                icon: Icons.receipt_long_rounded,
                title: 'Štýl PDF pre príjemky',
                trailing: 'Nastaviť',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReceiptPdfStyleScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          _buildSubGroup(
            label: 'Sklady a katalóg',
            tiles: [
              _buildListTile(
                icon: Icons.category_rounded,
                title: 'Druhy produktov',
                trailing: 'Klince, montážna pena, …',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductKindsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      _buildCategoryBlock(
        title: 'Bezpečnosť',
        subtitle: 'Odhlásenie a dvojfaktorové overenie',
        icon: Icons.shield_outlined,
        accent: AppColors.success,
        sections: [
          _buildSubGroup(
            label: 'Prístup',
            tiles: [
              _buildListTile(
                icon: Icons.lock_clock_outlined,
                title: 'Auto-odhlásenie',
                trailing: _autoLockLabel(_autoLockMinutes),
                onTap: _showAutoLockDialog,
              ),
              _buildListTile(
                icon: Icons.phonelink_lock_rounded,
                title: 'TOTP dvojfaktorové overenie',
                trailing: 'Stav, backup kódy',
                onTap: _show2faDialog,
              ),
            ],
          ),
        ],
      ),
      _buildCategoryBlock(
        title: l10n.about,
        subtitle: l10n.stockManagement,
        icon: Icons.info_outline_rounded,
        accent: AppColors.textSecondary,
        sections: [
          _buildSubGroup(
            label: 'Verzia',
            tiles: [
              _buildListTile(
                icon: Icons.inventory_2_rounded,
                title: l10n.appTitle,
                trailing: 'v1.0',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.stockManagement)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ];
  }

  Widget _buildCategoryBlock({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<Widget> sections,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.2),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sections,
        ],
      ),
    );
  }

  Widget _buildSubGroup({
    required String label,
    required List<Widget> tiles,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1.15,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
          ),
          _buildGlassCard(children: tiles),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required List<Widget> children}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              final isLast = i == children.length - 1;
              return Column(
                children: [
                  c,
                  if (!isLast)
                    Divider(
                      height: 1,
                      color: AppColors.borderSubtle,
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.borderSubtle,
                width: 1,
              ),
            ),
            child: Icon(icon, color: AppColors.accentGold, size: 22),
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.accentGold,
        activeColor: AppColors.accentGold,
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentGoldSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.borderSubtle,
                width: 1,
              ),
            ),
            child: Icon(icon, color: AppColors.accentGold, size: 22),
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              trailing,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _shortPath(String path) {
    if (path.length <= 35) return path;
    return '...${path.substring(path.length - 32)}';
  }

  void _showLanguageDialog(
    BuildContext context,
    ThemeLocaleProvider themeProvider,
  ) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _languageOption(
              ctx,
              themeProvider,
              'sk',
              l10n.languageSlovak,
              l10n,
            ),
            _languageOption(ctx, themeProvider, 'cs', l10n.languageCzech, l10n),
            _languageOption(
              ctx,
              themeProvider,
              'en',
              l10n.languageEnglish,
              l10n,
            ),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(
    BuildContext ctx,
    ThemeLocaleProvider themeProvider,
    String code,
    String label,
    AppLocalizations l10n,
  ) {
    final isSelected = themeProvider.locale.languageCode == code;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
          : null,
      onTap: () async {
        Navigator.pop(ctx);
        await themeProvider.setLocale(Locale(code));
        if (ctx.mounted) {
          ScaffoldMessenger.of(
            ctx,
          ).showSnackBar(SnackBar(content: Text(l10n.languageChanged(label))));
        }
      },
    );
  }

  void _showDbPathInfo() async {
    final path = await DatabaseService().getDatabasePath();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.databaseLocation),
        content: SelectableText(path ?? l10n.unknown),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
