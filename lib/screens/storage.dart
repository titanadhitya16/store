import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:intl/intl.dart';

// Create Firebase service instance
final FirebaseService _firebaseService = FirebaseService();

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
                    'Date: ${DateFormat('dd/MM/yyyy').format(item.itemDate)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.itemCount == 0
                    ? 'Out of stock'
                    : item.itemCount < 10
                        ? 'Low stock'
                        : 'In stock',
              ),
              Text(
                DateFormat('dd/MM/yyyy').format(item.itemDate),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
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

// Storage Screen
class Storage extends StatefulWidget {
  const Storage({super.key});

  @override
  State<Storage> createState() => _StorageState();
}

class _StorageState extends State<Storage> {
  bool isGridView = false;
  String searchQuery = '';

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
            Text('Date: ${DateFormat('dd/MM/yyyy').format(item.itemDate)}'),
            const SizedBox(height: 8),
            if (item.category != null) Text('Category: ${item.category}'),
            if (item.description != null) ...[
              const SizedBox(height: 8),
              Text('Description: ${item.description}'),
            ],
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

  List<Stocks> _filterItems(List<Stocks> items) {
    if (searchQuery.isEmpty) return items;
    return items
        .where((item) =>
            item.itemName.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: StreamBuilder<List<Stocks>>(
        stream: _firebaseService.getStocksStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final allItems = snapshot.data ?? [];
          final filteredItems = _filterItems(allItems);

          if (allItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No items in inventory'),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your first item using the + button',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ),
                
                // View Toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items (${filteredItems.length})',
                        style: const TextStyle(
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
                          items: filteredItems,
                          onItemTap: _handleItemTap,
                        )
                      : StockListView(
                          items: filteredItems,
                          onItemTap: _handleItemTap,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}