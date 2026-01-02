import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/portfolio_service.dart';
import 'transaction_dialog.dart';

class TransactionHistoryDialog extends StatefulWidget {
  final String symbol;

  const TransactionHistoryDialog({
    required this.symbol,
    Key? key,
  }) : super(key: key);

  @override
  _TransactionHistoryDialogState createState() =>
      _TransactionHistoryDialogState();
}

class _TransactionHistoryDialogState extends State<TransactionHistoryDialog> {
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    setState(() {
      _transactions = PortfolioService().getTransactionsFor(widget.symbol);
      // Sort by date descending
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    });
  }

  void _deleteTransaction(String id) async {
    await PortfolioService().removeTransaction(id);
    _loadTransactions();
  }

  void _showAddTransactionDialog() async {
    final result = await showDialog(
      context: context,
      builder: (ctx) => TransactionDialog(symbol: widget.symbol),
    );

    if (result != null) {
      await PortfolioService().addTransaction(result);
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${widget.symbol} 交易明細'),
          // Add button in title/header area
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue),
            onPressed: _showAddTransactionDialog,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300, // Fixed height for list
        child: _transactions.isEmpty
            ? const Center(child: Text('尚無交易紀錄'))
            : ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final t = _transactions[index];
                  final isBuy = t.type == TransactionType.buy;
                  final color = isBuy ? Colors.red : Colors.green;
                  final typeText = isBuy ? '買入' : '賣出';
                  final dateStr = DateFormat('yyyy/MM/dd').format(t.date);

                  return Dismissible(
                    key: Key(t.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      _deleteTransaction(t.id);
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        child: Text(typeText,
                            style: TextStyle(color: color, fontSize: 12)),
                      ),
                      title: Text('$dateStr  ${t.shares}股'),
                      subtitle: Text('@ ${t.price.toStringAsFixed(2)}'),
                      trailing: Text(
                        '${(t.shares * t.price).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // Close dialog
          child: const Text('關閉'),
        ),
      ],
    );
  }
}
