import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../services/stock_service.dart';
import '../services/database_helper.dart';

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
          ],
        ),
      ),
    );
  }
}
