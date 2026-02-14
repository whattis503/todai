import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

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
    // Return stored access token if available and not expired
    if (_calendarAccessToken != null && _calendarAccessToken!.isNotEmpty) {
      if (_tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
        if (kDebugMode) {
          debugPrint('Using cached calendar access token');
        }
        return _calendarAccessToken;
      } else {
        if (kDebugMode) {
          debugPrint('Access token expired, attempting refresh...');
        }
      }
    }
    
    try {
      if (kIsWeb) {
        // For web, if token is expired or not available, need to re-authenticate
        final user = _auth.currentUser;
        if (user != null && (_calendarAccessToken == null || 
            (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)))) {
          if (kDebugMode) {
            debugPrint('Attempting to refresh token via re-authentication...');
          }
          
          GoogleAuthProvider googleProvider = GoogleAuthProvider();
          googleProvider.addScope('https://www.googleapis.com/auth/calendar');
          googleProvider.addScope('https://www.googleapis.com/auth/calendar.events');
          googleProvider.addScope('https://www.googleapis.com/auth/calendar.readonly');
          
          try {
            final result = await user.reauthenticateWithPopup(googleProvider);
            if (result.credential != null && result.credential!.accessToken != null) {
              _calendarAccessToken = result.credential!.accessToken;
              _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
              if (kDebugMode) {
                debugPrint('Token refreshed successfully');
              }
              return _calendarAccessToken;
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Re-authentication error: $e');
            }
            // Don't throw, just return null to indicate token unavailable
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
          return auth.accessToken;
        }
        return null;
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
  
  // Request fresh calendar token (shows popup on web)
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
