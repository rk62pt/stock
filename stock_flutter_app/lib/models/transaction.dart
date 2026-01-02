enum TransactionType { buy, sell }

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
    return Transaction(
      id: json['id'],
      symbol: json['symbol'],
      date: DateTime.parse(json['date']),
      type: json['type'] == 'TransactionType.buy'
          ? TransactionType.buy
          : TransactionType.sell,
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
