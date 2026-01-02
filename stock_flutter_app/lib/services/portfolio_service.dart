import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart'; // Removed
import 'database_helper.dart';
import '../models/transaction.dart';

import 'package:flutter/foundation.dart';

class PortfolioService extends ChangeNotifier {
  static const String _storageKey = 'portfolio_transactions';

  // Singleton pattern
  static final PortfolioService _instance = PortfolioService._internal();
  factory PortfolioService() => _instance;
  PortfolioService._internal();

  List<Transaction> _transactions = [];
  List<Transaction> get transactions => _transactions;

  Future<void> loadTransactions() async {
    _transactions = await DatabaseHelper().getTransactions();
    notifyListeners();
  }

  Future<void> addTransaction(Transaction t) async {
    await DatabaseHelper().insertTransaction(t);
    // Reload local list
    _transactions.add(t);
    notifyListeners();
  }

  Future<void> removeTransaction(String id) async {
    await DatabaseHelper().deleteTransaction(id);
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // No longer needed to save all transactions manually
  Future<void> _saveTransactions() async {}

  // Get transactions for a specific symbol
  List<Transaction> getTransactionsFor(String symbol) {
    return _transactions.where((t) => t.symbol == symbol).toList();
  }

  // Calculate holdings stats
  Map<String, dynamic> getHoldings(String symbol) {
    final txs = getTransactionsFor(symbol);

    int totalShares = 0;
    double totalCost = 0;

    for (var t in txs) {
      if (t.type == TransactionType.buy) {
        totalShares += t.shares;
        totalCost += t.shares * t.price;
      } else {
        // Sell logic (FIFO or simple average reduction?)
        // Simple Average Cost reduction for display
        // If we sell, we reduce shares. We keep "Average Cost per Share" same, but total cost reduces proportionally.
        if (totalShares > 0) {
          double avgCostPerShare = totalCost / totalShares;
          totalShares -= t.shares;
          totalCost -= t.shares * avgCostPerShare;
        } else {
          // Short selling? For now, ignore or just negative
          totalShares -= t.shares;
        }
      }
    }

    // Floating point errors fix
    if (totalShares < 0) totalShares = 0;
    if (totalCost < 0) totalCost = 0;

    final avgCost = totalShares > 0 ? (totalCost / totalShares) : 0.0;

    return {
      'totalShares': totalShares,
      'avgCost': avgCost,
      'totalCost': totalCost,
    };
  }
}
