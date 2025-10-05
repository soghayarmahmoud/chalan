import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFF5A189A); 
const Color darkThemeColor = Color(0xFF1E1E1E); 
const Color lightThemeColor = Color(0xFFF7F7F7); 

final ThemeData lightTheme = ThemeData(
  primaryColor: primaryColor,
  brightness: Brightness.light,
  scaffoldBackgroundColor: lightThemeColor,
  colorScheme: const ColorScheme.light(
    primary: primaryColor,
    onSurface: Colors.black, 
  ),
);

final ThemeData darkTheme = ThemeData(
  primaryColor: primaryColor,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: darkThemeColor,
  colorScheme: const ColorScheme.dark(
    primary: primaryColor,
    onSurface: Colors.white, 
  ),
);