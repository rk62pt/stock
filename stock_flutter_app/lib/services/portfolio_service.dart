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

  // Calculate detailed portfolio status with FIFO
  Future<PortfolioMetrics> getPortfolioMetrics(String symbol) async {
    // Ensure we have latest
    // _transactions might be stale if we don't reload ?
    // Usually loadTransactions is called at startup.
    // Let's filter from memory for speed, assuming _transactions is kept in sync.

    var symbolTransactions =
        _transactions.where((t) => t.symbol == symbol).toList();
    symbolTransactions.sort((a, b) => a.date.compareTo(b.date)); // Oldest first

    // FIFO Logic
    List<Transaction> buyQueue = []; // Buying lots
    double totalRealizedProfit = 0;
    List<TransactionWithPL> history = [];

    for (var t in symbolTransactions) {
      if (t.type == TransactionType.buy) {
        buyQueue.add(t); // Add to queue
        history.add(TransactionWithPL(t, null));
      } else {
        // Sell
        int sharesToSell = t.shares;
        double costBasisForThisSell = 0;

        // Consume from buyQueue
        while (sharesToSell > 0 && buyQueue.isNotEmpty) {
          var oldestBuy = buyQueue.first;

          if (oldestBuy.shares > sharesToSell) {
            // Partial consumption of the buy lot
            costBasisForThisSell += sharesToSell * oldestBuy.price;

            // Update the queue head with remaining shares (in memory only)
            buyQueue[0] =
                oldestBuy.copyWith(shares: oldestBuy.shares - sharesToSell);
            sharesToSell = 0;
          } else {
            // Full consumption of this buy lot
            costBasisForThisSell += oldestBuy.shares * oldestBuy.price;
            sharesToSell -= oldestBuy.shares;
            buyQueue.removeAt(0);
          }
        }

        // Realized P/L calculation
        // actuallySold is what we found matching buys for.
        // If sharesToSell > 0 remaining, it means we oversold (short). Cost basis 0 for that part?
        int actuallySold = t.shares - sharesToSell;
        double realized = 0;
        if (actuallySold > 0) {
          realized = (actuallySold * t.price) - costBasisForThisSell;
        }

        totalRealizedProfit += realized;
        history.add(TransactionWithPL(t, realized));
      }
    }

    // Remaining holdings
    int totalShares = 0;
    double totalCostVector = 0;
    for (var b in buyQueue) {
      totalShares += b.shares;
      totalCostVector += b.shares * b.price;
    }
    double avgCost = totalShares > 0 ? totalCostVector / totalShares : 0;

    return PortfolioMetrics(
      totalShares: totalShares,
      avgCost: avgCost,
      totalRealizedProfit: totalRealizedProfit,
      history: history,
    );
  }

  // Backward compatibility wrapper (but now async! UI needs update)
  // Actually the original was synchronous but that was wrong for DB access anyway,
  // though existing code filtered from memory.
  // We can keep it synchronous IF we use the memory cache, but `getPortfolioMetrics` logic is complex enough
  // that we might want to just call it. But to avoid breaking call sites immediately,
  // let's try to keep it synchronous if possible OR return a Future.
  // The existing call site `StockCard` calls `PortfolioService().getHoldings(widget.stock.symbol)`.
  // It assigns it to a Map.
  // I will change StockCard to handle Future or just make this sync using _transactions.
  // Since _transactions is in memory, we can make `getPortfolioMetrics` synchronous!

  PortfolioMetrics getPortfolioMetricsSync(String symbol) {
    var symbolTransactions =
        _transactions.where((t) => t.symbol == symbol).toList();
    symbolTransactions.sort((a, b) => a.date.compareTo(b.date));

    List<Transaction> buyQueue = [];
    double totalRealizedProfit = 0;
    List<TransactionWithPL> history = [];

    for (var t in symbolTransactions) {
      if (t.type == TransactionType.buy) {
        buyQueue.add(t);
        history.add(TransactionWithPL(t, null));
      } else {
        int sharesToSell = t.shares;
        double costBasis = 0;
        while (sharesToSell > 0 && buyQueue.isNotEmpty) {
          var oldestBuy = buyQueue.first;
          if (oldestBuy.shares > sharesToSell) {
            costBasis += sharesToSell * oldestBuy.price;
            buyQueue[0] =
                oldestBuy.copyWith(shares: oldestBuy.shares - sharesToSell);
            sharesToSell = 0;
          } else {
            costBasis += oldestBuy.shares * oldestBuy.price;
            sharesToSell -= oldestBuy.shares;
            buyQueue.removeAt(0);
          }
        }
        int actuallySold = t.shares - sharesToSell;
        double realized = 0;
        if (actuallySold > 0) {
          realized = (actuallySold * t.price) - costBasis;
        }
        totalRealizedProfit += realized;
        history.add(TransactionWithPL(t, realized));
      }
    }

    int totalShares = 0;
    double totalCost = 0;
    for (var b in buyQueue) {
      totalShares += b.shares;
      totalCost += b.shares * b.price;
    }
    double avgCost = totalShares > 0 ? totalCost / totalShares : 0;

    return PortfolioMetrics(
      totalShares: totalShares,
      avgCost: avgCost,
      totalRealizedProfit: totalRealizedProfit,
      history: history,
    );
  }

  Map<String, dynamic> getHoldings(String symbol) {
    final metrics = getPortfolioMetricsSync(symbol);
    return {
      'totalShares': metrics.totalShares,
      'avgCost': metrics.avgCost,
      'totalRealizedProfit': metrics.totalRealizedProfit,
    };
  }

  Future<void> updateTransaction(Transaction t) async {
    await DatabaseHelper().updateTransaction(t);
    // Reload local list efficiently? Or just re-fetch all?
    // Replace in memory
    final index = _transactions.indexWhere((x) => x.id == t.id);
    if (index != -1) {
      _transactions[index] = t;
    } else {
      _transactions.add(t);
    }
    notifyListeners();
  }

  // Get metrics for ALL symbols (used for dashboard and separating lists)
  Future<Map<String, PortfolioMetrics>> getAllPortfolioMetrics() async {
    // 1. Get all unique symbols from transactions
    final allTx = _transactions;
    final symbols = allTx.map((t) => t.symbol).toSet();

    final Map<String, PortfolioMetrics> results = {};

    // 2. Compute metrics for each
    for (var symbol in symbols) {
      results[symbol] = await getPortfolioMetrics(symbol);
    }

    return results;
  }

  // Calculate total realized profit within a date range across all stocks
  Future<double> getRealizedProfit(DateTime start, DateTime end) async {
    final allMetrics = await getAllPortfolioMetrics();
    double total = 0;

    for (var metrics in allMetrics.values) {
      for (var item in metrics.history) {
        if (item.transaction.type == TransactionType.sell &&
            item.realizedPL != null) {
          final date = item.transaction.date;
          // Check range (Inclusive)
          if (date.isAfter(start.subtract(const Duration(seconds: 1))) &&
              date.isBefore(end.add(const Duration(seconds: 1)))) {
            total += item.realizedPL!;
          }
        }
      }
    }
    return total;
  }
}

class PortfolioMetrics {
  final int totalShares;
  final double avgCost;
  final double totalRealizedProfit;
  final List<TransactionWithPL> history;

  PortfolioMetrics({
    required this.totalShares,
    required this.avgCost,
    required this.totalRealizedProfit,
    required this.history,
  });
}

class TransactionWithPL {
  final Transaction transaction;
  final double? realizedPL; // Only for sells

  TransactionWithPL(this.transaction, this.realizedPL);
}
