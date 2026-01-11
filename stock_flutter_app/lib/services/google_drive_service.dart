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

  // No fixed filename anymore
  // final String _backupFileName = 'stock_app_backup.json';

  Future<List<drive.File>> listBackups() async {
    if (_driveApi == null) return [];

    try {
      final fileList = await _driveApi!.files.list(
        spaces: 'appDataFolder',
        q: "name contains 'stock_backup_'",
        orderBy: 'createdTime desc', // Newest first
        $fields: 'files(id, name, createdTime, modifiedTime, size)',
      );

      return fileList.files ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('Error listing backup files: $e');
      }
      return [];
    }
  }

  // Helper to find the latest
  Future<drive.File?> _findLatestBackup() async {
    final list = await listBackups();
    if (list.isNotEmpty) return list.first;
    return null;
  }

  Future<DateTime?> getLastBackupTime() async {
    final file = await _findLatestBackup();
    return file?.createdTime; // Use createdTime for rotating backups
  }

  Future<void> uploadBackup(String jsonContent) async {
    if (_driveApi == null) throw Exception('Not signed in');

    // 1. Create NEW file with timestamp
    // Format: stock_backup_YYYYMMDD_HHMMSS.json
    final now = DateTime.now();
    final timestamp =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
    final fileName = 'stock_backup_$timestamp.json';

    final uploadMedia = drive.Media(
      Future.value(utf8.encode(jsonContent)).asStream(),
      utf8.encode(jsonContent).length,
    );

    final newFile = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder'];

    await _driveApi!.files.create(
      newFile,
      uploadMedia: uploadMedia,
    );

    // 2. Prune old backups (Keep latest 10)
    await _pruneOldBackups();
  }

  Future<void> _pruneOldBackups() async {
    final list = await listBackups(); // Sorted by createdTime desc
    if (list.length > 10) {
      // Delete from 11th onwards
      final toDelete = list.sublist(10);
      for (var file in toDelete) {
        try {
          if (file.id != null) {
            print('Pruning old backup: ${file.name}');
            await _driveApi!.files.delete(file.id!);
          }
        } catch (e) {
          print('Error pruning file ${file.id}: $e');
        }
      }
    }
  }

  Future<String?> downloadBackup(String fileId) async {
    if (_driveApi == null) throw Exception('Not signed in');

    final method = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await method.stream.forEach(bytes.addAll);

    return utf8.decode(bytes);
  }
}
