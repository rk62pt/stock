import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../services/stock_service.dart';
import '../widgets/stock_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    final provider = Provider.of<StockProvider>(context, listen: false);

    if (provider.apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先至設定輸入 API Key')),
      );
      return;
    }

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await StockService.searchStocks(query, provider.apiKey);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _addStock(String symbol) {
    Provider.of<StockProvider>(context, listen: false).addStock(symbol);
    _searchController.clear();
    setState(() {
      _searchResults = [];
      // Close search functionality or keep it open?
      // Let's clear results to indicate success
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $symbol')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = Provider.of<StockProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('庫存'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => stockProvider.fetchStocks(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入代號或名稱搜尋 (例如: 2330)...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).scaffoldBackgroundColor == Colors.black
                        ? Colors.grey[900]
                        : Colors.grey[100],
              ),
              onSubmitted: _performSearch,
              textInputAction: TextInputAction.search,
            ),
          ),

          // Search Results Overlay (Simple logic: if results exist, show them, else show watchlist)
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  // result is StockData from search
                  return ListTile(
                    title: Text(result.symbol),
                    subtitle: Text(result.shortName ?? result.longName ?? ''),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => _addStock(result.symbol),
                  );
                },
              ),
            )
          else
            // Watchlist
            Expanded(
              child: stockProvider.isLoading && stockProvider.stocks.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : stockProvider.error != null
                      ? Center(child: Text(stockProvider.error!))
                      : stockProvider.stocks.isEmpty
                          ? const Center(
                              child: Text(
                                '目前沒有追蹤的股票',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: stockProvider.stocks.length,
                              itemBuilder: (context, index) {
                                final stock = stockProvider.stocks[index];
                                return StockCard(
                                  stock: stock,
                                  onRemove: (symbol) =>
                                      stockProvider.removeStock(symbol),
                                );
                              },
                            ),
            ),
        ],
      ),
    );
  }
}
