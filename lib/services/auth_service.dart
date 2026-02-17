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
  
  static const String _tokenKey = 'calendar_access_token';
  static const String _tokenExpiryKey = 'calendar_token_expiry';
  static const String _refreshTokenKey = 'calendar_refresh_token';
  
  // Store refresh token for silent token renewal
  String? _refreshToken;

  // Load stored token on init
  Future<void> loadStoredToken() async {
    try {
      if (kIsWeb) {
        // Web: use localStorage directly
        _calendarAccessToken = web_storage.getItem(_tokenKey);
        final expiryStr = web_storage.getItem(_tokenExpiryKey);
        if (expiryStr != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryStr));
        }
      } else {
        // Mobile: use SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        _calendarAccessToken = prefs.getString(_tokenKey);
        final expiryMs = prefs.getInt(_tokenExpiryKey);
        if (expiryMs != null) {
          _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
        }
      }
      if (kDebugMode) {
        debugPrint('Loaded stored calendar token: ${_calendarAccessToken != null}, length: ${_calendarAccessToken?.length ?? 0}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading stored token: $e');
      }
    }
  }
  
  // Save token to storage
  Future<void> _saveToken() async {
    try {
      if (kIsWeb) {
        // Web: use localStorage directly
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
        // Mobile: use SharedPreferences
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
        // Web: use localStorage directly
        web_storage.removeItem(_tokenKey);
        web_storage.removeItem(_tokenExpiryKey);
      } else {
        // Mobile: use SharedPreferences
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
        // Web sign-in with OAuth to get access token for Calendar
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
        
        // Store OAuth access token for Calendar API
        final credential = userCredential.credential;
        if (credential != null) {
          _calendarAccessToken = credential.accessToken;
          // Set token expiry to 55 minutes from now (buffer before actual expiry)
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          await _saveToken();
          
          if (kDebugMode) {
            debugPrint('Calendar access token obtained: ${_calendarAccessToken != null}');
            debugPrint('Token length: ${_calendarAccessToken?.length ?? 0}');
          }
        } else {
          if (kDebugMode) {
            debugPrint('Warning: No credential received from sign-in');
          }
        }
        
        return userCredential.user;
      } else {
        // Mobile sign-in
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = 
            await googleUser.authentication;

        // Store access token for Calendar API
        _calendarAccessToken = googleAuth.accessToken;
        _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
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
    // First, try to load from storage if not already loaded
    if (_calendarAccessToken == null) {
      await loadStoredToken();
    }
    
    // Check if token is expired or about to expire
    final bool isTokenExpired = _tokenExpiry == null || 
        DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
    
    // If token exists and not expired, use it
    if (_calendarAccessToken != null && _calendarAccessToken!.isNotEmpty && !isTokenExpired) {
      if (kDebugMode) {
        debugPrint('Using stored calendar access token (valid until $_tokenExpiry)');
      }
      return _calendarAccessToken;
    }
    
    // Token is expired or missing - try to refresh silently
    if (kDebugMode) {
      debugPrint('Token expired or missing, attempting silent refresh...');
    }
    
    try {
      if (kIsWeb) {
        // For web, try to silently re-authenticate using stored session
        final user = _auth.currentUser;
        if (user != null) {
          // Try to get fresh token via Firebase Auth token refresh
          final idToken = await user.getIdToken(true);
          if (idToken != null) {
            // Firebase user is still valid, try silent Google sign-in popup
            // But we can't do silent re-auth on web without user interaction
            // So check if we have a recent token that might still work
            if (_calendarAccessToken != null && _calendarAccessToken!.isNotEmpty) {
              if (kDebugMode) {
                debugPrint('Returning possibly expired token for web - will refresh on 401');
              }
              return _calendarAccessToken;
            }
          }
        }
        return _calendarAccessToken;
      } else {
        // Mobile: try silent sign-in to refresh token
        final googleUser = await _googleSignIn.signInSilently();
        if (googleUser != null) {
          final auth = await googleUser.authentication;
          _calendarAccessToken = auth.accessToken;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
          await _saveToken();
          return auth.accessToken;
        }
        return _calendarAccessToken;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting access token: $e');
      }
      return _calendarAccessToken; // Return cached token even if refresh failed
    }
  }
  
  // Check if calendar access is available
  bool get hasCalendarAccess => _calendarAccessToken != null && _calendarAccessToken!.isNotEmpty;
  
  // Check if token needs refresh (expired or about to expire)
  bool get needsTokenRefresh {
    if (_tokenExpiry == null) return true;
    // Refresh if token expires in less than 5 minutes
    return DateTime.now().isAfter(_tokenExpiry!.subtract(const Duration(minutes: 5)));
  }
  
  // Mark token as invalid (called when API returns 401)
  void invalidateToken() {
    if (kDebugMode) {
      debugPrint('Token invalidated - will require re-authentication');
    }
    _tokenExpiry = DateTime.now().subtract(const Duration(minutes: 1));
  }
  
  // Refresh token silently without popup (for automatic calendar loading)
  Future<String?> refreshTokenSilently() async {
    // Just return cached token - don't trigger any auth flows
    if (_calendarAccessToken != null && _calendarAccessToken!.isNotEmpty) {
      return _calendarAccessToken;
    }
    
    // Try to load from storage
    await loadStoredToken();
    return _calendarAccessToken;
  }
  
  // Request fresh calendar token (shows popup on web) - only call explicitly
  Future<bool> requestCalendarAccess() async {
    try {
      if (kIsWeb) {
        final user = _auth.currentUser;
        if (user != null) {
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
            await _saveToken();
            if (kDebugMode) {
              debugPrint('Calendar access granted, token obtained');
            }
            return true;
          }
        }
      } else {
        // For mobile, try full sign-in again to ensure scopes
        final googleUser = await _googleSignIn.signIn();
        if (googleUser != null) {
          final auth = await googleUser.authentication;
          _calendarAccessToken = auth.accessToken;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
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
  
  // Force re-authenticate to get fresh tokens (use when calendar fails)
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
