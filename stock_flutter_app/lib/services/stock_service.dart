import 'dart:convert';
// import 'dart:io' show Platform; // Removed
// import 'package:flutter/foundation.dart' show kIsWeb; // Removed
import 'package:http/http.dart' as http;
import '../models/stock.dart';

class StockService {
  // API Key is now passed in
  static Future<List<StockData>> fetchStockQuotes(
      List<String> symbols, String apiKey) async {
    if (symbols.isEmpty || apiKey.isEmpty) return [];

    // Fugle API v1.0 is per-symbol.
    // We should run them in parallel.
    // However, to be nice to rate limits (if any), we could stagger them?
    // Given the user said "60s limit", we are polling slow, so parallel fetch for 3-5 stocks is usually fine.

    final futures =
        symbols.map((symbol) => _fetchSingleFugleQuote(symbol, apiKey));
    final results = await Future.wait(futures);

    // Filter out nulls (failed requests)
    return results.where((s) => s != null).cast<StockData>().toList();
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

  static Future<List<StockData>> searchStocks(
      String query, String apiKey) async {
    if (apiKey.isEmpty) return [];

    // Fugle doesn't have a simple public search API in the free tier usually.
    // We can fallback to just returning what we have or implement a simple local filter if we had a list.
    // Since we don't have a full list anymore, we might just return empty or
    // try to fetch the query as a symbol directly?

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
