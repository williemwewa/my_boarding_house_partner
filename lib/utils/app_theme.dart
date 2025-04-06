import 'package:flutter/material.dart';

// API endpoint for image uploads
final String _imageUploadApiUrl = 'http://143.198.165.152/api/upload-image';

class AppTheme {
  // Colors from the screenshots
  static const Color primaryColor = Color(0xFF1F2B7E);
  static const Color primaryColorLight = Color(0xFF3E4DA0);
  static const Color accentColor = Color(0xFF2196F3);
  static const Color backgroundColor = Colors.white;
  static const Color textColor = AppTheme.primaryColor;
  static const Color secondaryTextColor = Color(0xFF757575);
  static const Color dividerColor = Color(0xFFE0E0E0);
  static const Color errorColor = Color(0xFFB00020);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color cardColor = Colors.white;
  static const Color verifiedBadgeColor = Color(0xFF00BFA5);

  // Text styles
  static const TextStyle headlineStyle = TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: textColor, height: 1.2);

  static const TextStyle subtitleStyle = TextStyle(fontSize: 16.0, color: secondaryTextColor);

  static const TextStyle buttonTextStyle = TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: Colors.white);

  static const TextStyle cardTitleStyle = TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: textColor);

  static const TextStyle cardSubtitleStyle = TextStyle(fontSize: 14.0, color: secondaryTextColor);

  // Button styles
  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16));

  static final ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: primaryColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: primaryColor)),
    elevation: 0,
    padding: const EdgeInsets.symmetric(vertical: 16),
  );

  static final ButtonStyle outlineButtonStyle = OutlinedButton.styleFrom(foregroundColor: primaryColor, side: const BorderSide(color: primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16));

  // Input decoration
  static InputDecoration inputDecoration(String labelText, String hintText) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryColor, width: 2)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    hintColor: accentColor,
    colorScheme: ColorScheme.light(primary: primaryColor, secondary: accentColor, background: backgroundColor, error: errorColor, surface: cardColor),
    scaffoldBackgroundColor: backgroundColor,
    appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.white, iconTheme: IconThemeData(color: textColor), titleTextStyle: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20), centerTitle: true),
    cardTheme: CardTheme(color: cardColor, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Colors.white, selectedItemColor: primaryColor, unselectedItemColor: secondaryTextColor),
    textTheme: const TextTheme(titleLarge: headlineStyle, titleMedium: cardTitleStyle, bodyLarge: subtitleStyle, bodyMedium: cardSubtitleStyle),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryColor),
  );

  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    hintColor: accentColor,
    colorScheme: ColorScheme.dark(primary: primaryColor, secondary: accentColor, background: const Color(0xFF121212), error: errorColor, surface: const Color(0xFF1E1E1E)),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Color(0xFF1E1E1E), iconTheme: IconThemeData(color: Colors.white), titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20), centerTitle: true),
    cardTheme: CardTheme(color: const Color(0xFF1E1E1E), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Color(0xFF1E1E1E), selectedItemColor: accentColor, unselectedItemColor: Color(0xFFAAAAAA)),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2),
      titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: Colors.white),
      bodyLarge: TextStyle(fontSize: 16.0, color: Color(0xFFBBBBBB)),
      bodyMedium: TextStyle(fontSize: 14.0, color: Color(0xFFAAAAAA)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: accentColor),
  );
}
