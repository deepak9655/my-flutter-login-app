// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'viewmodels/home_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _defaultLightColorScheme =
      ColorScheme.fromSeed(seedColor: Colors.indigo);
  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo, brightness: Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return DynamicColorBuilder(
            builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
              final lightColorScheme = lightDynamic ?? _defaultLightColorScheme;
              final darkColorScheme = darkDynamic ?? _defaultDarkColorScheme;

              return MaterialApp(
                title: 'Repair Shop Pro',
                theme: ThemeData(
                  colorScheme: lightColorScheme,
                  useMaterial3: true,
                  appBarTheme: AppBarTheme(
                    backgroundColor: lightColorScheme.primary,
                    foregroundColor: lightColorScheme.onPrimary,
                    elevation: 0,
                    titleTextStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: lightColorScheme.onPrimary),
                  ),
                  cardTheme: const CardThemeData(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  // Input field theme
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: lightColorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: lightColorScheme.primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: lightColorScheme.outline, width: 1),
                    ),
                    hintStyle:
                        TextStyle(color: lightColorScheme.onSurfaceVariant),
                    labelStyle: TextStyle(color: lightColorScheme.onSurface),
                    prefixIconColor: lightColorScheme.onSurfaceVariant,
                    suffixIconColor: lightColorScheme.onSurfaceVariant,
                  ),
                ),
                darkTheme: ThemeData(
                  colorScheme: darkColorScheme,
                  useMaterial3: true,
                  appBarTheme: AppBarTheme(
                    backgroundColor: darkColorScheme.primary,
                    foregroundColor: darkColorScheme.onPrimary,
                    elevation: 0,
                    titleTextStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: darkColorScheme.onPrimary),
                  ),
                  floatingActionButtonTheme: FloatingActionButtonThemeData(
                    backgroundColor: darkColorScheme.secondaryContainer,
                    foregroundColor: darkColorScheme.onSecondaryContainer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  cardTheme: const CardThemeData(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  // Input field theme
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: darkColorScheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: darkColorScheme.primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: darkColorScheme.outline, width: 1),
                    ),
                    hintStyle:
                        TextStyle(color: darkColorScheme.onSurfaceVariant),
                    labelStyle: TextStyle(color: darkColorScheme.onSurface),
                    prefixIconColor: darkColorScheme.onSurfaceVariant,
                    suffixIconColor: darkColorScheme.onSurfaceVariant,
                  ),
                ),
                themeMode: settings.themeMode,
                home: Consumer<AuthService>(
                  builder: (context, authService, child) {
                    if (authService.isLoading &&
                        !authService.isSignedIn &&
                        !authService.isGuestMode) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return (authService.isSignedIn || authService.isGuestMode)
                        ? const HomeScreen()
                        : const LoginScreen();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
