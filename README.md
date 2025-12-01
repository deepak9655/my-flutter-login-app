# Repair Shop — Flutter with Google Drive & Excel Export

This project extends the previous starter with:
- Google Drive connectivity (Google Sign-In + Drive API)
- Export job list to Excel (.xlsx)
- Animations and polished transitions

## Google Drive setup (required one-time)
1. Go to https://console.developers.google.com/ and create a project.
2. Enable the Google Drive API for the project.
3. Create OAuth credentials (OAuth Client ID) for Android / iOS and also an OAuth Client ID for "Web" if you test in browser.
4. For Android, add your app's package name and SHA-1. For testing, you can use web client for browser flows.
5. Copy the OAuth client ID and place it into the app where indicated (see `lib/google_drive.dart` comments).

## How to run
1. `flutter pub get`
2. In `lib/google_drive.dart` set your OAuth client ID for web (if testing in browser) or configure Android/iOS native configs.
3. `flutter run`

Notes:
- Excel export uses the `excel` package and writes to app documents directory; you can then upload the XLSX to Google Drive via the Drive API button.
- The Drive integration uses google_sign_in for auth and googleapis.drive.v3 to upload files.
- This is a starter integration; for production, secure OAuth credentials and configure consent screen correctly.
