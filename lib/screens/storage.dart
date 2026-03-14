import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:storehsk/utils/currency_formatter.dart';

// Create Firebase service instance
final FirebaseService _firebaseService = FirebaseService();

class _StockFolder {
  final String key;
  final String displayName;
  final List<Stocks> items;

  const _StockFolder({
    required this.key,
    required this.displayName,
    required this.items,
  });
}

String _normalizeName(String value) {
  final cleaned = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned;
}

String _toTitleCase(String value) {
  if (value.isEmpty) return value;
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

bool _isLikelySuffixToken(String token) {
  if (token.isEmpty) return false;
  return RegExp(r'(?=.*[a-z])(?=.*\d)[a-z0-9-]+').hasMatch(token) ||
      RegExp(r'^[a-z]{1,3}\d{1,4}$').hasMatch(token) ||
      RegExp(r'^\d+[a-z]{1,3}$').hasMatch(token);
}

String _deriveFolderKey(String itemName) {
  final normalized = _normalizeName(itemName);
  if (normalized.isEmpty) return itemName.toLowerCase().trim();

  final tokens = normalized.split(' ');
  if (tokens.length <= 1) {
    return normalized;
  }

  final lastToken = tokens.last;
  if (_isLikelySuffixToken(lastToken)) {
    return tokens.sublist(0, tokens.length - 1).join(' ');
  }

  return normalized;
}

List<_StockFolder> _groupIntoFolders(List<Stocks> items) {
  final Map<String, List<Stocks>> grouped = {};

  for (final item in items) {
    final key = _deriveFolderKey(item.itemName);
    grouped.putIfAbsent(key, () => []).add(item);
  }

  final folders = grouped.entries.map((entry) {
    final sortedItems = [...entry.value]
      ..sort((a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));
    return _StockFolder(
      key: entry.key,
      displayName: _toTitleCase(entry.key),
      items: sortedItems,
    );
  }).toList()
    ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

  return folders;
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
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        
        Color getCountColor() {
          if (item.isOutOfStock) return Colors.red;
          if (item.isLowStock) return Colors.orange;
          return Colors.green;
        }

        IconData getStockIcon() {
          if (item.isOutOfStock) return Icons.cancel_rounded;
          if (item.isLowStock) return Icons.warning_amber_rounded;
          return Icons.check_circle_rounded;
        }

        String getStockStatus() {
          if (item.isOutOfStock) return 'Out of Stock';
          if (item.isLowStock) return 'Low Stock';
          return 'In Stock';
        }

        return FCard(
          child: InkWell(
            onTap: () => onItemTap?.call(item),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: getCountColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      getStockIcon(),
                      color: getCountColor(),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: getCountColor().withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                getStockStatus(),
                                style: TextStyle(
                                  color: getCountColor(),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(item.itemDate),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        if (item.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Stock Count
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${item.itemCount}',
                        style: TextStyle(
                          color: getCountColor(),
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      if (item.unit != null)
                        Text(
                          item.unit!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class FolderedStockListView extends StatelessWidget {
  final List<_StockFolder> folders;
  final Function(Stocks)? onItemTap;

  const FolderedStockListView({
    super.key,
    required this.folders,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: folders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final folder = folders[index];
        final totalCount = folder.items.fold<int>(0, (sum, item) => sum + item.itemCount);

        return FCard(
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(Icons.folder_open_rounded, color: Colors.amber),
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              title: Text(
                folder.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${folder.items.length} / $totalCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
              children: [
                StockListView(
                  items: folder.items,
                  onItemTap: onItemTap,
                ),
              ],
            ),
          ),
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

enum StockFilter { all, inStock, lowStock, outOfStock }

class _StorageState extends State<Storage> {
  String searchQuery = '';
  StockFilter selectedFilter = StockFilter.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleItemTap(Stocks item) {
    final TextEditingController quantityController = TextEditingController();
    
    Color getStockColor() {
      if (item.isOutOfStock) return Colors.red;
      if (item.isLowStock) return Colors.orange;
      return Colors.green;
    }

    String getStockStatus() {
      if (item.isOutOfStock) return 'Out of Stock';
      if (item.isLowStock) return 'Low Stock';
      return 'In Stock';
    }

    final profitMargin = (item.stockPrice != null && item.sellPrice != null && item.stockPrice! > 0)
        ? ((item.sellPrice! - item.stockPrice!) / item.stockPrice! * 100)
        : null;

    final potentialProfit = (item.stockPrice != null && item.sellPrice != null)
        ? ((item.sellPrice! - item.stockPrice!) * item.itemCount)
        : null;

    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        style: style,
        animation: animation,
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: getStockColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                getStockStatus(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock Count
                _buildDetailRow(
                  'Current Stock',
                  '${item.itemCount}${item.unit != null ? ' ${item.unit}' : ''}',
                  Icons.inventory_2_rounded,
                  getStockColor(),
                  isBold: true,
                ),
                const SizedBox(height: 16),
                
                // Date
                _buildDetailRow(
                  'Date Added',
                  DateFormat('dd MMMM yyyy').format(item.itemDate),
                  Icons.calendar_today,
                  Colors.blue,
                ),
                
                // Description
                if (item.description != null) ...[
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Description',
                    item.description!,
                    Icons.description,
                    Colors.purple,
                  ),
                ],
                
                // Pricing Section
                if (item.stockPrice != null || item.sellPrice != null) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Pricing Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                if (item.stockPrice != null)
                  _buildDetailRow(
                    'Stock Price (Cost)',
                    formatRupiah(item.stockPrice!),
                    Icons.shopping_cart,
                    Colors.orange,
                  ),
                
                if (item.sellPrice != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Sell Price',
                    formatRupiah(item.sellPrice!),
                    Icons.attach_money,
                    Colors.green,
                  ),
                ],
                
                if (profitMargin != null) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Profit Margin',
                    '${profitMargin.toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.green,
                    isBold: true,
                  ),
                ],
                
                if (potentialProfit != null && item.itemCount > 0) ...[
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Potential Profit',
                    formatRupiah(potentialProfit),
                    Icons.account_balance_wallet,
                    Colors.green,
                    isBold: true,
                  ),
                ],
                const SizedBox(height: 24),
                
                // Input box with buttons on the right
                Row(
                  children: [
                    Expanded(
                      child: FTextField(
                        control: .managed(
                          controller: quantityController
                          ),
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        hint: 'Adjust stock (e.g., +5, -3)',
                      ),
                    ),
                    const SizedBox(width: 12),
                    FButton(
                      onPress: () async {
                        final input = quantityController.text.trim();
                        if (input.isEmpty) {
                          Navigator.of(context).pop();
                          return;
                        }
                        
                        try {
                          int adjustment = int.parse(input);
                          int newQuantity = item.itemCount + adjustment;
                          
                          if (newQuantity < 0) {
                            showFToast(
                              context: context,
                              style: .delta(padding: EdgeInsets.all(16)),
                              icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
                              title: const Text('Invalid Stock'),
                              description: const Text('Stock cannot be negative'),
                              suffixBuilder: (context, entry) =>
                                  GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
                              alignment: .topCenter,
                              duration: const Duration(seconds: 3),
                            );
                            return;
                          }
                          
                          final updatedItem = Stocks(
                            id: item.id,
                            itemName: item.itemName,
                            itemCount: newQuantity,
                            itemDate: item.itemDate,
                            description: item.description,
                            stockPrice: item.stockPrice,
                            sellPrice: item.sellPrice,
                            unit: item.unit,
                            lowStockThreshold: item.lowStockThreshold,
                            createdAt: item.createdAt,
                          );
                          
                          await _firebaseService.updateStock(item.id!, updatedItem);
                          
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            // Small delay to ensure dialog is dismissed before showing toast
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (context.mounted) {
                                showFToast(
                                  context: context,
                                  style: .delta(padding: EdgeInsets.all(16)),
                                  icon: const Icon(FIcons.check, color: Colors.green),
                                  title: const Text('Stock Updated'),
                                  description: Text('${item.itemName}: ${item.itemCount} → $newQuantity'),
                                  suffixBuilder: (context, entry) =>
                                      GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
                                  alignment: .bottomCenter,
                                  duration: const Duration(seconds: 4),
                                );
                              }
                            });
                          }
                        } catch (e) {
                          showFToast(
                            context: context,
                            style: .delta(padding: EdgeInsets.all(16)),
                            icon: const Icon(FIcons.circleAlert, color: Colors.red),
                            title: const Text('Invalid Input'),
                            description: const Text('Please enter a valid number (e.g., +5 or -3)'),
                            suffixBuilder: (context, entry) =>
                                GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
                            alignment: .topCenter,
                            duration: const Duration(seconds: 3),
                          );
                        }
                      },
                      child: const Text('Ok'),
                    ),
                    const SizedBox(width: 8),
                    FButton(
                      onPress: () => Navigator.of(context).pop(),
                      variant: .outline,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          FButton(
            onPress: () async {
              // Show confirmation dialog
              final confirmed = await showFDialog<bool>(
                context: context,
                builder: (context, style, animation) => FDialog(
                  style: style,
                  animation: animation,
                  title: const Text('Delete Item'),
                  body: Text('Are you sure you want to delete "${item.itemName}"?'),
                  actions: [
                    FButton(
                      onPress: () => Navigator.of(context).pop(false),
                      variant: .outline,
                      child: const Text('Cancel'),
                    ),
                    FButton(
                      onPress: () => Navigator.of(context).pop(true),
                      variant: .destructive,
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && context.mounted) {
                try {
                  await _firebaseService.deleteStock(item.id!);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    // Small delay to ensure dialog is dismissed before showing toast
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        showFToast(
                          context: context,
                          style: .delta(padding: EdgeInsets.all(16)),
                          icon: const Icon(FIcons.trash, color: Colors.green),
                          title: const Text('Item Deleted'),
                          description: Text('"${item.itemName}" deleted successfully'),
                          suffixBuilder: (context, entry) =>
                              GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
                          alignment: .topCenter,
                          duration: const Duration(seconds: 3),
                        );
                      }
                    });
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (context.mounted) {
                        showFToast(
                          context: context,
                          style: .delta(padding: EdgeInsets.all(16)),
                          icon: const Icon(FIcons.circleAlert, color: Colors.red),
                          title: const Text('Delete Failed'),
                          description: Text('Failed to delete item: $e'),
                          suffixBuilder: (context, entry) =>
                              GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
                          alignment: .topCenter,
                          duration: const Duration(seconds: 4),
                        );
                      }
                    });
                  }
                }
              }
            },
            variant: .destructive,
            child: const Text('Delete Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: isBold ? color : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Stocks> _filterItems(List<Stocks> items) {
    var filtered = items;
    
    // Apply stock status filter
    switch (selectedFilter) {
      case StockFilter.inStock:
        filtered = filtered.where((item) => item.isInStock).toList();
        break;
      case StockFilter.lowStock:
        filtered = filtered.where((item) => item.isLowStock).toList();
        break;
      case StockFilter.outOfStock:
        filtered = filtered.where((item) => item.isOutOfStock).toList();
        break;
      case StockFilter.all:
        break;
    }
    
    // Apply search query
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.itemName.toLowerCase().contains(searchQuery.toLowerCase()) ||
              (item.description?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
              (item.unit?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false))
          .toList();
    }
    
    return filtered;
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
          final groupedFolders = _groupIntoFolders(filteredItems);

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
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search items, description, unit...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            ),
                          PopupMenuButton<StockFilter>(
                            icon: Icon(
                              Icons.filter_list,
                              color: selectedFilter != StockFilter.all ? Colors.blue : null,
                            ),
                            tooltip: 'Filter by status',
                            onSelected: (filter) {
                              setState(() {
                                selectedFilter = filter;
                              });
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: StockFilter.all,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.all_inclusive,
                                      color: selectedFilter == StockFilter.all ? Colors.blue : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('All Items'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: StockFilter.inStock,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: selectedFilter == StockFilter.inStock ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('In Stock'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: StockFilter.lowStock,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: selectedFilter == StockFilter.lowStock ? Colors.orange : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Low Stock'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: StockFilter.outOfStock,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cancel_rounded,
                                      color: selectedFilter == StockFilter.outOfStock ? Colors.red : Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Out of Stock'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                
                // Filter Chips
                if (selectedFilter != StockFilter.all || searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Chip(
                                avatar: const Icon(Icons.search, size: 16),
                                label: Text('Search: "$searchQuery"'),
                                onDeleted: () {
                                  setState(() {
                                    searchQuery = '';
                                  });
                                },
                                deleteIcon: const Icon(Icons.close, size: 16),
                              ),
                            ),
                          if (selectedFilter != StockFilter.all)
                            Chip(
                              avatar: Icon(
                                selectedFilter == StockFilter.inStock
                                    ? Icons.check_circle_rounded
                                    : selectedFilter == StockFilter.lowStock
                                        ? Icons.warning_amber_rounded
                                        : Icons.cancel_rounded,
                                size: 16,
                                color: selectedFilter == StockFilter.inStock
                                    ? Colors.green
                                    : selectedFilter == StockFilter.lowStock
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                              label: Text(
                                selectedFilter == StockFilter.inStock
                                    ? 'In Stock'
                                    : selectedFilter == StockFilter.lowStock
                                        ? 'Low Stock'
                                        : 'Out of Stock',
                              ),
                              onDeleted: () {
                                setState(() {
                                  selectedFilter = StockFilter.all;
                                });
                              },
                              deleteIcon: const Icon(Icons.close, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                
                // Items Display
                if (filteredItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items match your filters',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: FolderedStockListView(
                      folders: groupedFolders,
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