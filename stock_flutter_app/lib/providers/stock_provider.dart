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
  String _apiKey = '';

  // Dashboard Metrics State
  Map<String, PortfolioMetrics> _symbolMetrics = {};
  double _periodRealizedPL = 0;
  TimePeriod _selectedPeriod = TimePeriod.month;

  // Advanced Settings
  bool _includeFees = true;
  bool _includeDividends = true;
  double _brokerDiscount = 1.0; // 1.0 = No discount, 0.6 = 6 fold

  // Getters
  List<String> get watchlist => _watchlist;
  List<StockData> get stocks => _stocks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get apiKey => _apiKey;

  TimePeriod get selectedPeriod => _selectedPeriod;
  double get periodRealizedPL => _periodRealizedPL;

  bool get includeFees => _includeFees;
  bool get includeDividends => _includeDividends;
  double get brokerDiscount => _brokerDiscount;

  StockProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadApiKey();
    await _loadSettings(); // Load settings first
    await _loadWatchlist();
    await PortfolioService().loadTransactions(); // Load local data on startup
    await _refreshPortfolioMetrics(); // Load initial portfolio data
    await _refreshPortfolioMetrics(); // Load initial portfolio data
    await _loadCachedPrices(); // Load cached prices for immediate UI
  }

  Future<void> _loadCachedPrices() async {
    try {
      final cachedMaps = await DatabaseHelper().getLatestStockPrices();
      if (cachedMaps.isNotEmpty) {
        // Parse and sort by watchlist if needed, or just display ALL cached?
        // Let's filter by watchlist to stay consistent.
        final allCached = cachedMaps.map((m) => StockData.fromJson(m)).toList();
        final map = {for (var s in allCached) s.symbol: s};

        _stocks = _watchlist
            .map((symbol) => map[symbol])
            .where((s) => s != null)
            .cast<StockData>()
            .toList();

        notifyListeners();
      }
    } catch (e) {
      print('Error loading cached prices: $e');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _includeFees = prefs.getBool('includeFees') ?? true;
    _includeDividends = prefs.getBool('includeDividends') ?? true;
    _brokerDiscount = prefs.getDouble('brokerDiscount') ?? 1.0;
  }

  Future<void> setSettings(
      {bool? fees, bool? dividends, double? discount}) async {
    final prefs = await SharedPreferences.getInstance();
    if (fees != null) {
      _includeFees = fees;
      await prefs.setBool('includeFees', fees);
    }
    if (dividends != null) {
      _includeDividends = dividends;
      await prefs.setBool('includeDividends', dividends);
    }
    if (discount != null) {
      _brokerDiscount = discount;
      await prefs.setDouble('brokerDiscount', discount);
    }
    notifyListeners();
    // Refresh metrics with new settings
    await refreshMetrics();
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
      // Rebuild list based on watchlist order, filtering out any missing ones
      _stocks = _watchlist
          .map((symbol) => stockMap[symbol])
          .where((s) => s != null)
          .cast<StockData>()
          .toList();

      // Save to DB
      // We convert StockData to Map for the helper
      // StockData doesn't have toJson currently based on view (only fromJson).
      // We'll create a quick helper or add toJson to model.
      // Or just map it here.
      final List<Map<String, dynamic>> toSave = _stocks.map((s) {
        return {
          'symbol': s.symbol,
          'regularMarketPrice': s.regularMarketPrice,
          'regularMarketChange': s.regularMarketChange,
          'regularMarketChangePercent': s.regularMarketChangePercent,
          'shortName': s.shortName,
          'longName': s.longName,
        };
      }).toList();
      await DatabaseHelper().upsertStockPrices(toSave);
    } catch (e) {
      _error = '無法取得股價資訊';
      print(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStock(String symbol) async {
    if (!_watchlist.contains(symbol)) {
      _watchlist.add(symbol);
      await _saveWatchlist();
      await fetchStocks();
    }
  }

  Future<void> addStocks(List<String> symbols) async {
    bool changed = false;
    for (var symbol in symbols) {
      if (!_watchlist.contains(symbol)) {
        _watchlist.add(symbol);
        changed = true;
      }
    }
    if (changed) {
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
    _symbolMetrics = await PortfolioService().getAllPortfolioMetrics(
      includeFees: _includeFees,
      includeDividends: _includeDividends,
      brokerDiscount: _brokerDiscount,
    );
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

    _periodRealizedPL = await PortfolioService().getRealizedProfit(
      start,
      end,
      includeFees: _includeFees,
      includeDividends: _includeDividends,
      brokerDiscount: _brokerDiscount,
    );
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

  // 3. Total Inventory Cost
  double get totalInventoryCost {
    double total = 0;
    // Iterate metrics directly so we don't depend on fetched _stocks
    for (var metrics in _symbolMetrics.values) {
      if (metrics.totalShares > 0) {
        total += metrics.avgCost * metrics.totalShares;
      }
    }
    return total;
  }

  // 4. Total Market Value
  double get totalMarketValue {
    double total = 0;
    for (var stock in _stocks) {
      final metrics = _symbolMetrics[stock.symbol];
      if (metrics != null && metrics.totalShares > 0) {
        total += stock.regularMarketPrice * metrics.totalShares;
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
    super.dispose();
  }
}

enum TimePeriod {
  day,
  month,
  quarter,
  year,
}
