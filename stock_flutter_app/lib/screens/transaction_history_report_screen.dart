import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_history_provider.dart';
import '../providers/profit_loss_provider.dart'; // For ReportPeriod enum
import '../providers/stock_provider.dart';
import '../models/stock.dart';
import '../models/transaction.dart';

class TransactionHistoryReportScreen extends StatefulWidget {
  const TransactionHistoryReportScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryReportScreen> createState() =>
      _TransactionHistoryReportScreenState();
}

class _TransactionHistoryReportScreenState
    extends State<TransactionHistoryReportScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<TransactionHistoryProvider>(context, listen: false)
            .refresh());
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionHistoryProvider>(context);
    final dateFormat = DateFormat('yyyy/MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易紀錄報表'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Controls Area (Same style as P/L Report)
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
                            value: ReportPeriod.day, child: Text("日")),
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
                      const SizedBox(width: 48),
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

          // 2. Totals Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTotalItem(
                    context, "總收入", provider.totalIncome, Colors.red),
                Container(
                    height: 20,
                    width: 1,
                    color: Theme.of(context).dividerColor),
                _buildTotalItem(
                    context, "總支出", provider.totalExpense, Colors.green),
              ],
            ),
          ),
          const Divider(height: 1),

          // 3. Transaction List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.transactions.isEmpty
                    ? Center(
                        child: Text("此區間無交易紀錄",
                            style: TextStyle(color: Colors.grey[500])))
                    : ListView.separated(
                        itemCount: provider.transactions.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final t = provider.transactions[i];

                          // Resolve Stock Name
                          final stockProvider = Provider.of<StockProvider>(
                              context,
                              listen: false);
                          String? stockName;
                          try {
                            final stock = stockProvider.stocks.firstWhere(
                                (s) => s.symbol == t.symbol,
                                orElse: () => StockData(
                                    symbol: t.symbol,
                                    regularMarketPrice: 0,
                                    regularMarketChange: 0,
                                    regularMarketChangePercent: 0));
                            stockName = stock.shortName ?? stock.longName;
                          } catch (_) {}

                          // UI Helper Variables
                          Color iconBgColor;
                          Color iconColor;
                          String iconText;
                          String trailingText;
                          Color trailingColor =
                              Theme.of(context).colorScheme.onSurface;

                          switch (t.type) {
                            case TransactionType.buy:
                              iconBgColor = Colors.red.shade100;
                              iconColor = Colors.red;
                              iconText = '買';
                              trailingText =
                                  "${t.shares}股 @ ${t.price}\n\$${NumberFormat("#,##0").format(t.shares * t.price)}";
                              break;
                            case TransactionType.sell:
                              iconBgColor = Colors.green.shade100;
                              iconColor = Colors.green;
                              iconText = '賣';
                              trailingText =
                                  "${t.shares}股 @ ${t.price}\n\$${NumberFormat("#,##0").format(t.shares * t.price)}";
                              trailingColor = Colors.green;
                              break;
                            case TransactionType.stockDividend:
                              iconBgColor = Colors.blue.shade100;
                              iconColor = Colors.blue;
                              iconText = '股';
                              trailingText = "${t.shares}股";
                              break;
                            case TransactionType.cashDividend:
                              iconBgColor = Colors.orange.shade100;
                              iconColor = Colors.orange;
                              iconText = '息';
                              trailingText =
                                  "\$${NumberFormat("#,##0").format(t.price)}";
                              trailingColor = Colors.orange;
                              break;
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: iconBgColor,
                              child: Text(iconText,
                                  style: TextStyle(
                                      color: iconColor,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text(
                              "${t.symbol} ${stockName ?? ''}",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                DateFormat('yyyy/MM/dd HH:mm').format(t.date)),
                            trailing: Text(
                              trailingText,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: trailingColor),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalItem(
      BuildContext context, String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          "\$${NumberFormat("#,##0").format(value)}",
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
