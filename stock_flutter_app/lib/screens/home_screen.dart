import 'dart:async';
import 'dart:math'; // For min

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stock_provider.dart';
import '../services/stock_service.dart';
import '../widgets/stock_card.dart';
import '../models/stock.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<StockData> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce; // Added for debounce

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // Cancel debounce timer on dispose
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) async {
    final provider = Provider.of<StockProvider>(context, listen: false);

    // Quick validation
    if (provider.apiKey.isEmpty) {
      // Don't show snackbar on every keystroke, just return or handle quietly?
      // Or checking once on init is better.
      return;
    }

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Strip .TW if present and trim
    final cleanQuery = query.replaceAll('.TW', '').trim();
    if (cleanQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final results =
          await StockService.searchStocks(cleanQuery, provider.apiKey);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      print('Search error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _addStock(String symbol) {
    Provider.of<StockProvider>(context, listen: false).addStock(symbol);
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false; // Reset search state
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $symbol')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = Provider.of<StockProvider>(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          stockProvider.fetchStocks();
          // Also refresh metrics
          stockProvider.refreshMetrics();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('更新報價'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Floating Search Bar Area
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28.0),
                ),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: '搜尋股票代號...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.menu,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _performSearch('');
                            },
                          ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()),
                              );
                            },
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.purple.shade100,
                              child: const Icon(Icons.settings,
                                  size: 20, color: Colors.purple),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: _performSearch,
                ),
              ),
            ),

            // Dashboard Summary
            const DashboardSummaryWidget(),

            // Main Content
            Expanded(
              child: _isSearching
                  ? _buildSearchResults() // Searching overlay? Or view.
                  : (_searchResults.isNotEmpty &&
                          _searchController.text.isNotEmpty)
                      ? _buildSearchResults()
                      : _buildStockTabs(stockProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) return const Center(child: CircularProgressIndicator());

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child:
                Text(result.symbol.substring(0, min(result.symbol.length, 2))),
          ),
          title: Text(result.symbol,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(result.shortName ?? result.longName ?? ''),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _addStock(result.symbol),
          ),
        );
      },
    );
  }

  Widget _buildStockTabs(StockProvider stockProvider) {
    if (stockProvider.stocks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('尚無自選股',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    final activeStocks = stockProvider.stocks
        .where((s) => stockProvider.isStockActive(s.symbol))
        .toList();
    // Settled stocks: In watchlist BUT not active (shares == 0).
    // Or should it include ALL metrics that have realized PL?
    // For now, adhere to list: "Move to settled stats when shares is 0".
    final settledStocks = stockProvider.stocks
        .where((s) => !stockProvider.isStockActive(s.symbol))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '現股庫存'),
              Tab(text: '已結算/無庫存'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: activeStocks.length,
                  itemBuilder: (ctx, i) => StockCard(
                    stock: activeStocks[i],
                    onRemove: (s) => stockProvider.removeStock(s),
                  ),
                ),
                ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: settledStocks.length,
                  itemBuilder: (ctx, i) => StockCard(
                    stock: settledStocks[i],
                    onRemove: (s) => stockProvider.removeStock(s),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardSummaryWidget extends StatelessWidget {
  const DashboardSummaryWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Watch provider
    final provider = Provider.of<StockProvider>(context);
    final dailyPL = provider.totalDailyPL;
    final unrealizedPL = provider.totalUnrealizedPL;
    final realizedPL = provider.periodRealizedPL;

    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 1,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoColumn('當日損益', dailyPL, isCurrency: true),
                    _buildInfoColumn('總未實現', unrealizedPL, isCurrency: true),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<TimePeriod>(
                      value: provider.selectedPeriod,
                      underline: Container(),
                      items: const [
                        DropdownMenuItem(
                            value: TimePeriod.day, child: Text('當日')),
                        DropdownMenuItem(
                            value: TimePeriod.month, child: Text('當月')),
                        DropdownMenuItem(
                            value: TimePeriod.quarter, child: Text('當季')),
                        DropdownMenuItem(
                            value: TimePeriod.year, child: Text('當年')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          provider.setPeriod(val);
                        }
                      },
                    ),
                    Text(
                      '已實現: ${realizedPL > 0 ? '+' : ''}${realizedPL.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: realizedPL >= 0 ? Colors.red : Colors.green),
                    )
                  ],
                )
              ],
            )));
  }

  Widget _buildInfoColumn(String label, double val, {bool isCurrency = false}) {
    final color = val > 0 ? Colors.red : (val < 0 ? Colors.green : Colors.grey);
    final text = val.toStringAsFixed(0);
    final sign = val > 0 ? '+' : '';

    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text('$sign$text',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
