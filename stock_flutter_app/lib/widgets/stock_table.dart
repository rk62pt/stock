import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/stock.dart';
import '../providers/stock_provider.dart';
import 'transaction_history_dialog.dart';

class StockTable extends StatefulWidget {
  final List<StockData> stocks;
  final Function(String) onRemove;

  const StockTable({
    Key? key,
    required this.stocks,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<StockTable> createState() => _StockTableState();
}

class _StockTableState extends State<StockTable> {
  int _sortColumnIndex = 0; // Default: Symbol
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    if (widget.stocks.isEmpty) return const SizedBox();

    final provider = Provider.of<StockProvider>(context);

    // 1. Prepare Data
    final rowDataList = widget.stocks.map((stock) {
      final metrics = provider.getMetrics(stock.symbol);
      final shares = metrics?.totalShares ?? 0;
      final avgCost = metrics?.avgCost ?? 0.0;
      final marketPrice = stock.regularMarketPrice;

      double profitLoss = 0;
      double profitLossPercent = 0;

      if (shares > 0) {
        final marketValue = shares * marketPrice;
        final totalCost = shares * avgCost;
        profitLoss = marketValue - totalCost;
        if (totalCost > 0) {
          profitLossPercent = (profitLoss / totalCost) * 100;
        }
      }

      return _StockRowData(
        stock: stock,
        shares: shares,
        avgCost: avgCost,
        marketPrice: marketPrice,
        change: stock.regularMarketChange,
        changePercent: stock.regularMarketChangePercent,
        profitLoss: profitLoss,
        profitLossPercent: profitLossPercent,
      );
    }).toList();

    // 2. Sort Data
    rowDataList.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnIndex) {
        case 0: // Symbol
          cmp = a.stock.symbol.compareTo(b.stock.symbol);
          break;
        case 1: // Shares
          cmp = a.shares.compareTo(b.shares);
          break;
        case 2: // Price/Cost -> Sort by Price
          cmp = a.marketPrice.compareTo(b.marketPrice);
          break;
        case 3: // Change/Change% -> Sort by Change Amount
          cmp = a.change.compareTo(b.change);
          break;
        case 4: // P/L / P/L% -> Sort by P/L Amount
          cmp = a.profitLoss.compareTo(b.profitLoss);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    // 3. Build Table
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          columnSpacing: 16, // Reduced spacing for compact view
          horizontalMargin: 8,
          headingRowHeight: 48,
          dataRowMinHeight: 56, // Increased height for 2 lines
          dataRowMaxHeight: 56,
          columns: [
            _buildColumn('股號', 0),
            _buildColumn('持股', 1, numeric: true),
            _buildColumn('現價\n均價', 2, numeric: true), // Multiline header
            _buildColumn('漲跌\n幅度', 3, numeric: true),
            _buildColumn('損益\n報酬', 4, numeric: true),
            const DataColumn(label: Text('')), // Actions
          ],
          rows: rowDataList.map((data) => _buildRow(context, data)).toList(),
        ),
      ),
    );
  }

  DataColumn _buildColumn(String label, int index, {bool numeric = false}) {
    return DataColumn(
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        textAlign: numeric ? TextAlign.end : TextAlign.start,
      ),
      numeric: numeric,
      onSort: (idx, asc) {
        setState(() {
          _sortColumnIndex = idx;
          _sortAscending = asc;
        });
      },
    );
  }

  DataRow _buildRow(BuildContext context, _StockRowData data) {
    final isUp = data.change > 0;
    final isDown = data.change < 0;
    final changeColor =
        isUp ? Colors.red : (isDown ? Colors.green : Colors.grey);

    final isProfit = data.profitLoss > 0;
    final isLoss = data.profitLoss < 0;
    final plColor =
        isProfit ? Colors.red : (isLoss ? Colors.green : Colors.grey);

    final intFormat = NumberFormat("#,##0");

    return DataRow(
      cells: [
        // Symbol + Name
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.stock.symbol,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                data.stock.shortName ?? data.stock.longName ?? '',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          onTap: () => _showTransactionDialog(context, data.stock),
        ),
        // Shares
        DataCell(Text(intFormat.format(data.shares))),
        // Price / Avg Cost
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.marketPrice.toStringAsFixed(2),
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: changeColor),
              ),
              Text(
                data.avgCost.toStringAsFixed(2),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        // Change / Change%
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.change > 0 ? '+' : ''}${data.change.toStringAsFixed(2)}',
                style:
                    TextStyle(color: changeColor, fontWeight: FontWeight.bold),
              ),
              Text(
                '${data.changePercent > 0 ? '+' : ''}${data.changePercent.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 11, color: changeColor),
              ),
            ],
          ),
        ),
        // P/L / P/L%
        DataCell(
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.profitLoss > 0 ? '+' : ''}${intFormat.format(data.profitLoss)}',
                style: TextStyle(color: plColor, fontWeight: FontWeight.bold),
              ),
              Text(
                '${data.profitLossPercent > 0 ? '+' : ''}${data.profitLossPercent.toStringAsFixed(2)}%',
                style: TextStyle(fontSize: 11, color: plColor),
              ),
            ],
          ),
        ),

        // Actions
        DataCell(
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () => _showDeleteConfirmation(context, data.stock),
          ),
        ),
      ],
    );
  }

  Future<void> _showTransactionDialog(
      BuildContext context, StockData stock) async {
    await showDialog(
      context: context,
      builder: (ctx) => TransactionHistoryDialog(
        symbol: stock.symbol,
        stockName: stock.shortName ?? stock.longName,
      ),
    );
    if (mounted) {
      Provider.of<StockProvider>(context, listen: false).refreshMetrics();
    }
  }

  void _showDeleteConfirmation(BuildContext context, StockData stock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除 ${stock.symbol} 嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onRemove(stock.symbol);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
  }
}

class _StockRowData {
  final StockData stock;
  final int shares;
  final double avgCost;
  final double marketPrice;
  final double change;
  final double changePercent;
  final double profitLoss;
  final double profitLossPercent;

  _StockRowData({
    required this.stock,
    required this.shares,
    required this.avgCost,
    required this.marketPrice,
    required this.change,
    required this.changePercent,
    required this.profitLoss,
    required this.profitLossPercent,
  });
}
