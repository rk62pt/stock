import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/profit_loss_provider.dart';
import '../widgets/transaction_history_dialog.dart';

import '../providers/stock_provider.dart';
import '../models/stock.dart'; // For StockData fallback or type

class ProfitLossReportScreen extends StatefulWidget {
  const ProfitLossReportScreen({Key? key}) : super(key: key);

  @override
  State<ProfitLossReportScreen> createState() => _ProfitLossReportScreenState();
}

class _ProfitLossReportScreenState extends State<ProfitLossReportScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh data on entry
    Future.microtask(() =>
        Provider.of<ProfitLossProvider>(context, listen: false).refresh());
  }

  void _showHistory(BuildContext context, String symbol, String? stockName) {
    showDialog(
      context: context,
      builder: (ctx) => TransactionHistoryDialog(
        symbol: symbol,
        stockName: stockName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ProfitLossProvider>(context);
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('已實現損益報表'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Controls Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Column(
              children: [
                // Period Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("統計區間: ", style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    DropdownButton<ReportPeriod>(
                      value: provider.selectedPeriod,
                      onChanged: (val) {
                        if (val != null) provider.setPeriod(val);
                      },
                      items: const [
                        DropdownMenuItem(
                            value: ReportPeriod.week, child: Text("週")),
                        DropdownMenuItem(
                            value: ReportPeriod.month, child: Text("月")),
                        DropdownMenuItem(
                            value: ReportPeriod.quarter, child: Text("季")),
                        DropdownMenuItem(
                            value: ReportPeriod.year, child: Text("年")),
                        DropdownMenuItem(
                            value: ReportPeriod.custom, child: Text("自訂")),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Date Navigator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (provider.selectedPeriod != ReportPeriod.custom)
                      IconButton(
                        icon: const Icon(Icons.arrow_left, size: 32),
                        onPressed: provider.previousPeriod,
                      )
                    else
                      const SizedBox(width: 48), // Placeholder to keep center
                    Expanded(
                      child: InkWell(
                        onTap: provider.selectedPeriod == ReportPeriod.custom
                            ? () async {
                                final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  initialDateRange: DateTimeRange(
                                    start: provider.startDate,
                                    end: provider.endDate,
                                  ),
                                );
                                if (picked != null) {
                                  provider.setCustomDateRange(
                                      picked.start, picked.end);
                                }
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${dateFormat.format(provider.startDate)} - ${dateFormat.format(provider.endDate)}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: provider.selectedPeriod ==
                                          ReportPeriod.custom
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  decoration: provider.selectedPeriod ==
                                          ReportPeriod.custom
                                      ? TextDecoration.underline
                                      : null,
                                ),
                              ),
                              if (provider.selectedPeriod ==
                                  ReportPeriod.custom)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.edit_calendar,
                                      size: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                )
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (provider.selectedPeriod != ReportPeriod.custom)
                      IconButton(
                        icon: const Icon(Icons.arrow_right, size: 32),
                        onPressed: provider.nextPeriod,
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ],
            ),
          ),

          // 2. Report List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.reportItems.isEmpty
                    ? Center(
                        child: Text("此區間無已實現損益紀錄",
                            style: TextStyle(color: Colors.grey[500])))
                    : ListView.separated(
                        itemCount: provider.reportItems.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = provider.reportItems[i];

                          // Look up stock name
                          final stockProvider = Provider.of<StockProvider>(
                              context,
                              listen: false);
                          String? stockName;
                          try {
                            final stock = stockProvider.stocks.firstWhere(
                                (s) => s.symbol == item.symbol,
                                orElse: () => StockData(
                                    symbol: item.symbol,
                                    regularMarketPrice: 0,
                                    regularMarketChange: 0,
                                    regularMarketChangePercent:
                                        0) // Dummy fallback
                                );
                            stockName = stock.shortName ?? stock.longName;
                          } catch (_) {}

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(item.symbol.substring(
                                  0,
                                  item.symbol.length > 2
                                      ? 2
                                      : item.symbol.length)),
                            ),
                            title: Text(item.symbol,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle:
                                stockName != null ? Text(stockName) : null,
                            trailing: Text(
                              "${item.realizedPL > 0 ? '+' : ''}${item.realizedPL.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: item.realizedPL >= 0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                            onTap: () =>
                                _showHistory(context, item.symbol, stockName),
                          );
                        },
                      ),
          ),

          // 3. Footer Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("區間總損益", style: TextStyle(fontSize: 16)),
                Text(
                  "${provider.totalRealizedPL > 0 ? '+' : ''}${provider.totalRealizedPL.toStringAsFixed(0)}",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: provider.totalRealizedPL >= 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
