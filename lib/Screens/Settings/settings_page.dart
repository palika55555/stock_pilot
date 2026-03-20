import 'dart:io' show File;
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Providers/theme_locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/Database/database_service.dart';
import '../../services/auto_lock_service.dart';
import '../../l10n/app_localizations.dart';
import 'company_edit_screen.dart';
import 'receipt_pdf_style_screen.dart';
import 'product_kinds_screen.dart';
import 'notification_settings_screen.dart';

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
      body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80), // Priestor pre AppBar
            _buildSection(
              title: l10n.application,
              icon: Icons.app_settings_alt_rounded,
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: l10n.notifications,
                  subtitle: l10n.notificationsSubtitle,
                  value: _notificationsEnabled,
                  onChanged: _saveNotifications,
                ),
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
            _buildSection(
              title: l10n.database,
              icon: Icons.storage_rounded,
              children: [
                _buildListTile(
                  icon: Icons.folder_outlined,
                  title: l10n.databaseLocation,
                  trailing: _dbPath != null
                      ? _shortPath(_dbPath!)
                      : l10n.defaultPath,
                  onTap: () => _showDbPathInfo(),
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
                ],
              ],
            ),
            _buildSection(
              title: l10n.ourCompany,
              icon: Icons.business_rounded,
              children: [
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
            _buildSection(
              title: 'Notifikácie',
              icon: Icons.notifications_active_outlined,
              children: [
                _buildListTile(
                  icon: Icons.settings_suggest_outlined,
                  title: 'Nastavenia notifikácií',
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
            _buildSection(
              title: 'Generovanie PDF',
              icon: Icons.picture_as_pdf_rounded,
              children: [
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
            _buildSection(
              title: 'Sklady a produkty',
              icon: Icons.inventory_2_rounded,
              children: [
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
            _buildSection(
              title: 'Bezpečnosť',
              icon: Icons.security_rounded,
              children: [
                _buildListTile(
                  icon: Icons.lock_clock_outlined,
                  title: 'Auto-odhlásenie',
                  trailing: _autoLockLabel(_autoLockMinutes),
                  onTap: _showAutoLockDialog,
                ),
              ],
            ),
            _buildSection(
              title: l10n.about,
              icon: Icons.info_outline_rounded,
              children: [
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
              const SizedBox(height: 32),
            ],
          ),
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.accentGold),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
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
                  children: children.map((c) {
                    final isLast = c == children.last;
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
          ),
        ],
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
