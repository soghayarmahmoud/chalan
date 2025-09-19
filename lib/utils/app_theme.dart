import 'package:flutter/material.dart';

const Color primaryColor = Color.fromARGB(255, 238, 155, 0); 
const Color darkThemeColor = Color(0xFF121802); 
const Color lightThemeColor = Color(0xFFFFFFFF); 

final ThemeData lightTheme = ThemeData(
  primaryColor: primaryColor,
  brightness: Brightness.light,
  scaffoldBackgroundColor: lightThemeColor,
  colorScheme: const ColorScheme.light(
    primary: primaryColor,
    onBackground: Colors.black, 
  ),
);

final ThemeData darkTheme = ThemeData(
  primaryColor: primaryColor,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: darkThemeColor,
  colorScheme: const ColorScheme.dark(
    primary: primaryColor,
    onBackground: Colors.white, 
  ),
);