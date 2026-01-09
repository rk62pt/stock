import 'package:flutter/material.dart';
import '../services/portfolio_service.dart';

enum ReportPeriod {
  week,
  month,
  quarter,
  year,
  custom,
}

class ProfitLossItem {
  final String symbol;
  final double realizedPL;
  ProfitLossItem({required this.symbol, required this.realizedPL});
}

class ProfitLossProvider extends ChangeNotifier {
  ReportPeriod _selectedPeriod = ReportPeriod.month;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  bool _isLoading = false;
  List<ProfitLossItem> _reportItems = [];
  double _totalRealizedPL = 0;

  // Getters
  ReportPeriod get selectedPeriod => _selectedPeriod;
  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  bool get isLoading => _isLoading;
  List<ProfitLossItem> get reportItems => _reportItems;
  double get totalRealizedPL => _totalRealizedPL;

  ProfitLossProvider() {
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
      // Refresh with current range state, ensuring listeners are notified
      _fetchReportData();
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
    _fetchReportData();
  }

  void nextPeriod() {
    if (_selectedPeriod == ReportPeriod.custom) return; // Disable for custom

    // Move start date forward by 1 unit of period
    DateTime newAnchor;
    switch (_selectedPeriod) {
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
    if (_selectedPeriod == ReportPeriod.custom) return; // Disable for custom

    DateTime newAnchor;
    switch (_selectedPeriod) {
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
      case ReportPeriod.week:
        // Week starts on Monday
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

    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final allMetrics = await PortfolioService().getAllPortfolioMetrics();

      _reportItems = [];
      _totalRealizedPL = 0;

      for (var entry in allMetrics.entries) {
        String symbol = entry.key;
        PortfolioMetrics metrics = entry.value;

        double stockTotalRealized = 0;
        bool hasActivity = false;

        for (var item in metrics.history) {
          if (item.realizedPL != null) {
            final date = item.transaction.date;
            if (date.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                date.isBefore(_endDate.add(const Duration(seconds: 1)))) {
              stockTotalRealized += item.realizedPL!;
              hasActivity = true;
            }
          }
        }

        if (hasActivity) {
          _reportItems.add(
              ProfitLossItem(symbol: symbol, realizedPL: stockTotalRealized));
          _totalRealizedPL += stockTotalRealized;
        }
      }

      _reportItems.sort((a, b) => b.realizedPL.compareTo(a.realizedPL));
    } catch (e) {
      print("Error fetching P/L Report: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _fetchReportData();
  }
}
