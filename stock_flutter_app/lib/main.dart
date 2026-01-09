// Imports updated
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/stock_provider.dart';
import 'providers/profit_loss_provider.dart';
import 'screens/home_screen.dart';
import 'services/google_drive_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => ProfitLossProvider()),
        ChangeNotifierProvider(create: (_) => GoogleDriveService()..init()),
      ],
      child: MaterialApp(
        title: '台股即時看板',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue, // Gmail blue
          brightness: Brightness.light,
          scaffoldBackgroundColor:
              const Color(0xFFFDFDFD), // Very light clean background
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFDFDFD), // Clean surface
            surfaceTintColor: Colors.transparent, // Avoid tint on scroll
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            elevation: 0, // Flat cards usually, or low elevation
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(16)), // Rounded M3 corners
              side: BorderSide(color: Color(0xFFE0E0E0)), // Subtle outline
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1B1B1F),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1B1B1F),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Color(0xFF2C2C30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              side: BorderSide.none,
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
