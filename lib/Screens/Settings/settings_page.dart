import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Providers/theme_locale_provider.dart';
import '../../services/database/database_service.dart';
import '../../l10n/app_localizations.dart';
import 'company_edit_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String? _dbPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _dbPath = prefs.getString('db_path');
    });
  }

  Future<void> _saveNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeProvider = context.watch<ThemeLocaleProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.6),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.3),
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
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                title: Text(
                  l10n.settings,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF0F2F5),
              const Color(0xFFE8EBF0),
              const Color(0xFFF0F2F5),
            ],
          ),
        ),
        child: SingleChildScrollView(
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
              Icon(icon, size: 20, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
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
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 6,
                      offset: const Offset(0, -3),
                      spreadRadius: -2,
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
                            color: Colors.white.withOpacity(0.3),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.2),
                  const Color(0xFF6366F1).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 22),
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      trailing: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: value
                  ? const Color(0xFF6366F1).withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF6366F1),
        ),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.2),
                  const Color(0xFF6366F1).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 22),
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF1E293B),
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
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
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
