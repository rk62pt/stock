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
  Future<PortfolioMetrics> getPortfolioMetrics(String symbol,
      {bool includeFees = true,
      bool includeDividends = true,
      double brokerDiscount = 1.0}) async {
    return _calculateMetrics(
        symbol, includeFees, includeDividends, brokerDiscount);
  }

  PortfolioMetrics getPortfolioMetricsSync(String symbol,
      {bool includeFees = true,
      bool includeDividends = true,
      double brokerDiscount = 1.0}) {
    return _calculateMetrics(
        symbol, includeFees, includeDividends, brokerDiscount);
  }

  PortfolioMetrics _calculateMetrics(String symbol, bool includeFees,
      bool includeDividends, double brokerDiscount) {
    var symbolTransactions =
        _transactions.where((t) => t.symbol == symbol).toList();
    symbolTransactions.sort((a, b) => a.date.compareTo(b.date)); // Oldest first

    // FIFO Logic
    List<Transaction> buyQueue = []; // Buying lots
    double totalRealizedProfit = 0;
    List<TransactionWithPL> history = [];

    for (var t in symbolTransactions) {
      // Calculate costs
      double totalAmount = (t.shares * t.price).toDouble();

      // Fee Rule: 0.1425% with broker discount, min 1 TWD
      double fee = 0;
      double tax = 0;

      if (includeFees &&
          (t.type == TransactionType.buy || t.type == TransactionType.sell)) {
        double rawFee = (totalAmount * 0.001425 * brokerDiscount);
        fee = rawFee < 1 ? 1 : rawFee.floorToDouble();
      }

      if (includeFees && t.type == TransactionType.sell) {
        // Tax Rule: 0.3%
        tax = (totalAmount * 0.003).floorToDouble();
      }

      // Effective Price per share adjustment
      // Buy: Cost increases by fee
      // Sell: Net proceeds decrease by fee and tax

      if (t.type == TransactionType.buy ||
          t.type == TransactionType.stockDividend) {
        double effectiveCost = totalAmount + fee;
        double effectivePrice = (t.shares > 0) ? effectiveCost / t.shares : 0;

        // Use a modified transaction for queue that holds effective price
        // Note: We don't modify the original 't' displayed in history,
        // effectively we just track cost basis.
        // We can just store 'effectivePrice' in the buyQueue item
        // by creating a copy with modified price?
        // Yes, this is safe as buyQueue items are only used for cost calculation.

        buyQueue.add(t.copyWith(price: effectivePrice));
        history.add(TransactionWithPL(t, null));
      } else if (t.type == TransactionType.sell) {
        // Sell
        int sharesToSell = t.shares;
        double costBasisForThisSell = 0;

        // Consume from buyQueue
        while (sharesToSell > 0 && buyQueue.isNotEmpty) {
          var oldestBuy = buyQueue.first;

          if (oldestBuy.shares > sharesToSell) {
            // Partial consumption
            costBasisForThisSell += sharesToSell *
                oldestBuy.price; // oldestBuy.price includes buy fees

            // Update the queue head
            buyQueue[0] =
                oldestBuy.copyWith(shares: oldestBuy.shares - sharesToSell);
            sharesToSell = 0;
          } else {
            // Full consumption
            costBasisForThisSell += oldestBuy.shares * oldestBuy.price;
            sharesToSell -= oldestBuy.shares;
            buyQueue.removeAt(0);
          }
        }

        // Realized P/L calculation
        int actuallySold = t.shares - sharesToSell;
        double realized = 0;
        if (actuallySold > 0) {
          // Proceeds = (Shares * Price) - Fees - Tax
          // Since we calculated 'fee' and 'tax' based on the TOTAL shares of this transaction,
          // if we only partially sold (actuallySold < t.shares), we must prorate the sell costs.
          // However, for standard FIFO logic in this app, we assume we sold all if possible?
          // Wait, 'sharesToSell > 0' means we ran out of inventory (oversold/short).
          // If we are shorting, the cost basis is 0? Or negative?
          // Current logic: ignore p/l for short portion (cost basis 0 for that part?)
          // Let's assume valid inventory.

          double portion = actuallySold / t.shares;
          double sellProceeds =
              (actuallySold * t.price) - (fee * portion) - (tax * portion);

          realized = sellProceeds - costBasisForThisSell;
        }

        totalRealizedProfit += realized;
        history.add(TransactionWithPL(t, realized));
      } else if (t.type == TransactionType.cashDividend) {
        // If including dividends, add to total PL
        if (includeDividends) {
          totalRealizedProfit += t.price;
        }
        // Still show in history with PL value equivalent to amount if included, or just amount?
        // UI expects 'realizedPL' to show "Profit". For div, it is purely profit.
        history.add(TransactionWithPL(
            t, includeDividends ? t.price : 0)); // 0 or price?
      }
    }

    // Remaining holdings
    int totalShares = 0;
    double totalCostVector = 0;
    for (var b in buyQueue) {
      totalShares += b.shares;
      totalCostVector += b.shares * b.price; // This price includes buy fees
    }
    double avgCost = totalShares > 0 ? totalCostVector / totalShares : 0;
    // AvgCost here includes buy fees. This is standard "Break Even Price" (roughly).

    return PortfolioMetrics(
      totalShares: totalShares,
      avgCost: avgCost,
      totalRealizedProfit: totalRealizedProfit,
      history: history,
    );
  }

  Map<String, dynamic> getHoldings(String symbol) {
    // Accessing provider to get settings? NO, service ignores provider.
    // The caller (StockCard) should pass settings or we use defaults?
    // Since StockCard calls this, and StockCard has access to Provider...
    // But StockCard currently calls this directly without params.
    // We'll update StockCard later. For now use defaults (fees=true, div=true, disc=1.0)
    // Wait, user wants global settings to apply.
    // If we don't pass them, they are defaults.
    // We must update StockCard to pass them.

    final metrics = getPortfolioMetricsSync(symbol);
    return {
      'totalShares': metrics.totalShares,
      'avgCost': metrics.avgCost,
      'totalRealizedProfit': metrics.totalRealizedProfit,
    };
  }

  // Overload for StockCard usage with specific settings
  Map<String, dynamic> getHoldingsWithSettings(String symbol,
      {bool includeFees = true,
      bool includeDividends = true,
      double brokerDiscount = 1.0}) {
    final metrics = getPortfolioMetricsSync(symbol,
        includeFees: includeFees,
        includeDividends: includeDividends,
        brokerDiscount: brokerDiscount);
    return {
      'totalShares': metrics.totalShares,
      'avgCost': metrics.avgCost,
      'totalRealizedProfit': metrics.totalRealizedProfit,
    };
  }

  Future<void> updateTransaction(Transaction t) async {
    await DatabaseHelper().updateTransaction(t);
    final index = _transactions.indexWhere((x) => x.id == t.id);
    if (index != -1) {
      _transactions[index] = t;
    } else {
      _transactions.add(t);
    }
    notifyListeners();
  }

  Future<Map<String, PortfolioMetrics>> getAllPortfolioMetrics(
      {bool includeFees = true,
      bool includeDividends = true,
      double brokerDiscount = 1.0}) async {
    final allTx = _transactions;
    final symbols = allTx.map((t) => t.symbol).toSet();
    final Map<String, PortfolioMetrics> results = {};
    for (var symbol in symbols) {
      results[symbol] = await getPortfolioMetrics(symbol,
          includeFees: includeFees,
          includeDividends: includeDividends,
          brokerDiscount: brokerDiscount);
    }
    return results;
  }

  String exportData() {
    final data = {
      'transactions': _transactions.map((t) => t.toJson()).toList(),
      'version': 1,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  Future<void> importData(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final List<dynamic> txList = data['transactions'] ?? [];
      final newTransactions =
          txList.map((x) => Transaction.fromJson(x)).toList();

      // Clear DB - this is inefficient but safe for small data.
      // Optimized way: DatabaseHelper().clearAllTransactions()
      // Clear DB - create a copy of the list to iterate or use clearAll
      final currentIds = _transactions.map((t) => t.id).toList();
      for (var id in currentIds) {
        await removeTransaction(id);
      }

      // Insert new
      for (var t in newTransactions) {
        await addTransaction(t);
      }

      await loadTransactions();
    } catch (e) {
      if (kDebugMode) {
        print('Import failed: $e');
      }
      rethrow;
    }
  }

// ...
  Future<double> getRealizedProfit(DateTime start, DateTime end,
      {bool includeFees = true,
      bool includeDividends = true,
      double brokerDiscount = 1.0}) async {
    final allMetrics = await getAllPortfolioMetrics(
        includeFees: includeFees,
        includeDividends: includeDividends,
        brokerDiscount: brokerDiscount);
    double total = 0;

    for (var metrics in allMetrics.values) {
      for (var item in metrics.history) {
        // Sell
        if (item.transaction.type == TransactionType.sell &&
            item.realizedPL != null) {
          final date = item.transaction.date;
          if (date.isAfter(start.subtract(const Duration(seconds: 1))) &&
              date.isBefore(end.add(const Duration(seconds: 1)))) {
            total += item.realizedPL!;
          }
        }
        // Dividend - Check if it should be included in P/L report range
        // If includeDividends is false, their realizedPL in history is 0 (as set in calculation),
        // but we should verify the range too.
        if (item.transaction.type == TransactionType.cashDividend) {
          final date = item.transaction.date;
          if (date.isAfter(start.subtract(const Duration(seconds: 1))) &&
              date.isBefore(end.add(const Duration(seconds: 1)))) {
            // If includeDividends was false, realizedPL is 0 or null?
            // In calculation above: history.add(TransactionWithPL(t, includeDividends ? t.price : 0));
            // So adding item.realizedPL is safe (0 if disabled).
            if (item.realizedPL != null) {
              total += item.realizedPL!;
            }
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
