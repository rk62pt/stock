import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/stock.dart';
import '../services/portfolio_service.dart';
import 'transaction_history_dialog.dart';

class StockCard extends StatefulWidget {
  final StockData stock;
  final Function(String) onRemove;

  const StockCard({
    Key? key,
    required this.stock,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<StockCard> createState() => _StockCardState();
}

class _StockCardState extends State<StockCard> {
  Map<String, dynamic> _holdings = {};

  @override
  void initState() {
    super.initState();
    _loadHoldings();
  }

  // Reload holdings when card updates or init
  void _loadHoldings() {
    final holdings = PortfolioService().getHoldings(widget.stock.symbol);
    setState(() {
      _holdings = holdings;
    });
  }

  void _showTransactionDialog() async {
    // Open History Dialog instead of direct Add Dialog
    await showDialog(
      context: context,
      builder: (ctx) => TransactionHistoryDialog(symbol: widget.stock.symbol),
    );

    // Refresh card stats after closing history (in case transactions were added/deleted)
    _loadHoldings();
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final isPositive = stock.regularMarketChange > 0;
    final isNegative = stock.regularMarketChange < 0;

    // Taiwan formatting: Red for Up, Green for Down
    final changeColor =
        isPositive ? Colors.red : (isNegative ? Colors.green : Colors.grey);

    final sign = isPositive ? '+' : '';
    final percentFormat = NumberFormat('0.00');

    // Portfolio calculations
    final int shares = _holdings['totalShares'] ?? 0;
    final double avgCost = _holdings['avgCost'] ?? 0.0;

    double profitLoss = 0;
    double profitLossPercent = 0;

    if (shares > 0) {
      final marketValue = shares * stock.regularMarketPrice;
      final totalCost = shares * avgCost;
      profitLoss = marketValue - totalCost;
      if (totalCost > 0) {
        profitLossPercent = (profitLoss / totalCost) * 100;
      }
    }

    final hasHoldings = shares > 0;
    final plColor = profitLoss > 0
        ? Colors.red
        : (profitLoss < 0 ? Colors.green : Colors.grey);
    final plSign = profitLoss > 0 ? '+' : '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.symbol,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stock.shortName ?? stock.longName ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.note_add_outlined,
                          color: Colors.blue),
                      onPressed: _showTransactionDialog,
                      tooltip: '新增交易',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => widget.onRemove(stock.symbol),
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Price Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stock.regularMarketPrice.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: changeColor,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$sign${stock.regularMarketChange.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: changeColor,
                      ),
                    ),
                    Text(
                      '$sign${percentFormat.format(stock.regularMarketChangePercent)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: changeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Portfolio Section (if has holdings)
            if (hasHoldings) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('持有: $shares 股',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('均價: ${avgCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$plSign${profitLoss.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: plColor)),
                      Text(
                        '$plSign${percentFormat.format(profitLossPercent)}%',
                        style: TextStyle(fontSize: 12, color: plColor),
                      ),
                    ],
                  )
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
