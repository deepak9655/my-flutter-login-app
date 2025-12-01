// lib/services/settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyUseSeparateDriveAccount = 'use_separate_drive_account';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLanguage = 'language';
  static const String _keyBackupLocation = 'backup_location';

  bool _useSeparateDriveAccount = false;
  bool _notificationsEnabled = true;
  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'en';
  String? _backupLocation;

  bool get useSeparateDriveAccount => _useSeparateDriveAccount;
  bool get notificationsEnabled => _notificationsEnabled;
  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  String? get backupLocation => _backupLocation;

  SettingsService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _useSeparateDriveAccount =
          prefs.getBool(_keyUseSeparateDriveAccount) ?? false;
      _notificationsEnabled =
          prefs.getBool(_keyNotificationsEnabled) ?? true;
      final themeModeIndex = prefs.getInt(_keyThemeMode) ?? 0;
      _themeMode = ThemeMode.values[themeModeIndex];
      _language = prefs.getString(_keyLanguage) ?? 'en';
      _backupLocation = prefs.getString(_keyBackupLocation);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setUseSeparateDriveAccount(bool value) async {
    _useSeparateDriveAccount = value;
    await SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_keyUseSeparateDriveAccount, value));
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_keyNotificationsEnabled, value));
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt(_keyThemeMode, mode.index));
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_keyLanguage, lang));
    notifyListeners();
  }

  Future<void> setBackupLocation(String? location) async {
    _backupLocation = location;
    final prefs = await SharedPreferences.getInstance();
    if (location != null) {
      await prefs.setString(_keyBackupLocation, location);
    } else {
      await prefs.remove(_keyBackupLocation);
    }
    notifyListeners();
  }
}

