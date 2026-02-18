import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'web_storage_stub.dart' if (dart.library.html) 'web_storage_web.dart' as web_storage;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
  );

  User? get currentUser => _auth.currentUser;
  
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String? _lastError;
  String? get lastError => _lastError;
  
  // Store access token from OAuth for Calendar API
  String? _calendarAccessToken;
  DateTime? _tokenExpiry;
  
  // Flag to indicate calendar needs reconnection
  bool _needsCalendarReconnect = false;
  bool get needsCalendarReconnect => _needsCalendarReconnect;
  
  static const String _tokenKey = 'calendar_access_token';
  static const String _tokenExpiryKey = 'calendar_token_expiry';

  // Load stored token on init
  Future<void> loadStoredToken() async {
    try {
      if (kIsWeb) {
        _calendarAccessToken = web_storage.getItem(_tokenKey);
        final expiryStr = web_storage.getItem(_tokenExpiryKey);
        if (expiryStr != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        _calendarAccessToken = prefs.getString(_tokenKey);
        final expiryMs = prefs.getInt(_tokenExpiryKey);
        if (expiryMs != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        }
      }
      
      if (kDebugMode) {
        debugPrint('Loaded stored calendar token: ${_calendarAccessToken != null}');
        if (_tokenExpiry != null) {
          debugPrint('Token expiry: $_tokenExpiry (expired: ${_isTokenExpired()})');
        }
      }
      
      // Check if token is expired and try to refresh automatically
      if (_calendarAccessToken != null && _isTokenExpired()) {
        if (kDebugMode) {
          debugPrint('Token expired, attempting automatic refresh...');
        }
        await _tryAutoRefreshToken();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading stored token: $e');
      }
    }
  }
  
  // Check if token is expired (with 5 minute buffer)
  bool _isTokenExpired() {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }
  
  // Try to automatically refresh token using Firebase Auth
  Future<bool> _tryAutoRefreshToken() async {
    if (!kIsWeb) {
      // Mobile: Use GoogleSignIn silent refresh
      try {
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          final auth = await googleUser.authentication;
          if (auth.accessToken != null) {
            _calendarAccessToken = auth.accessToken;
            _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
            await _saveToken();
            _needsCalendarReconnect = false;
            if (kDebugMode) {
              debugPrint('Mobile: Token auto-refreshed successfully');
            }
            return true;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Mobile auto-refresh failed: $e');
        }
      }
    } else {
      // Web: Try to get token from Firebase Auth's current user
      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Force refresh the ID token - this doesn't give us a new access token
          // but confirms the user is still authenticated
          await user.getIdToken(true);
          
          // Unfortunately, on web we can't get a new access token without user interaction
          // Set flag to show reconnect button
          _needsCalendarReconnect = true;
          if (kDebugMode) {
            debugPrint('Web: Token expired, needs manual reconnection');
          }
          return false;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Web auth check failed: $e');
        }
      }
    }
    
    _needsCalendarReconnect = true;
    return false;
  }
  
  // Save token to storage with expiry
  Future<void> _saveToken() async {
    try {
      if (kIsWeb) {
        if (_calendarAccessToken != null) {
          web_storage.setItem(_tokenKey, _calendarAccessToken!);
        }
        if (_tokenExpiry != null) {
          web_storage.setItem(_tokenExpiryKey, _tokenExpiry!.millisecondsSinceEpoch.toString());
        }
        if (kDebugMode) {
          debugPrint('Saved calendar token to localStorage');
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        if (_calendarAccessToken != null) {
          await prefs.setString(_tokenKey, _calendarAccessToken!);
        }
        if (_tokenExpiry != null) {
          await prefs.setInt(_tokenExpiryKey, _tokenExpiry!.millisecondsSinceEpoch);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving token: $e');
      }
    }
  }
  
  // Clear stored token
  Future<void> _clearStoredToken() async {
    try {
      if (kIsWeb) {
        web_storage.removeItem(_tokenKey);
        web_storage.removeItem(_tokenExpiryKey);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove(_tokenExpiryKey);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing stored token: $e');
      }
    }
  }

  Future<User?> signInWithGoogle() async {
    _lastError = null;
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('https://www.googleapis.com/auth/calendar');
        googleProvider.addScope('https://www.googleapis.com/auth/calendar.events');
        googleProvider.addScope('https://www.googleapis.com/auth/calendar.readonly');
        googleProvider.setCustomParameters({
          'prompt': 'consent',
          'access_type': 'offline',
        });
        
        final UserCredential userCredential = 
            await _auth.signInWithPopup(googleProvider);
        
        final credential = userCredential.credential;
        if (credential != null) {
          _calendarAccessToken = credential.accessToken;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          _needsCalendarReconnect = false;
          await _saveToken();
          
          if (kDebugMode) {
            debugPrint('Calendar access token obtained, expires at: $_tokenExpiry');
          }
        }
        
        return userCredential.user;
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = 
            await googleUser.authentication;

        _calendarAccessToken = googleAuth.accessToken;
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
        _needsCalendarReconnect = false;
        await _saveToken();

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = 
            await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } on FirebaseAuthException catch (e) {
      _lastError = '${e.code}: ${e.message}';
      if (kDebugMode) {
        debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      }
      return null;
    } catch (e) {
      _lastError = e.toString();
      if (kDebugMode) {
        debugPrint('Error signing in with Google: $e');
      }
      return null;
    }
  }

  Future<void> signOut() async {
    _calendarAccessToken = null;
    _tokenExpiry = null;
    _needsCalendarReconnect = false;
    await _clearStoredToken();
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google sign out error: $e');
      }
    }
    await _auth.signOut();
  }

  Future<String?> getAccessToken() async {
    // Load from storage if not already loaded
    if (_calendarAccessToken == null) {
      await loadStoredToken();
    }
    
    // Check if token is expired
    if (_calendarAccessToken != null && _isTokenExpired()) {
      if (kDebugMode) {
        debugPrint('Token expired during getAccessToken, trying refresh...');
      }
      
      // Try to auto-refresh
      final refreshed = await _tryAutoRefreshToken();
      if (!refreshed) {
        // Token couldn't be refreshed, return null to trigger reconnection UI
        return null;
      }
    }
    
    // Return cached token if available and valid
    if (_calendarAccessToken != null && _calendarAccessToken!.isNotEmpty) {
      return _calendarAccessToken;
    }
    
    return null;
  }
  
  // Check if calendar access is available
  bool get hasCalendarAccess => 
      _calendarAccessToken != null && 
      _calendarAccessToken!.isNotEmpty && 
      !_isTokenExpired();
  
  // Mark token as invalid (called when API returns 401)
  void invalidateToken() {
    if (kDebugMode) {
      debugPrint('Token invalidated due to API error');
    }
    _calendarAccessToken = null;
    _tokenExpiry = null;
    _needsCalendarReconnect = true;
    _clearStoredToken();
  }
  
  // Request fresh calendar token (shows popup on web)
  Future<bool> requestCalendarAccess() async {
    try {
      if (kIsWeb) {
        final user = _auth.currentUser;
        if (user != null) {
          // Show consent popup to get new token
          GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('https://www.googleapis.com/auth/calendar');
          googleProvider.addScope('https://www.googleapis.com/auth/calendar.events');
          googleProvider.addScope('https://www.googleapis.com/auth/calendar.readonly');
          googleProvider.setCustomParameters({
            'prompt': 'consent',
          });
          
          final result = await user.reauthenticateWithPopup(googleProvider);
          if (result.credential != null && result.credential!.accessToken != null) {
            _calendarAccessToken = result.credential!.accessToken;
            _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
            _needsCalendarReconnect = false;
            await _saveToken();
            if (kDebugMode) {
              debugPrint('Calendar access renewed successfully');
            }
            return true;
          }
        }
      } else {
        // Mobile: try full sign-in again
        final googleUser = await _googleSignIn.signIn();
        if (googleUser != null) {
          final auth = await googleUser.authentication;
          _calendarAccessToken = auth.accessToken;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          _needsCalendarReconnect = false;
          await _saveToken();
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error requesting calendar access: $e');
      }
      _lastError = e.toString();
    }
    return false;
  }
  
  // Force re-authenticate
  Future<bool> forceReauthenticate() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('https://www.googleapis.com/auth/calendar');
        googleProvider.addScope('https://www.googleapis.com/auth/calendar.events');
        googleProvider.addScope('https://www.googleapis.com/auth/calendar.readonly');
        googleProvider.setCustomParameters({
          'prompt': 'select_account consent',
        });
        
        final UserCredential userCredential = 
            await _auth.signInWithPopup(googleProvider);
        
        if (userCredential.credential != null) {
          _calendarAccessToken = userCredential.credential!.accessToken;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          _needsCalendarReconnect = false;
          await _saveToken();
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Force re-authentication error: $e');
      }
      _lastError = e.toString();
    }
    return false;
  }
}
