import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../services/stock_service.dart';
import '../services/database_helper.dart';
import 'package:google_sign_in/widgets.dart'; // For GoogleUserCircleAvatar
import '../services/google_drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import '../services/portfolio_service.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _keyController;
  bool _isSyncing = false;
  int _dbCount = 0; // Added _dbCount

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<StockProvider>(context, listen: false);
    _keyController = TextEditingController(text: provider.apiKey);
    _refreshDbCount(); // Called _refreshDbCount in initState
  }

  Future<void> _refreshDbCount() async {
    final count = await DatabaseHelper().getStockSymbolCount();
    if (mounted) {
      setState(() {
        _dbCount = count;
      });
    }
  }

  Future<void> _syncStocks() async {
    final provider = Provider.of<StockProvider>(context, listen: false);
    if (provider.apiKey.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請先儲存 API Key')));
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      // Force sync
      final count =
          await StockService.syncStockList(provider.apiKey, force: true);
      await _refreshDbCount(); // Refresh display

      if (mounted) {
        if (count > 0) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('同步完成，新增 $count 筆股票')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('同步回傳 0 筆資料 (請確認 API Key 權限或網路)'))); // Modified message
        }
      }
    } catch (e) {
      print('Sync error: $e'); // Added print statement
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('同步失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '富果 API Key',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '請輸入您的 Fugle Market Data API Key 來啟用行情功能。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '輸入 API Key',
                labelText: 'API Key',
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final key = _keyController.text.trim();
                  if (key.isNotEmpty) {
                    await Provider.of<StockProvider>(context, listen: false)
                        .setApiKey(key);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API Key 已儲存')),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('儲存'),
              ),
            ),
            const Divider(height: 48),
            // Transaction Settings
            const Text(
              '交易設定',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '設定券商手續費折數，用於計算損益 (範圍 0.1 ~ 10, 如 2.8 折請輸入 2.8)。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildBrokerDiscountInput(context),

            const Divider(height: 48),
            // Cloud Sync Section
            const Text(
              '雲端備份 (Google Drive)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '將您的交易紀錄備份到 Google Drive 應用程式資料夾 (隱藏)。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildSyncSection(),

            const Divider(height: 48),
            // Local Backup Section
            const Text(
              '本機備份 (JSON)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '匯出或匯入交易紀錄 (JSON 格式)，可用於不同裝置間轉移或是手動備份。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _buildLocalBackupSection(context),

            const Divider(height: 48),
            const Text(
              '股票資料庫',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '目前資料庫筆數: $_dbCount',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            const Text(
              '若搜尋不到股票，請嘗試手動下載最新清單 (需花費約 5-10 秒)。',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_download),
                label: Text(_isSyncing ? '同步中...' : '手動下載股票清單'),
                onPressed: _isSyncing ? null : _syncStocks,
              ),
            ),
            const SizedBox(height: 80), // Prevent bottom clipping
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSection() {
    return Consumer<GoogleDriveService>(
      builder: (context, driveService, child) {
        if (!driveService.isSignedIn) {
          return SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('登入 Google Drive'),
              onPressed: () async {
                try {
                  await driveService.signIn();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('登入成功')));
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('登入失敗: $e')));
                }
              },
            ),
          );
        }

        return Column(
          children: [
            ListTile(
              leading:
                  GoogleUserCircleAvatar(identity: driveService.currentUser!),
              title: Text(driveService.currentUser!.displayName ?? ''),
              subtitle: Text(driveService.currentUser!.email),
              trailing: IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await driveService.signOut();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('已登出')));
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('立即備份'),
                    onPressed: _isSyncing ? null : () => _backup(driveService),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('還原資料'),
                    onPressed: _isSyncing ? null : () => _restore(driveService),
                  ),
                ),
              ],
            ),
            FutureBuilder<DateTime?>(
              future: driveService.getLastBackupTime(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('檢查備份中...',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                }
                if (snapshot.hasData && snapshot.data != null) {
                  // Simple formatting
                  final date = snapshot.data!.toLocal();
                  return Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('上次備份: $date',
                        style:
                            const TextStyle(color: Colors.green, fontSize: 12)),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('尚無雲端備份',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _backup(GoogleDriveService driveService) async {
    setState(() => _isSyncing = true);
    try {
      final json = PortfolioService().exportData();
      await driveService.uploadBackup(json);
      // Refresh UI state (last backup time)
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('備份成功')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('備份失敗: $e')));
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _restore(GoogleDriveService driveService) async {
    setState(() => _isSyncing = true);

    try {
      // 1. Fetch list of backups
      final backups = await driveService.listBackups();

      if (backups.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('雲端無備份資料')));
        }
        return;
      }

      setState(() => _isSyncing = false); // Pause spinner to show dialog

      if (!mounted) return;

      // 2. Show selection dialog
      final drive.File? selectedFile = await showDialog<drive.File>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('選擇要還原的備份'),
          children: backups.map((file) {
            String dateStr = 'Unknown Date';
            if (file.createdTime != null) {
              dateStr = file.createdTime!.toLocal().toString().split('.')[0];
            }
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, file),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(file.name ?? 'Unknown',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );

      if (selectedFile == null || selectedFile.id == null) return;

      // 3. Confirm overwrite
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('確認還原'),
          content: Text(
              '將使用備份 (${selectedFile.createdTime?.toLocal().toString().split('.')[0]})\n還原將會覆蓋本機目前的交易紀錄，確定要繼續嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('確定還原', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      setState(() => _isSyncing = true);

      // 4. Download and Import
      final json = await driveService.downloadBackup(selectedFile.id!);
      if (json != null) {
        await PortfolioService().importData(json);
        if (mounted) {
          // Force refresh provider
          final provider = Provider.of<StockProvider>(context, listen: false);

          // Sync watchlist with restored transactions
          final allSymbols =
              PortfolioService().transactions.map((t) => t.symbol).toList();
          await provider.addStocks(allSymbols);

          await provider.refreshMetrics();
          await provider.fetchStocks();

          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('還原成功，請回到首頁查看')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('下載失敗或是空檔案')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('還原失敗: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Widget _buildBrokerDiscountInput(BuildContext context) {
    final provider = Provider.of<StockProvider>(context);
    // Stored is multiplier (e.g. 0.28), display is X折 (e.g. 2.8)
    // So Initial Text = multiplier * 10
    double displayVal = provider.brokerDiscount * 10;
    // Strip trailing zero if integer (e.g. 6.0 -> 6)
    String textVal = displayVal.toStringAsFixed(2);
    if (textVal.endsWith('00'))
      textVal = textVal.substring(0, textVal.length - 3);
    else if (textVal.endsWith('0'))
      textVal = textVal.substring(0, textVal.length - 1);

    final TextEditingController controller =
        TextEditingController(text: textVal);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '手續費折數 (ex: 2.8)',
                hintText: '2.8',
                suffixText: '折'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: () async {
            final val = double.tryParse(controller.text);
            if (val != null && val > 0 && val <= 10) {
              // Input 2.8 -> 0.28 multiplier
              double multiplier = val / 10.0;

              await provider.setSettings(discount: multiplier); // Store 0.28
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已儲存折數: $val 折 (倍率 $multiplier)')));
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請輸入有效折數 (0.1 ~ 10)')));
              }
            }
          },
          child: const Text('儲存'),
        ),
      ],
    );
  }

  Widget _buildLocalBackupSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('匯出檔案'),
            onPressed: () => _exportTransactions(context),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.file_upload),
            label: const Text('匯入檔案'),
            onPressed: () => _importTransactions(context),
          ),
        ),
      ],
    );
  }

  Future<void> _exportTransactions(BuildContext context) async {
    try {
      final jsonString = PortfolioService().exportData();
      final tempDir = await getTemporaryDirectory();
      final dateStr =
          DateTime.now().toIso8601String().split('T')[0].replaceAll('-', '');
      final file = File('${tempDir.path}/stock_backup_$dateStr.json');
      await file.writeAsString(jsonString);

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Stock App Transaction Backup',
      );

      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('匯出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯出失敗: $e')),
        );
      }
    }
  }

  Future<void> _importTransactions(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final File file = File(result.files.single.path!);
        final jsonString = await file.readAsString();

        // Confirm overwrite
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('確認匯入'),
            content: const Text('匯入將會覆蓋本機目前的交易紀錄，確定要繼續嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('確定匯入', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        await PortfolioService().importData(jsonString);

        if (mounted) {
          final provider = Provider.of<StockProvider>(context, listen: false);

          final allSymbols =
              PortfolioService().transactions.map((t) => t.symbol).toList();
          await provider.addStocks(allSymbols);

          await provider.refreshMetrics();
          await provider.fetchStocks();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('匯入成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯入失敗: $e')),
        );
      }
    }
  }
}
