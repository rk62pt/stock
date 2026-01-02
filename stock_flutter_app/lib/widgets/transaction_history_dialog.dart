import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../services/portfolio_service.dart';

class TransactionHistoryDialog extends StatefulWidget {
  final String symbol;

  const TransactionHistoryDialog({Key? key, required this.symbol})
      : super(key: key);

  @override
  _TransactionHistoryDialogState createState() =>
      _TransactionHistoryDialogState();
}

class _TransactionHistoryDialogState extends State<TransactionHistoryDialog> {
  late PortfolioMetrics _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _metrics = PortfolioService().getPortfolioMetricsSync(widget.symbol);
      _isLoading = false;
    });
  }

  void _showAddEditDialog([Transaction? transaction]) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditTransactionDialog(
        symbol: widget.symbol,
        currentHoldings: _metrics.totalShares,
        transaction: transaction,
        onSave: () {
          _refresh();
          // Also need to notify parent to refresh?
          // PortfolioService listeners should trigger, but this Dialog is stateful.
          // The parent StockCard listens to Build changes but might not auto-rebuild if it doesn't listen to service directly?
          // Actually PortfolioService is a ChangeNotifier, but we accessed it directly.
          // The parent `StockCard` calls `setState` when it opens dialog.
        },
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
          content: SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator())));
    }

    // Sort history by date descending for display
    final displayList = List<TransactionWithPL>.from(_metrics.history);
    displayList
        .sort((a, b) => b.transaction.date.compareTo(a.transaction.date));

    return AlertDialog(
      title: Text('${widget.symbol} 交易紀錄'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('目前持股', '${_metrics.totalShares}'),
                  _buildSummaryItem('均價', _metrics.avgCost.toStringAsFixed(2)),
                  _buildSummaryItem(
                      '已實現', _metrics.totalRealizedProfit.toStringAsFixed(0),
                      color: _metrics.totalRealizedProfit >= 0
                          ? Colors.red
                          : Colors.green),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final item = displayList[index];
                  final t = item.transaction;
                  final isBuy = t.type == TransactionType.buy;
                  final dateStr = DateFormat('yyyy/MM/dd').format(t.date);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isBuy ? Colors.red.shade100 : Colors.green.shade100,
                      child: Text(isBuy ? '買' : '賣',
                          style: TextStyle(
                              color: isBuy ? Colors.red : Colors.green)),
                    ),
                    title: Text('${t.shares} 股 @ ${t.price}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateStr),
                        if (!isBuy && item.realizedPL != null)
                          Text(
                            '損益: ${item.realizedPL!.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: item.realizedPL! >= 0
                                  ? Colors.red
                                  : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showAddEditDialog(t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 20, color: Colors.grey),
                          onPressed: () {
                            _confirmDelete(t);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
        ElevatedButton.icon(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add),
          label: const Text('新增交易'),
        ),
      ],
    );
  }

  void _confirmDelete(Transaction t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除交易'),
        content: const Text('確定要刪除這筆交易嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await PortfolioService().removeTransaction(t.id);
              _refresh();
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class AddEditTransactionDialog extends StatefulWidget {
  final String symbol;
  final int currentHoldings;
  final Transaction? transaction; // If null, adding. If set, editing.
  final VoidCallback onSave;

  const AddEditTransactionDialog({
    Key? key,
    required this.symbol,
    required this.currentHoldings,
    this.transaction,
    required this.onSave,
  }) : super(key: key);

  @override
  _AddEditTransactionDialogState createState() =>
      _AddEditTransactionDialogState();
}

class _AddEditTransactionDialogState extends State<AddEditTransactionDialog> {
  late TransactionType _type;
  late TextEditingController _dateController;
  late TextEditingController _sharesController;
  late TextEditingController _priceController;
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      _type = t.type;
      _selectedDate = t.date;
      _sharesController = TextEditingController(text: t.shares.toString());
      _priceController = TextEditingController(text: t.price.toString());
    } else {
      _type = TransactionType.buy;
      _sharesController = TextEditingController();
      _priceController = TextEditingController();
    }
    _dateController = TextEditingController(
        text: DateFormat('yyyy/MM/dd').format(_selectedDate));
  }

  void _save() async {
    setState(() {
      _errorMessage = null;
    });

    final shares = int.tryParse(_sharesController.text);
    final price = double.tryParse(_priceController.text);

    if (shares == null || price == null) {
      setState(() {
        _errorMessage = '請輸入有效數值';
      });
      return;
    }

    // Validation: Cannot sell more than held
    if (_type == TransactionType.sell) {
      int available = widget.currentHoldings;
      if (widget.transaction != null &&
          widget.transaction!.type == TransactionType.sell) {
        available += widget.transaction!.shares;
      }
      if (widget.transaction != null &&
          widget.transaction!.type == TransactionType.buy) {
        available -= widget.transaction!.shares;
      }

      if (shares > available) {
        setState(() {
          _errorMessage = '庫存不足無法賣出 (剩餘: $available 股)';
        });
        return;
      }
    }

    final newT = Transaction(
      id: widget.transaction?.id ?? const Uuid().v4(),
      symbol: widget.symbol,
      date: _selectedDate,
      type: _type,
      shares: shares,
      price: price,
    );

    if (widget.transaction != null) {
      await PortfolioService().updateTransaction(newT);
    } else {
      await PortfolioService().addTransaction(newT);
    }

    widget.onSave();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;
    return AlertDialog(
      title: Text(isEditing ? '編輯交易' : '新增交易'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type Segment
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.buy,
                  label: Text('買進'),
                ),
                ButtonSegment(
                  value: TransactionType.sell,
                  label: Text('賣出'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<TransactionType> newSelection) {
                setState(() {
                  _type = newSelection.first;
                  _errorMessage = null;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: '日期',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _dateController.text =
                        DateFormat('yyyy/MM/dd').format(picked);
                  });
                }
              },
            ),
            TextField(
              controller: _sharesController,
              decoration: const InputDecoration(labelText: '股數'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: '價格'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
