import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_boarding_house_partner/screens/splash_screen.dart';
import 'package:my_boarding_house_partner/services/auth_service.dart';
import 'package:my_boarding_house_partner/services/user_service.dart';
import 'package:my_boarding_house_partner/services/property_service.dart';
import 'package:my_boarding_house_partner/services/booking_service.dart';
import 'package:my_boarding_house_partner/services/messaging_service.dart';
import 'package:my_boarding_house_partner/providers/auth_provider.dart';
import 'package:my_boarding_house_partner/providers/theme_provider.dart';
import 'package:my_boarding_house_partner/utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Get user preferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(isDarkMode)),
        Provider<AuthenticationService>(create: (_) => AuthenticationService()),
        Provider<UserService>(create: (_) => UserService()),
        Provider<PropertyService>(create: (_) => PropertyService()),
        Provider<BookingService>(create: (_) => BookingService()),
        Provider<MessagingService>(create: (_) => MessagingService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(title: 'Dodo Doba Partner', debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme, darkTheme: AppTheme.darkTheme, themeMode: themeProvider.themeMode, home: const SplashScreen());
  }
}
