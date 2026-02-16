import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('Flutter error: ${details.exception}');
    }
  };
  
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('Platform error: $error');
    }
    return true;
  };
  
  // Initialize Firebase
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
    if (kDebugMode) {
      debugPrint('Firebase initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase init error: $e');
    }
  }
  
  // Initialize locale
  try {
    await initializeDateFormatting('ko', null);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Locale error: $e');
    }
  }
  
  runApp(TodaiApp(firebaseReady: firebaseReady));
}

class TodaiApp extends StatelessWidget {
  final bool firebaseReady;
  
  const TodaiApp({super.key, required this.firebaseReady});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(firebaseInitialized: firebaseReady)..initialize(),
      child: MaterialApp(
        title: 'Todai',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: firebaseReady 
          ? const AuthWrapper() 
          : const _ErrorScreen(message: 'Firebase initialization failed'),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;
  bool _error = false;
  User? _user;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      // Listen to auth state changes
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (User? user) {
          if (mounted) {
            setState(() {
              _user = user;
              _initialized = true;
            });
          }
        },
        onError: (error) {
          if (kDebugMode) {
            debugPrint('Auth error: $error');
          }
          if (mounted) {
            setState(() {
              _error = true;
              _initialized = true;
            });
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Auth init error: $e');
      }
      if (mounted) {
        setState(() {
          _error = true;
          _initialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const _ErrorScreen(message: 'Authentication error');
    }
    
    if (!_initialized) {
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
    
    // User is logged in
    if (_user != null) {
      return const HomeScreen();
    }
    
    // User is not logged in
    return const LoginScreen();
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Reload the page
                if (kIsWeb) {
                  // ignore: avoid_web_libraries_in_flutter
                  // This will be executed only on web
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
