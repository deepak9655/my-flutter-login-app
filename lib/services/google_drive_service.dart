// lib/services/google_drive_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

// This service is now only responsible for handling Google Drive operations.
// It can use a separate Google account for uploads if configured.

class GoogleDriveService {
  // Use both scopes to allow file creation and file manipulation
  // This can be a separate instance from AuthService for different account
  final GoogleSignIn _gs = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveScope,
    ],
  );
  
  // Separate GoogleSignIn instance for Drive uploads (different account)
  final GoogleSignIn _driveGs = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      drive.DriveApi.driveScope,
    ],
  );
  
  bool _useSeparateAccount = false;
  
  void setUseSeparateAccount(bool value) {
    _useSeparateAccount = value;
  }

  // A simple client that attaches the authentication headers
  Future<http.Client> getAuthenticatedClient({bool forceNewSignIn = false}) async {
    try {
      // Use separate account if configured
      final googleSignIn = _useSeparateAccount ? _driveGs : _gs;
      
      GoogleSignInAccount? account;
      
      if (forceNewSignIn) {
        // Force new sign-in (for separate account)
        account = await googleSignIn.signIn();
      } else {
        // First, try to get the current user silently (if already signed in)
        account = await googleSignIn.signInSilently();
        
        // If silent sign-in fails, try interactive sign-in
        account ??= await googleSignIn.signIn();
      }
      
      if (account == null) {
        throw Exception('Sign-in cancelled or failed. Please try again.');
      }

      // Request additional scopes if needed (this returns a bool)
      try {
        final hasScopes = await googleSignIn.requestScopes([
          drive.DriveApi.driveFileScope,
          drive.DriveApi.driveScope,
        ]);

        // If scopes were denied, get the account again after scope request
        if (!hasScopes) {
          account = await googleSignIn.signIn();
          if (account == null) {
            throw Exception('Permission denied. Please grant Google Drive access.');
          }
        }
      } catch (e) {
        // If scope request fails, continue with existing account
        debugPrint('Scope request warning: $e');
      }

      // Ensure account is still valid after scope request
      if (account == null) {
        throw Exception('Sign-in failed. Please try again.');
      }

      final authHeaders = await account.authHeaders;
      if (authHeaders.isEmpty) {
        throw Exception('Failed to get authentication headers.');
      }

      return AuthenticatedClient(authHeaders);
    } catch (e) {
      // Handle specific error cases
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('cancel') || errorString.contains('cancelled')) {
        throw Exception('Sign-in was cancelled.');
      } else if (errorString.contains('network') || errorString.contains('connection')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Authentication failed: ${e.toString()}');
      }
    }
  }
  
  // Get current Drive account email (if signed in)
  Future<String?> getCurrentDriveAccountEmail() async {
    try {
      final googleSignIn = _useSeparateAccount ? _driveGs : _gs;
      final account = await googleSignIn.signInSilently();
      return account?.email;
    } catch (e) {
      return null;
    }
  }
  
  // Sign out from Drive account
  Future<void> signOutDrive() async {
    if (_useSeparateAccount) {
      await _driveGs.signOut();
    }
  }

  // UPLOAD FILE: This is now the entry point for authentication.
  Future<String?> uploadFile(File file, {bool forceNewSignIn = false}) async {
    try {
      final client = await getAuthenticatedClient(forceNewSignIn: forceNewSignIn);
      final api = drive.DriveApi(client);

      final media = drive.Media(file.openRead(), file.lengthSync());

      final f = drive.File()
        ..name = file.path.split(Platform.pathSeparator).last
        ..mimeType =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'; // Set MIME type for Excel

      final createdFile = await api.files.create(f, uploadMedia: media);

      // OPTIONAL: Make the file world readable so the link can be viewed easily
      try {
        await api.permissions.create(
          drive.Permission(type: 'anyone', role: 'reader'),
          createdFile.id!,
        );
      } catch (e) {
        // Permission setting failed, but file was uploaded
        debugPrint('Warning: Could not set file permissions: $e');
      }

      // Return the web link to the created file
      return createdFile.webViewLink;
    } catch (e) {
      // Handle cancellation gracefully
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('cancel') || 
          errorString.contains('cancelled') ||
          errorString.contains('user cancelled')) {
        return null; // Return null for cancellation (not an error)
      }
      // Re-throw other errors
      rethrow;
    }
  }

  // Since we no longer use a dedicated login screen, this is the sign-out function
  Future<void> signOut() => _gs.signOut();
}

// Small IO Client that attaches auth headers
class AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client(); // Changed to standard http.Client
  AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
