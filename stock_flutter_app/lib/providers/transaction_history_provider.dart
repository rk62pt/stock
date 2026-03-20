import 'package:flutter/material.dart';
import '../services/portfolio_service.dart';
import '../models/transaction.dart';
import 'profit_loss_provider.dart'; // Reuse ReportPeriod enum

class TransactionHistoryProvider extends ChangeNotifier {
  ReportPeriod _selectedPeriod = ReportPeriod.day; // Default to Day
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  bool _isLoading = false;
  List<Transaction> _transactions = [];

  // Getters
  ReportPeriod get selectedPeriod => _selectedPeriod;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  bool get isLoading => _isLoading;
  List<Transaction> get transactions => _transactions;

  // New Getters for Totals
  double get totalIncome {
    return _transactions.fold(0.0, (sum, t) {
      if (t.type == TransactionType.sell) {
        return sum + (t.shares * t.price);
      } else if (t.type == TransactionType.cashDividend) {
        return sum + t.price; // For cash dividend, price stores the amount
      }
      return sum;
    });
  }

  double get totalExpense {
    return _transactions.fold(0.0, (sum, t) {
      if (t.type == TransactionType.buy) {
        return sum + (t.shares * t.price);
      }
      return sum;
    });
  }

  TransactionHistoryProvider() {
    _initDateRange();
  }

  void _initDateRange() {
    final now = DateTime.now();
    _updateDateRange(now);
  }

  void setPeriod(ReportPeriod period) {
    if (_selectedPeriod == period) return;
    _selectedPeriod = period;

    if (_selectedPeriod == ReportPeriod.custom) {
      _fetchData();
    } else {
      _updateDateRange(DateTime.now());
    }
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    if (_selectedPeriod != ReportPeriod.custom) {
      _selectedPeriod = ReportPeriod.custom;
    }
    // Align to start/end of day
    _startDate = DateTime(start.year, start.month, start.day);
    _endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    _fetchData();
  }

  void nextPeriod() {
    if (_selectedPeriod == ReportPeriod.custom) return;

    DateTime newAnchor;
    switch (_selectedPeriod) {
      case ReportPeriod.day:
        newAnchor = _startDate.add(const Duration(days: 1));
        break;
      case ReportPeriod.week:
        newAnchor = _startDate.add(const Duration(days: 7));
        break;
      case ReportPeriod.month:
        newAnchor = DateTime(_startDate.year, _startDate.month + 1, 1);
        break;
      case ReportPeriod.quarter:
        newAnchor = DateTime(_startDate.year, _startDate.month + 3, 1);
        break;
      case ReportPeriod.year:
        newAnchor = DateTime(_startDate.year + 1, 1, 1);
        break;
      default:
        newAnchor = DateTime.now();
    }
    _updateDateRange(newAnchor);
  }

  void previousPeriod() {
    if (_selectedPeriod == ReportPeriod.custom) return;

    DateTime newAnchor;
    switch (_selectedPeriod) {
      case ReportPeriod.day:
        newAnchor = _startDate.subtract(const Duration(days: 1));
        break;
      case ReportPeriod.week:
        newAnchor = _startDate.subtract(const Duration(days: 7));
        break;
      case ReportPeriod.month:
        newAnchor = DateTime(_startDate.year, _startDate.month - 1, 1);
        break;
      case ReportPeriod.quarter:
        newAnchor = DateTime(_startDate.year, _startDate.month - 3, 1);
        break;
      case ReportPeriod.year:
        newAnchor = DateTime(_startDate.year - 1, 1, 1);
        break;
      default:
        newAnchor = DateTime.now();
    }
    _updateDateRange(newAnchor);
  }

  void _updateDateRange(DateTime anchor) {
    if (_selectedPeriod == ReportPeriod.custom) return;

    switch (_selectedPeriod) {
      case ReportPeriod.day:
        _startDate = DateTime(anchor.year, anchor.month, anchor.day);
        _endDate = DateTime(anchor.year, anchor.month, anchor.day, 23, 59, 59);
        break;

      case ReportPeriod.week:
        final daysToSubtract = anchor.weekday - 1;
        _startDate = DateTime(anchor.year, anchor.month, anchor.day)
            .subtract(Duration(days: daysToSubtract));
        _endDate = _startDate
            .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;

      case ReportPeriod.month:
        _startDate = DateTime(anchor.year, anchor.month, 1);
        final nextMonth = DateTime(anchor.year, anchor.month + 1, 1);
        _endDate = nextMonth.subtract(const Duration(seconds: 1));
        break;

      case ReportPeriod.quarter:
        int newMonth = anchor.month;
        int quarterStartMonth = ((newMonth - 1) ~/ 3) * 3 + 1;
        _startDate = DateTime(anchor.year, quarterStartMonth, 1);
        final nextQuarter = DateTime(anchor.year, quarterStartMonth + 3, 1);
        _endDate = nextQuarter.subtract(const Duration(seconds: 1));
        break;

      case ReportPeriod.year:
        _startDate = DateTime(anchor.year, 1, 1);
        _endDate = DateTime(anchor.year, 12, 31, 23, 59, 59);
        break;

      default:
        break;
    }

    _fetchData();
  }

  Future<void> _fetchData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get all transactions
      final allTransactions = PortfolioService().transactions;

      // Filter by date
      _transactions = allTransactions.where((t) {
        return t.date
                .isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
            t.date.isBefore(_endDate.add(const Duration(seconds: 1)));
      }).toList();

      // Sort by date (descending)
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      print("Error fetching Transaction History: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _fetchData();
  }
}
