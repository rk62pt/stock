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
      final shares = int.parse(_sharesController.text);
      final price = double.parse(_priceController.text);

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

              // Buy/Sell Segment
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<TransactionType>(
                      title: const Text('買入'),
                      value: TransactionType.buy,
                      groupValue: _type,
                      onChanged: (val) => setState(() => _type = val!),
                      activeColor: Colors
                          .red, // Taiwan stock color for Up/Buy is usually Red
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<TransactionType>(
                      title: const Text('賣出'),
                      value: TransactionType.sell,
                      groupValue: _type,
                      onChanged: (val) => setState(() => _type = val!),
                      activeColor: Colors
                          .green, // Taiwan stock color for Down/Sell is usually Green
                    ),
                  ),
                ],
              ),

              // Shares
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

              // Price
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: '價格 (元)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return '請輸入價格';
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
