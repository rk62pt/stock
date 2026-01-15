import 'dart:convert';
// import 'dart:io' show Platform; // Removed
// import 'package:flutter/foundation.dart' show kIsWeb; // Removed
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import 'database_helper.dart';

class StockService {
  // API Key is now passed in
  // API Key is now passed in
  static Future<List<StockData>> fetchStockQuotes(
      List<String> symbols, String apiKey) async {
    if (symbols.isEmpty || apiKey.isEmpty) return [];

    // Fugle API v1.0 is per-symbol.
    // We implement batching to respect rate limits (approx 60/min = 1/sec).
    // Batch size: 3, Delay: 1s => 3 stocks / 1s = ~180/min burst, but safe for short lists.
    // If list is long, it will take time but won't error.

    final List<StockData> allResults = [];
    const int batchSize = 3;

    for (var i = 0; i < symbols.length; i += batchSize) {
      final end =
          (i + batchSize < symbols.length) ? i + batchSize : symbols.length;
      final batch = symbols.sublist(i, end);

      print('Fetching batch ${i ~/ batchSize + 1}: $batch');

      final futures =
          batch.map((symbol) => _fetchSingleFugleQuote(symbol, apiKey));
      final results = await Future.wait(futures);

      allResults.addAll(results.where((s) => s != null).cast<StockData>());

      // Add delay if there are more batches to come
      if (end < symbols.length) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }

    return allResults;
  }

  static Future<StockData?> _fetchSingleFugleQuote(
      String symbol, String apiKey) async {
    try {
      // API: https://api.fugle.tw/marketdata/v1.0/stock/intraday/quote/{symbol}
      final url = Uri.parse(
          'https://api.fugle.tw/marketdata/v1.0/stock/intraday/quote/$symbol');

      final response = await http.get(
        url,
        headers: {'X-API-KEY': apiKey},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseFugleStock(data, symbol);
      } else {
        print('Failed to fetch Fugle data for $symbol: ${response.statusCode}');
        print('Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching Fugle stock $symbol: $e');
      return null;
    }
  }

  static Future<int> syncStockList(String apiKey, {bool force = false}) async {
    final lastSync = await DatabaseHelper().getLastSyncTime();
    final now = DateTime.now().millisecondsSinceEpoch;
    final count = await DatabaseHelper().getStockSymbolCount();

    // 24 hours = 86400000 ms
    // Sync if: Force OR Never synced OR table empty OR > 24h ago
    bool shouldSync = force ||
        (lastSync == null) ||
        (count == 0) ||
        ((now - lastSync) >= 86400000);

    if (!shouldSync) {
      print(
          'Stock list sync skipped (Count: $count, Last Sync: ${DateTime.fromMillisecondsSinceEpoch(lastSync!)})');
      return 0;
    }

    print('Starting stock list sync...');
    final List<Map<String, dynamic>> allTickers = [];

    // Fetch TWSE
    allTickers.addAll(await _fetchExchangeTickers('TWSE', apiKey));
    // Fetch TPEx
    allTickers.addAll(await _fetchExchangeTickers('TPEx', apiKey));

    if (allTickers.isNotEmpty) {
      await DatabaseHelper().batchInsertStockSymbols(allTickers);
      await DatabaseHelper().setLastSyncTime(now);
      print(
          'Stock list sync completed. Inserted ${allTickers.length} symbols.');
      return allTickers.length;
    } else {
      print('Stock list sync failed or empty. (Got ${allTickers.length})');
      return 0; // or throw
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchExchangeTickers(
      String exchange, String apiKey) async {
    try {
      // Simplify params: type=EQUITY, exchange=...
      final uri = Uri.parse(
              'https://api.fugle.tw/marketdata/v1.0/stock/intraday/tickers')
          .replace(queryParameters: {
        'type': 'EQUITY',
        'exchange': exchange,
        // 'isNormal': 'true', // Removed to ensure we get data first
      });

      print('Fetching tickers: $uri');
      final response = await http.get(uri, headers: {'X-API-KEY': apiKey});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] is List) {
          final list = data['data'] as List;
          print('Fetched ${list.length} tickers for $exchange');
          return list.map((item) {
            return {
              'symbol': item['symbol'],
              'name': item['name'],
              'type': item['type'],
            };
          }).toList();
        }
      } else {
        print(
            'Failed to fetch $exchange tickers: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching tickers for $exchange: $e');
    }
    return [];
  }

  static Future<List<StockData>> searchStocks(
      String query, String apiKey) async {
    if (apiKey.isEmpty) return [];

    // 1. Try Local Search
    try {
      final localResults = await DatabaseHelper().searchLocalSymbols(query);
      if (localResults.isNotEmpty) {
        return localResults.map((map) {
          return StockData(
            symbol: map['symbol'] as String,
            regularMarketPrice: 0, // Price unknown in search
            regularMarketChange: 0,
            regularMarketChangePercent: 0,
            shortName: map['name'] as String,
            longName: map['name'] as String,
          );
        }).toList();
      }
    } catch (e) {
      print('Local search error: $e');
    }

    // 2. Fallback to Online "Exact Match" (Previous Logic)
    // If local DB is empty or miss, try to treat query as symbol
    // Only if query looks like a symbol (digits)

    // Attempt to treat query as symbol
    final stock = await _fetchSingleFugleQuote(query, apiKey);
    if (stock != null) {
      return [stock];
    }
    return [];
  }

  static StockData? _parseFugleStock(Map<String, dynamic> json, String symbol) {
    // Example Response Structure (v1.0):
    // {
    //   "symbol": "2330",
    //   "name": "台積電",
    //   ...
    //   "lastTrade": { "price": 580.0, ... },
    //   "previousClose": 575.0,
    //   "change": 5.0,
    //   "changePercent": 0.87,
    //   ...
    // }

    // Note: Fugle structure might vary slightly.
    // "lastTrade" might be null if no trade yet.

    try {
      final String name = json['name'] ?? symbol;

      double price = 0.0;
      if (json['lastTrade'] != null && json['lastTrade']['price'] != null) {
        price = (json['lastTrade']['price'] as num).toDouble();
      } else if (json['closePrice'] != null) {
        // Fallback to closePrice if no last trade (e.g. market closed)
        price = (json['closePrice'] as num).toDouble();
      }

      final double change = (json['change'] as num?)?.toDouble() ?? 0.0;
      final double changePercent =
          (json['changePercent'] as num?)?.toDouble() ?? 0.0;

      return StockData(
        symbol: json['symbol'] ?? symbol,
        regularMarketPrice: price,
        regularMarketChange: change,
        regularMarketChangePercent: changePercent,
        shortName: name,
        longName: name,
      );
    } catch (e) {
      print('Error parsing Fugle JSON for $symbol: $e');
      return null;
    }
  }
}
