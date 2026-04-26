
import 'package:flutter/material.dart';
import 'package:myapp/core/theme.dart';
import 'package:myapp/screens/main_screen.dart';
import 'package:myapp/state/app_state.dart';
import 'package:myapp/state/theme_provider.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppState()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const WtrLabReaderApp(),
    ),
  );
}

class WtrLabReaderApp extends StatelessWidget {
  const WtrLabReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'WTR Lab Reader',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MainScreen(),
        );
      },
    );
  }
}
