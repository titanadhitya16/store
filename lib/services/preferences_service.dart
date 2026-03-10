import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app preferences/settings
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  // Keys for preferences
  static const String _keyIsDarkMode = 'isDarkMode';
  static const String _keyThemeColor = 'themeColor';
  static const String _keyFontSize = 'fontSize';
  static const String _keyNotificationsEnabled = 'notificationsEnabled';

  /// Initialize the preferences service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========== Dark Mode ==========
  
  /// Get dark mode preference (default: true)
  bool get isDarkMode {
    return _prefs?.getBool(_keyIsDarkMode) ?? true;
  }

  /// Save dark mode preference
  Future<bool> setDarkMode(bool value) async {
    return await _prefs?.setBool(_keyIsDarkMode, value) ?? false;
  }

  // ========== Theme Color ==========
  
  /// Get theme color preference (default: 'zinc')
  String get themeColor {
    return _prefs?.getString(_keyThemeColor) ?? 'zinc';
  }

  /// Save theme color preference
  Future<bool> setThemeColor(String value) async {
    return await _prefs?.setString(_keyThemeColor, value) ?? false;
  }

  // ========== Font Size ==========
  
  /// Get font size preference (default: 16.0)
  double get fontSize {
    return _prefs?.getDouble(_keyFontSize) ?? 16.0;
  }

  /// Save font size preference
  Future<bool> setFontSize(double value) async {
    return await _prefs?.setDouble(_keyFontSize, value) ?? false;
  }

  // ========== Notifications ==========
  
  /// Get notifications enabled preference (default: true)
  bool get notificationsEnabled {
    return _prefs?.getBool(_keyNotificationsEnabled) ?? true;
  }

  /// Save notifications enabled preference
  Future<bool> setNotificationsEnabled(bool value) async {
    return await _prefs?.setBool(_keyNotificationsEnabled, value) ?? false;
  }

  // ========== Clear All Settings ==========
  
  /// Clear all saved preferences
  Future<bool> clearAll() async {
    return await _prefs?.clear() ?? false;
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    await setDarkMode(true);
    await setThemeColor('zinc');
    await setFontSize(16.0);
    await setNotificationsEnabled(true);
  }
}
