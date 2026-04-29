import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';
import 'screens/home.dart';

const _brandSeedColor = Color(0xFF7C4DFF);

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  ThemeMode _themeMode = AppPreferences.defaultThemeMode;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    setState(() {
      _themeMode = AppPreferences.themeModeFromString(
        prefs.getString(AppPreferences.themeModeKey),
      );
    });
  }

  Future<void> _setThemeMode(ThemeMode themeMode) async {
    setState(() {
      _themeMode = themeMode;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppPreferences.themeModeKey,
      AppPreferences.themeModeToString(themeMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gym App',
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomePage(themeMode: _themeMode, onThemeModeChanged: _setThemeMode),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _brandSeedColor,
    brightness: brightness,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: colorScheme.outlineVariant),
  );

  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: colorScheme.surfaceContainerLowest,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
  );
}
