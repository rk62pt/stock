import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import 'package:uuid/uuid.dart';

class TransactionDialog extends StatefulWidget {
  final String symbol;
  const TransactionDialog({required this.symbol, Key? key}) : super(key: key);

  @override
  _TransactionDialogState createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();

  TransactionType _type = TransactionType.buy;
  DateTime _date = DateTime.now();
  final TextEditingController _sharesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void dispose() {
    _sharesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      int shares = 0;
      double price = 0.0;

      if (_type == TransactionType.stockDividend) {
        shares = int.parse(_sharesController.text);
        price = 0.0; // Free shares
      } else if (_type == TransactionType.cashDividend) {
        shares = 0; // No shares added
        price = double.parse(_priceController.text); // Total amount
      } else {
        shares = int.parse(_sharesController.text);
        price = double.parse(_priceController.text);
      }

      final transaction = Transaction(
        id: const Uuid().v4(),
        symbol: widget.symbol,
        date: _date,
        type: _type,
        shares: shares,
        price: price,
      );

      Navigator.of(context).pop(transaction);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('新增交易 - ${widget.symbol}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Picker
              ListTile(
                title: const Text('交易日期'),
                subtitle: Text(DateFormat('yyyy/MM/dd').format(_date)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),

              const SizedBox(height: 10),

              // Transaction Type Dropdown
              DropdownButtonFormField<TransactionType>(
                value: _type,
                decoration: const InputDecoration(labelText: '交易類型'),
                items: const [
                  DropdownMenuItem(
                    value: TransactionType.buy,
                    child: Text('買進 (Buy)'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.sell,
                    child: Text('賣出 (Sell)'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.stockDividend,
                    child: Text('配股 (Stock Dividend)'),
                  ),
                  DropdownMenuItem(
                    value: TransactionType.cashDividend,
                    child: Text('配息 (Cash Dividend)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _type = val;
                      // clear inputs when type changes mostly for clarity
                      // _sharesController.clear();
                      // _priceController.clear();
                    });
                  }
                },
              ),

              const SizedBox(height: 10),

              // Shares / Amount Field
              // For Cash Dividend, we use this field as 'Amount' (Total Cash) conceptually,
              // but we store it in Price? Or Shares?
              // Let's stick to:
              // Stock Dividend: Shares field = shares. Price field = 0.
              // Cash Dividend: Shares field = 1 (hidden?). Price field = Amount.
              // But to keep it simple, let's keep both fields visible but change labels.

              if (_type != TransactionType.cashDividend)
                TextFormField(
                  controller: _sharesController,
                  decoration: const InputDecoration(labelText: '股數'),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.isEmpty) return '請輸入股數';
                    if (int.tryParse(val) == null) return '請輸入有效數字';
                    return null;
                  },
                ),

              // Price Field
              if (_type != TransactionType.stockDividend)
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: _type == TransactionType.cashDividend
                        ? '總金額 (元)'
                        : '價格 (元)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.isEmpty) return '請輸入金額';
                    if (double.tryParse(val) == null) return '請輸入有效數字';
                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
