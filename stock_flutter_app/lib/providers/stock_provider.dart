import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../services/database_helper.dart';
import '../services/portfolio_service.dart';

class StockProvider with ChangeNotifier {
  List<String> _watchlist = ['2330', '0050', '2454']; // Removed .TW
  List<StockData> _stocks = [];
  bool _isLoading = false;
  String? _error;
  Timer? _timer;
  String _apiKey = '';

  // Dashboard Metrics State
  Map<String, PortfolioMetrics> _symbolMetrics = {};
  double _periodRealizedPL = 0;
  TimePeriod _selectedPeriod = TimePeriod.month;

  // Getters
  List<String> get watchlist => _watchlist;
  List<StockData> get stocks => _stocks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get apiKey => _apiKey;

  TimePeriod get selectedPeriod => _selectedPeriod;
  double get periodRealizedPL => _periodRealizedPL;

  StockProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadApiKey();
    await _loadWatchlist();
    await _refreshPortfolioMetrics(); // Load initial portfolio data
    _startPolling();
  }

  Future<void> _loadApiKey() async {
    _apiKey = await DatabaseHelper().getApiKey() ?? '';
    // If we have key, fetch stocks. If it's empty, we wait for user.
    if (_apiKey.isNotEmpty) {
      // We can call setApiKey implicitly or just store it.
      // StockService needs it passed, or we set it globally.
      // In previous steps we set it via StockService().setApiKey?
      // No, we pass it in fetch.
      // But wait, `StockService` (static) methods take key.
      // `PortfolioService` uses DB.
    }
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
    // Fetch immediately then periodic
    fetchStocks();
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

  // --- Metrics Logic ---

  Future<void> _refreshPortfolioMetrics() async {
    _symbolMetrics = await PortfolioService().getAllPortfolioMetrics();
    await _calculatePeriodRealizedPL();
    notifyListeners();
  }

  Future<void> refreshMetrics() async {
    await _refreshPortfolioMetrics();
  }

  Future<void> setPeriod(TimePeriod p) async {
    _selectedPeriod = p;
    await _calculatePeriodRealizedPL();
    notifyListeners();
  }

  Future<void> _calculatePeriodRealizedPL() async {
    DateTime now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (_selectedPeriod) {
      case TimePeriod.day:
        start = DateTime(now.year, now.month, now.day);
        break;
      case TimePeriod.month:
        start = DateTime(now.year, now.month, 1);
        break;
      case TimePeriod.quarter:
        // Q1: 1-3, Q2: 4-6, ...
        int quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        start = DateTime(now.year, quarterStartMonth, 1);
        break;
      case TimePeriod.year:
        start = DateTime(now.year, 1, 1);
        break;
    }

    _periodRealizedPL = await PortfolioService().getRealizedProfit(start, end);
  }

  // 1. Total Daily P/L (Only active stocks)
  double get totalDailyPL {
    double total = 0;
    for (var stock in _stocks) {
      // Use _stocks (fetched data) + metrics
      final metrics = _symbolMetrics[stock.symbol];
      if (metrics != null && metrics.totalShares > 0) {
        total += stock.regularMarketChange * metrics.totalShares;
      }
    }
    return total;
  }

  // 2. Total Unrealized P/L (Only active stocks)
  double get totalUnrealizedPL {
    double total = 0;
    for (var stock in _stocks) {
      final metrics = _symbolMetrics[stock.symbol];
      if (metrics != null && metrics.totalShares > 0) {
        double marketValue = stock.regularMarketPrice * metrics.totalShares;
        double cost = metrics.avgCost * metrics.totalShares;
        total += (marketValue - cost);
      }
    }
    return total;
  }

  // Helper to check if stock is active
  bool isStockActive(String symbol) {
    final metrics = _symbolMetrics[symbol];
    // Active if has shares.
    // If we made a profit (realized) but have 0 shares, it's NOT active (it's settled).
    return metrics != null && metrics.totalShares > 0;
  }

  // Helper to get metrics for a stock
  PortfolioMetrics? getMetrics(String symbol) => _symbolMetrics[symbol];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

enum TimePeriod {
  day,
  month,
  quarter,
  year,
}
