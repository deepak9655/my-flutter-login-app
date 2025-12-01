// lib/services/auth_service.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isGuestMode = false;
  static const String _keyGuestMode = 'guest_mode';

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _currentUser != null;
  bool get isGuestMode => _isGuestMode;

  AuthService() {
    _checkExistingSignIn();
    _loadGuestMode();
  }

  Future<void> _loadGuestMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isGuestMode = prefs.getBool(_keyGuestMode) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading guest mode: $e');
    }
  }

  // Check if user is already signed in
  Future<void> _checkExistingSignIn() async {
    try {
      _isLoading = true;
      notifyListeners();

      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        _errorMessage = null;
      }
    } catch (e) {
      // Silent sign-in failed, user needs to sign in manually
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        _errorMessage = null;
        _isGuestMode = false; // Clear guest mode when signing in with Google
        
        // Clear guest mode preference
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyGuestMode, false);
        } catch (e) {
          debugPrint('Error clearing guest mode: $e');
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // User cancelled sign-in
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Sign-in failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      debugPrint('Google Sign-In Error: $e');
      return false;
    }
  }

  // Sign in as guest
  Future<void> signInAsGuest() async {
    _isLoading = true;
    notifyListeners();
    
    _isGuestMode = true;
    _currentUser = null;
    _errorMessage = null;
    
    // Persist guest mode
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyGuestMode, true);
    } catch (e) {
      debugPrint('Error saving guest mode: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (!_isGuestMode) {
        await _googleSignIn.signOut();
      }
      _currentUser = null;
      _errorMessage = null;
      _isGuestMode = false;
      
      // Clear guest mode preference
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyGuestMode, false);
      } catch (e) {
        debugPrint('Error clearing guest mode: $e');
      }
    } catch (e) {
      _errorMessage = 'Sign-out failed: ${e.toString()}';
      debugPrint('Sign-out Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get user display name
  String? get displayName => _currentUser?.displayName;

  // Get user email
  String? get email => _currentUser?.email;

  // Get user photo URL
  String? get photoUrl => _currentUser?.photoUrl;
}

