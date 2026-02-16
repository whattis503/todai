import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  // Wrap everything in a zone to catch ALL errors
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Global error handler to prevent uncaught exceptions
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        debugPrint('Flutter error: ${details.exception}');
      }
      // Don't rethrow in production to prevent crashes
    };
    
    // Handle platform dispatcher errors (for async errors)
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) {
        debugPrint('Platform error: $error');
      }
      return true; // Handled
    };
    
    bool firebaseInitialized = false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseInitialized = true;
      if (kDebugMode) {
        debugPrint('Firebase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firebase init error: $e');
      }
    }
    
    // Initialize Korean locale for date formatting
    try {
      await initializeDateFormatting('ko', null);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Locale init error: $e');
      }
    }
    
    runApp(TodaiApp(firebaseInitialized: firebaseInitialized));
  }, (error, stack) {
    // This catches any unhandled async errors
    if (kDebugMode) {
      debugPrint('Unhandled error: $error');
    }
  });
}

class TodaiApp extends StatelessWidget {
  final bool firebaseInitialized;
  
  const TodaiApp({super.key, this.firebaseInitialized = false});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(firebaseInitialized: firebaseInitialized)..initialize(),
      child: MaterialApp(
        title: 'Todai',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        // Show loading while initializing
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Show home screen if logged in
        if (provider.isLoggedIn) {
          return const HomeScreen();
        }
        
        // Show login screen
        return const LoginScreen();
      },
    );
  }
}
