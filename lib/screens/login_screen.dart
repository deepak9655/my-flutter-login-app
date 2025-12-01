// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthService>(
          builder: (context, authService, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withAlpha(178),
                    Colors.indigo.shade300,
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Logo/Icon
                      Image.asset(
                        'assets/images/app_logo.png',
                        height: 120,
                        width: 120,
                      ),
                      const SizedBox(height: 30),

                      // App Title
                      const Text(
                        'Repair Shop Pro',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle
                      Text(
                        'Manage your repair business efficiently',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withAlpha(230),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 60),

                      // Google Sign-In Button
                      _buildGoogleSignInButton(context, authService),

                      const SizedBox(height: 16),

                      // Divider with "OR"
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.white.withAlpha(128))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white.withAlpha(128))),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Guest Login Button
                      _buildGuestLoginButton(context, authService),

                      const SizedBox(height: 20),

                      // Error Message
                      if (authService.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authService.errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 40),

                      // Info Text
                      Text(
                        'By signing in, you agree to use Google Drive for data backup and synchronization.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(204),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton(
      BuildContext context, AuthService authService) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF4285F4), // Google Blue
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: authService.isLoading
              ? null
              : () => _handleGoogleSignIn(context, authService),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (authService.isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  _buildGoogleLogo(),
                const SizedBox(width: 12),
                Text(
                  authService.isLoading
                      ? 'Signing in...'
                      : 'Continue with Google',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(
      BuildContext context, AuthService authService) async {
    final success = await authService.signInWithGoogle();

    if (success && context.mounted) {
      // Navigate to home screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (!success && context.mounted && authService.errorMessage != null) {
      // Show error snackbar if sign-in failed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authService.errorMessage ?? 'Sign-in failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildGuestLoginButton(
      BuildContext context, AuthService authService) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(77), width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: authService.isLoading
              ? null
              : () => _handleGuestSignIn(context, authService),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (authService.isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(
                    Icons.person_outline,
                    size: 24,
                    color: Colors.white,
                  ),
                const SizedBox(width: 12),
                const Text(
                  'Continue as Guest',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGuestSignIn(
      BuildContext context, AuthService authService) async {
    await authService.signInAsGuest();

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  // Build simple Google logo - a colorful 'G'
  Widget _buildGoogleLogo() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4285F4), // Google Blue
        ),
      ),
    );
  }
}
