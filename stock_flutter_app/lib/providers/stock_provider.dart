import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../services/database_helper.dart';

class StockProvider with ChangeNotifier {
  List<String> _watchlist = ['2330', '0050', '2454']; // Removed .TW
  List<StockData> _stocks = [];
  bool _isLoading = false;
  String? _error;
  Timer? _timer;
  String _apiKey = '';

  List<String> get watchlist => _watchlist;
  List<StockData> get stocks => _stocks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get apiKey => _apiKey;

  StockProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadApiKey();
    await _loadWatchlist();
    fetchStocks();
    _startPolling();
  }

  Future<void> _loadApiKey() async {
    _apiKey = await DatabaseHelper().getApiKey() ?? '';
    notifyListeners();
  }

  Future<void> setApiKey(String key) async {
    await DatabaseHelper().saveApiKey(key);
    _apiKey = key;
    notifyListeners();
    // Refresh stocks immediately with new key
    if (_apiKey.isNotEmpty) {
      fetchStocks();
    }
  }

  Future<void> _loadWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('watchlist');
    if (saved != null) {
      // Migrate old data: remove .TW suffix if present
      _watchlist = saved.map((s) => s.replaceAll('.TW', '')).toList();
    }
    notifyListeners();
  }

  Future<void> _saveWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('watchlist', _watchlist);
  }

  Future<void> fetchStocks() async {
    // If we have no API key, we can't fetch.
    if (_apiKey.isEmpty) {
      // Maybe set error?
      // _error = '請先設定 API Key';
      // notifyListeners();
      return;
    }

    if (_watchlist.isEmpty) {
      _stocks = [];
      notifyListeners();
      return;
    }

    // Only show loading indicator on initial load to avoid flickering during polling
    if (_stocks.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _error = null;
      final stocks = await StockService.fetchStockQuotes(_watchlist, _apiKey);
      _stocks = stocks;

      // Sort to match watchlist order
      // Create a map for quick lookup
      final stockMap = {for (var s in stocks) s.symbol: s};

      // Rebuild list based on watchlist order, filtering out any missing ones
      _stocks = _watchlist
          .map((symbol) => stockMap[symbol])
          .where((s) => s != null)
          .cast<StockData>()
          .toList();
    } catch (e) {
      _error = '無法取得股價資訊';
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 65), (timer) {
      fetchStocks();
    });
  }

  Future<void> addStock(String symbol) async {
    if (!_watchlist.contains(symbol)) {
      _watchlist.add(symbol);
      await _saveWatchlist();
      await fetchStocks();
    }
  }

  Future<void> removeStock(String symbol) async {
    _watchlist.remove(symbol);
    _stocks.removeWhere((s) => s.symbol == symbol);
    await _saveWatchlist();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
