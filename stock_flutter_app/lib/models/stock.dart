class StockData {
  final String symbol;
  final double regularMarketPrice;
  final double regularMarketChange;
  final double regularMarketChangePercent;
  final String? shortName;
  final String? longName;

  StockData({
    required this.symbol,
    required this.regularMarketPrice,
    required this.regularMarketChange,
    required this.regularMarketChangePercent,
    this.shortName,
    this.longName,
  });

  factory StockData.fromJson(Map<String, dynamic> json) {
    return StockData(
      symbol: json['symbol'] ?? '',
      regularMarketPrice: (json['regularMarketPrice'] as num?)?.toDouble() ?? 0.0,
      regularMarketChange: (json['regularMarketChange'] as num?)?.toDouble() ?? 0.0,
      regularMarketChangePercent: (json['regularMarketChangePercent'] as num?)?.toDouble() ?? 0.0,
      shortName: json['shortName'] as String?,
      longName: json['longName'] as String?,
    );
  }
}
