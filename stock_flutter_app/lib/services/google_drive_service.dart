import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GoogleDriveService extends ChangeNotifier {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
    ],
  );

  GoogleSignInAccount? _currentUser;
  drive.DriveApi? _driveApi;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  // Initialize checks if already signed in
  Future<void> init() async {
    _googleSignIn.onCurrentUserChanged.listen((account) async {
      print('User changed: $account');
      _currentUser = account;
      if (account != null) {
        // Create Drive API client
        final httpClient = await _googleSignIn.authenticatedClient();
        if (httpClient != null) {
          _driveApi = drive.DriveApi(httpClient);
        }
      } else {
        _driveApi = null;
      }
      notifyListeners();
    });

    await _googleSignIn.signInSilently();
  }

  Future<void> signIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      if (kDebugMode) {
        print('Sign in failed: $error');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  // --- Drive Operations ---

  final String _backupFileName = 'stock_app_backup.json';

  Future<drive.File?> _findBackupFile() async {
    if (_driveApi == null) return null;

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id, name, createdTime, modifiedTime)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error finding backup file: $e');
      }
      return null;
    }
  }

  Future<DateTime?> getLastBackupTime() async {
    final file = await _findBackupFile();
    return file?.modifiedTime;
  }

  Future<void> uploadBackup(String jsonContent) async {
    if (_driveApi == null) throw Exception('Not signed in');

    final existingFile = await _findBackupFile();

    final uploadMedia = drive.Media(
      Future.value(utf8.encode(jsonContent)).asStream(),
      utf8.encode(jsonContent).length,
    );

    if (existingFile != null) {
      // Update existing
      await _driveApi!.files.update(
        drive.File(),
        existingFile.id!,
        uploadMedia: uploadMedia,
      );
    } else {
      // Create new
      final newFile = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];

      await _driveApi!.files.create(
        newFile,
        uploadMedia: uploadMedia,
      );
    }
  }

  Future<String?> downloadBackup() async {
    if (_driveApi == null) throw Exception('Not signed in');

    final existingFile = await _findBackupFile();
    if (existingFile == null) return null; // No backup found

    final method = await _driveApi!.files.get(
      existingFile.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await method.stream.forEach(bytes.addAll);

    return utf8.decode(bytes);
  }
}
