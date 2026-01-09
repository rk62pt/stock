enum TransactionType { buy, sell, stockDividend, cashDividend }

class Transaction {
  final String id;
  final String symbol;
  final DateTime date;
  final TransactionType type;
  final int shares;
  final double price;

  Transaction({
    required this.id,
    required this.symbol,
    required this.date,
    required this.type,
    required this.shares,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'date': date.toIso8601String(),
      'type': type.toString(),
      'shares': shares,
      'price': price,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    String typeStr = json['type'].toString();
    TransactionType tType = TransactionType.buy;

    if (typeStr.contains('sell')) {
      tType = TransactionType.sell;
    } else if (typeStr.contains('stockDividend')) {
      tType = TransactionType.stockDividend;
    } else if (typeStr.contains('cashDividend')) {
      tType = TransactionType.cashDividend;
    }

    return Transaction(
      id: json['id'],
      symbol: json['symbol'],
      date: DateTime.parse(json['date']),
      type: tType,
      shares: json['shares'],
      price: (json['price'] as num).toDouble(),
    );
  }
  Transaction copyWith({
    String? id,
    String? symbol,
    DateTime? date,
    TransactionType? type,
    int? shares,
    double? price,
  }) {
    return Transaction(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      type: type ?? this.type,
      shares: shares ?? this.shares,
      price: price ?? this.price,
    );
  }
}
