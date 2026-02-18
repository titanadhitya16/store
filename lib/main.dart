import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'widget/navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(const Application());
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  // Theme management
  bool _isDarkMode = true;
  String _selectedThemeColor = 'zinc';

  // Method to get the current theme
  FThemeData get _currentTheme {
    return _isDarkMode ? _getDarkTheme() : _getLightTheme();
  }

  FThemeData _getLightTheme() {
    switch (_selectedThemeColor) {
      case 'zinc':
        return FThemes.zinc.light;
      case 'slate':
        return FThemes.slate.light;
      case 'red':
        return FThemes.red.light;
      case 'rose':
        return FThemes.rose.light;
      case 'orange':
        return FThemes.orange.light;
      case 'green':
        return FThemes.green.light;
      case 'blue':
        return FThemes.blue.light;
      case 'yellow':
        return FThemes.yellow.light;
      case 'violet':
        return FThemes.violet.light;
      default:
        return FThemes.zinc.light;
    }
  }

  FThemeData _getDarkTheme() {
    switch (_selectedThemeColor) {
      case 'zinc':
        return FThemes.zinc.dark;
      case 'slate':
        return FThemes.slate.dark;
      case 'red':
        return FThemes.red.dark;
      case 'rose':
        return FThemes.rose.dark;
      case 'orange':
        return FThemes.orange.dark;
      case 'green':
        return FThemes.green.dark;
      case 'blue':
        return FThemes.blue.dark;
      case 'yellow':
        return FThemes.yellow.dark;
      case 'violet':
        return FThemes.violet.dark;
      default:
        return FThemes.zinc.dark;
    }
  }

  void _updateTheme({bool? isDarkMode, String? themeColor}) {
    setState(() {
      if (isDarkMode != null) _isDarkMode = isDarkMode;
      if (themeColor != null) _selectedThemeColor = themeColor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = _currentTheme;

    return MaterialApp(
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      debugShowCheckedModeBanner: false,
      theme: theme.toApproximateMaterialTheme(),
      builder: (_, child) => FTheme(data: theme, child: child!),
      home: FScaffold(
        resizeToAvoidBottomInset: false,
        child: ThemeManager(
          isDarkMode: _isDarkMode,
          selectedThemeColor: _selectedThemeColor,
          onThemeChanged: _updateTheme,
          child: const Navigation(),
        ),
      ),
    );
  }
}

// InheritedWidget to provide theme management throughout the app
class ThemeManager extends InheritedWidget {
  final bool isDarkMode;
  final String selectedThemeColor;
  final Function({bool? isDarkMode, String? themeColor}) onThemeChanged;

  const ThemeManager({
    super.key,
    required this.isDarkMode,
    required this.selectedThemeColor,
    required this.onThemeChanged,
    required super.child,
  });

  static ThemeManager? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeManager>();
  }

  @override
  bool updateShouldNotify(ThemeManager oldWidget) {
    return isDarkMode != oldWidget.isDarkMode ||
        selectedThemeColor != oldWidget.selectedThemeColor;
  }
}
