
import 'package:flutter/material.dart';

const Color primarySeedColor = Colors.deepPurple;

// Define a common TextTheme
final TextTheme appTextTheme = const TextTheme(
  displayLarge: TextStyle(fontFamily: 'Oswald', fontSize: 57, fontWeight: FontWeight.bold),
  titleLarge: TextStyle(fontFamily: 'Roboto', fontSize: 22, fontWeight: FontWeight.w500),
  bodyMedium: TextStyle(fontFamily: 'Open Sans', fontSize: 14),
);

// Light Theme
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primarySeedColor,
    brightness: Brightness.light,
  ),
  textTheme: appTextTheme,
  appBarTheme: const AppBarTheme(
    backgroundColor: primarySeedColor,
    foregroundColor: Colors.white,
    titleTextStyle: TextStyle(fontFamily: 'Oswald', fontSize: 24, fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: primarySeedColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
);

// Dark Theme
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: primarySeedColor,
    brightness: Brightness.dark,
  ),
  textTheme: appTextTheme,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.grey,
    foregroundColor: Colors.white,
    titleTextStyle: TextStyle(fontFamily: 'Oswald', fontSize: 24, fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: Colors.black,
      backgroundColor: Colors.deepPurple.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 16, fontWeight: FontWeight.w500),
    ),
  ),
);
