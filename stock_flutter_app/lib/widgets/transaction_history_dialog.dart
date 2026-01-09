import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/transaction.dart';
import '../services/portfolio_service.dart';

class TransactionHistoryDialog extends StatefulWidget {
  final String symbol;
  final String? stockName;

  const TransactionHistoryDialog({
    Key? key,
    required this.symbol,
    this.stockName,
  }) : super(key: key);

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
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 10.0, vertical: 24.0),
      title: Text('${widget.symbol} ${widget.stockName ?? ''} 交易紀錄'),
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

                  Color iconBgColor;
                  Color iconColor;
                  String iconText;

                  switch (t.type) {
                    case TransactionType.buy:
                      iconBgColor = Colors.red.shade100;
                      iconColor = Colors.red;
                      iconText = '買';
                      break;
                    case TransactionType.sell:
                      iconBgColor = Colors.green.shade100;
                      iconColor = Colors.green;
                      iconText = '賣';
                      break;
                    case TransactionType.stockDividend:
                      iconBgColor = Colors.blue.shade100;
                      iconColor = Colors.blue;
                      iconText = '股';
                      break;
                    case TransactionType.cashDividend:
                      iconBgColor = Colors.orange.shade100;
                      iconColor = Colors.orange;
                      iconText = '息';
                      break;
                  }

                  String titleText;
                  if (t.type == TransactionType.cashDividend) {
                    titleText = '配息: ${t.price.toStringAsFixed(0)}';
                  } else if (t.type == TransactionType.stockDividend) {
                    titleText = '配股: ${t.shares} 股';
                  } else {
                    titleText = '${t.shares} 股 @ ${t.price}';
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black12)),
                    ),
                    child: Row(
                      children: [
                        // Date
                        Text(DateFormat('yy/MM/dd').format(t.date),
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                        const SizedBox(width: 8),
                        // Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: iconBgColor,
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(iconText,
                              style: TextStyle(
                                  color: iconColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        // Info & PL Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleText,
                                style: const TextStyle(fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((t.type == TransactionType.sell ||
                                      t.type == TransactionType.cashDividend) &&
                                  item.realizedPL != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    '損益: ${item.realizedPL! > 0 ? '+' : ''}${item.realizedPL!.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: item.realizedPL! >= 0
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Actions
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.more_vert,
                              size: 20, color: Colors.grey),
                          onSelected: (val) {
                            if (val == 'edit') _showAddEditDialog(t);
                            if (val == 'delete') _confirmDelete(t);
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('編輯')),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('刪除',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        )
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

    int? shares;
    double? price;

    if (_type == TransactionType.stockDividend) {
      shares = int.tryParse(_sharesController.text);
      price = 0.0;
    } else if (_type == TransactionType.cashDividend) {
      shares = 0;
      price = double.tryParse(_priceController.text);
    } else {
      shares = int.tryParse(_sharesController.text);
      price = double.tryParse(_priceController.text);
    }

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
            // Transaction Type Dropdown
            DropdownButtonFormField<TransactionType>(
              value: _type,
              decoration: const InputDecoration(labelText: '交易類型'),
              items: const [
                DropdownMenuItem(
                  value: TransactionType.buy,
                  child: Text('買進'),
                ),
                DropdownMenuItem(
                  value: TransactionType.sell,
                  child: Text('賣出'),
                ),
                DropdownMenuItem(
                  value: TransactionType.stockDividend,
                  child: Text('配股'),
                ),
                DropdownMenuItem(
                  value: TransactionType.cashDividend,
                  child: Text('配息'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _type = val;
                    _errorMessage = null;
                  });
                }
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
            if (_type != TransactionType.cashDividend)
              TextField(
                controller: _sharesController,
                decoration: const InputDecoration(labelText: '股數'),
                keyboardType: TextInputType.number,
              ),
            if (_type != TransactionType.stockDividend)
              TextField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText:
                      _type == TransactionType.cashDividend ? '總金額' : '價格',
                ),
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
