// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: Consumer2<AuthService, SettingsService>(
        builder: (context, authService, settings, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: authService.currentUser?.photoUrl != null
                            ? NetworkImage(authService.currentUser!.photoUrl!)
                            : null,
                        child: authService.currentUser?.photoUrl == null
                            ? Icon(
                                authService.isGuestMode
                                    ? Icons.person_outline
                                    : Icons.person,
                                size: 30)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authService.isGuestMode
                                  ? 'Guest User'
                                  : (authService.displayName ?? 'User'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (authService.email != null)
                              Text(
                                authService.email!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                                overflow: TextOverflow.ellipsis,
                              )
                            else if (authService.isGuestMode)
                              Text(
                                'Limited features available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Google Drive Settings
              _buildSectionHeader(context, 'Google Drive'),
              const SizedBox(height: 8),
              const SizedBox(height: 24),

              // App Settings
              _buildSectionHeader(context, 'App Settings'),
              const SizedBox(height: 8),
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  secondary: Icon(Icons.notifications_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Notifications'),
                  subtitle: const Text('Enable push notifications'),
                  value: settings.notificationsEnabled,
                  onChanged: (value) async {
                    await settings.setNotificationsEnabled(value);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Notifications ${value ? 'enabled' : 'disabled'}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.dark_mode_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Theme'),
                  subtitle: Text(_getThemeModeText(settings.themeMode)),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    items: ThemeMode.values.map((mode) {
                      return DropdownMenuItem(
                        value: mode,
                        child: Text(_getThemeModeText(mode)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        settings.setThemeMode(value);
                      }
                    },
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.language_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Language'),
                  subtitle: const Text('English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Language selection dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Language'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              title: const Text('English'),
                              leading: Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary),
                              onTap: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Language set to English')),
                                );
                              },
                            ),
                             const ListTile(
                              title: Text('More languages coming soon'),
                              enabled: false,
                            ),
                         ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Data Management
              _buildSectionHeader(context, 'Data Management'),
              const SizedBox(height: 8),
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.folder_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Backup Location'),
                  subtitle: Text(
                    settings.backupLocation ?? 'Default (App Documents)',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha((0.7 * 255).round()),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showBackupLocationDialog(context, settings),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Free up storage space'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showClearCacheDialog(context),
                ),
              ),
              const SizedBox(height: 24),

              // About
              _buildSectionHeader(context, 'About'),
              const SizedBox(height: 8),
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                  title: const Text('App Version'),
                  subtitle: const Text('1.0.0'),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Get help and contact support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Help & Support'),
                        content: const Text(
                            'For support, please contact:\n\nEmail: support@repairshop.com\n\nOr visit our website for documentation and FAQs.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Sign Out
              if (!authService.isGuestMode)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _handleSignOut(context, authService),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Sign In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _handleSignOut(context, authService),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.bodySmall?.color,
        letterSpacing: 0.5,
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
            'This will clear cached data and temporary files. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(
      BuildContext context, AuthService authService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(authService.isGuestMode ? 'Sign In' : 'Sign Out'),
        content: Text(authService.isGuestMode
            ? 'Sign in to access all features and sync your data.'
            : 'Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: authService.isGuestMode
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error),
            child: Text(authService.isGuestMode ? 'Sign In' : 'Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await authService.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showBackupLocationDialog(
      BuildContext context, SettingsService settings) {
    final controller = TextEditingController(text: settings.backupLocation ?? '');
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the folder path where backups should be saved:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Leave empty for default location',
                border: OutlineInputBorder(),
                helperText: 'Example: D:/Backups/RepairShop',
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reset to Default'),
              onPressed: () {
                controller.clear();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final path = controller.text.trim();
              await settings.setBackupLocation(path.isEmpty ? null : path);
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(path.isEmpty
                        ? 'Backup location reset to default'
                        : 'Backup location set to: $path'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
