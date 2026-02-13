import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:gap/gap.dart';

final List<Stocks> inventory = [
  Stocks(itemName: 'Produk A', itemCount: 25),
  Stocks(itemName: 'Produk B', itemCount: 8),
  Stocks(itemName: 'Produk C', itemCount: 0),
  Stocks(itemName: 'Produk D', itemCount: 15),
  Stocks(itemName: 'Produk E', itemCount: 5),
  Stocks(itemName: 'Produk F', itemCount: 32),
  Stocks(itemName: 'Produk G', itemCount: 3),
  Stocks(itemName: 'Produk H', itemCount: 12),
];

// Stock Item Component
class StockItem extends StatelessWidget {
  final Stocks item;
  final VoidCallback? onTap;

  const StockItem({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color getStockColor() {
      if (item.itemCount == 0) return Colors.red;
      if (item.itemCount < 10) return Colors.orange;
      return Colors.green;
    }

    IconData getStockIcon() {
      if (item.itemCount == 0) return Icons.warning;
      if (item.itemCount < 10) return Icons.trending_down;
      return Icons.check_circle;
    }

    return FCard(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    getStockIcon(),
                    color: getStockColor(),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'In Stock:',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${item.itemCount}',
                    style: TextStyle(
                      color: getStockColor(),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Stock Grid Component
class StockGrid extends StatelessWidget {
  final List<Stocks> items;
  final Function(Stocks)? onItemTap;

  const StockGrid({
    super.key,
    required this.items,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return StockItem(
          item: item,
          onTap: () => onItemTap?.call(item),
        );
      },
    );
  }
}

// Stock Search Component
class StockSearch extends StatefulWidget {
  final List<Stocks> items;
  final Function(List<Stocks>) onSearchResults;

  const StockSearch({
    super.key,
    required this.items,
    required this.onSearchResults,
  });

  @override
  State<StockSearch> createState() => _StockSearchState();
}

class _StockSearchState extends State<StockSearch> {
  final TextEditingController _searchController = TextEditingController();

  void _performSearch(String query) {
    if (query.isEmpty) {
      widget.onSearchResults(widget.items);
    } else {
      final filteredItems = widget.items
          .where((item) =>
              item.itemName.toLowerCase().contains(query.toLowerCase()))
          .toList();
      widget.onSearchResults(filteredItems);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search items...',
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
        ),
        onChanged: _performSearch,
      ),
    );
  }
}

class Storage extends StatefulWidget {
  const Storage({super.key});

  @override
  State<Storage> createState() => _StorageState();
}

class _StorageState extends State<Storage> {
  List<Stocks> filteredInventory = inventory;
  bool isGridView = false;

  void _handleSearchResults(List<Stocks> results) {
    setState(() {
      filteredInventory = results;
    });
  }

  void _handleItemTap(Stocks item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.itemName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock: ${item.itemCount}'),
            const SizedBox(height: 8),
            Text(
              'Status: ${item.itemCount == 0 ? 'Out of Stock' : item.itemCount < 10 ? 'Low Stock' : 'In Stock'}',
              style: TextStyle(
                color: item.itemCount == 0
                    ? Colors.red
                    : item.itemCount < 10
                        ? Colors.orange
                        : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Gap(16),
            
            // Search Bar
            StockSearch(
              items: inventory,
              onSearchResults: _handleSearchResults,
            ),
            
            // View Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.grid_view,
                          color: isGridView ? Colors.blue : Colors.grey,
                        ),
                        onPressed: () => setState(() => isGridView = true),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.list,
                          color: !isGridView ? Colors.blue : Colors.grey,
                        ),
                        onPressed: () => setState(() => isGridView = false),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Items Display
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: isGridView
                  ? StockGrid(
                      items: filteredInventory,
                      onItemTap: _handleItemTap,
                    )
                  : StockListView(
                      items: filteredInventory,
                      onItemTap: _handleItemTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stock List View Component
class StockListView extends StatelessWidget {
  final List<Stocks> items;
  final Function(Stocks)? onItemTap;

  const StockListView({
    super.key,
    required this.items,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return FItemGroup.builder(
      count: items.length,
      itemBuilder: (context, index) {
        if (index >= items.length) return null;
        
        final item = items[index];
        
        Color getCountColor() {
          if (item.itemCount == 0) return Colors.red;
          if (item.itemCount < 10) return Colors.orange;
          return Colors.green;
        }

        IconData getStockIcon() {
          if (item.itemCount == 0) return Icons.warning;
          if (item.itemCount < 10) return Icons.trending_down;
          return Icons.check_circle;
        }

        return FItem(
          title: Text(
            item.itemName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            item.itemCount == 0
                ? 'Out of stock'
                : item.itemCount < 10
                    ? 'Low stock'
                    : 'In stock',
          ),
          prefix: Icon(
            getStockIcon(),
            color: getCountColor(),
          ),
          suffix: Text(
            '${item.itemCount}',
            style: TextStyle(
              color: getCountColor(),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          onPress: () => onItemTap?.call(item),
        );
      },
    );
  }
}