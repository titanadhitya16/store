import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:storehsk/models/sale.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:storehsk/services/sales_service.dart';
import 'package:storehsk/utils/currency_formatter.dart';

final FirebaseService _firebaseService = FirebaseService();
final SalesService _salesService = SalesService();

class SellItem {
  final Stocks stock;
  int quantityToSell;

  SellItem({required this.stock, this.quantityToSell = 0});
}

void showSellFormSheet(
  BuildContext context, {
  Stocks? scannedItem,
  String? scannedBarcode,
  Function(List<Sale>)? onSaleCompleted,
}) {
  showFPersistentSheet(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    mainAxisMaxRatio: null,
    builder: (context, controller) => SellForm(
      controller: controller,
      scannedItem: scannedItem,
      scannedBarcode: scannedBarcode,
      onSaleCompleted: onSaleCompleted,
    ),
  );
}

class SellForm extends StatefulWidget {
  final FPersistentSheetController controller;
  final Stocks? scannedItem;
  final String? scannedBarcode;
  final Function(List<Sale>)? onSaleCompleted;

  const SellForm({
    super.key,
    required this.controller,
    this.scannedItem,
    this.scannedBarcode,
    this.onSaleCompleted,
  });

  @override
  State<SellForm> createState() => _SellFormState();
}

class _SellFormState extends State<SellForm> {
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, SellItem> _selectedItems = {};
  DateTime _saleDate = DateTime.now();
  bool _isLoading = false;
  String _searchQuery = '';
  bool _hasInitializedScannedItem = false;

  @override
  void dispose() {
    for (var controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _processSales() async {
    // Filter out items with quantity > 0
    final itemsToSell = _selectedItems.values
        .where((item) => item.quantityToSell > 0)
        .toList();

    if (itemsToSell.isEmpty) {
      if (mounted) {
        showFToast(
          context: context,
          style: .delta(padding: EdgeInsets.all(16)),
          icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
          title: const Text('No Items Selected'),
          description: const Text('Please select items and quantities to sell'),
          suffixBuilder: (context, entry) =>
              GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
          alignment: .topCenter,
          duration: const Duration(seconds: 3),
        );
      }
      return;
    }

    // Validate stock availability
    for (var sellItem in itemsToSell) {
      if (sellItem.quantityToSell > sellItem.stock.itemCount) {
        if (mounted) {
          showFToast(
            context: context,
            style: .delta(padding: EdgeInsets.all(16)),
            icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
            title: const Text('Insufficient Stock'),
            description: Text('${sellItem.stock.itemName}: Only ${sellItem.stock.itemCount} available'),
            suffixBuilder: (context, entry) =>
                GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
            alignment: .topCenter,
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }

      if (sellItem.stock.stockPrice == null || sellItem.stock.sellPrice == null) {
        if (mounted) {
          showFToast(
            context: context,
            style: .delta(padding: EdgeInsets.all(16)),
            icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
            title: const Text('Missing Prices'),
            description: Text('${sellItem.stock.itemName}: Stock price and sell price are required'),
            suffixBuilder: (context, entry) =>
                GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
            alignment: .topCenter,
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<Sale> completedSales = [];

      for (var sellItem in itemsToSell) {
        // Calculate profit
        final profit = (sellItem.stock.sellPrice! - sellItem.stock.stockPrice!) * 
                       sellItem.quantityToSell;

        // Create sale record
        final sale = Sale(
          itemId: sellItem.stock.id!,
          itemName: sellItem.stock.itemName,
          quantitySold: sellItem.quantityToSell,
          stockPrice: sellItem.stock.stockPrice!,
          sellPrice: sellItem.stock.sellPrice!,
          profit: profit,
          saleDate: _saleDate,
          createdAt: DateTime.now(),
        );

        // Add sale to database
        await _salesService.addSale(sale);

        // Update stock quantity
        final newQuantity = sellItem.stock.itemCount - sellItem.quantityToSell;
        final updatedStock = Stocks(
          id: sellItem.stock.id,
          itemName: sellItem.stock.itemName,
          itemCount: newQuantity,
          itemDate: sellItem.stock.itemDate,
          description: sellItem.stock.description,
          stockPrice: sellItem.stock.stockPrice,
          sellPrice: sellItem.stock.sellPrice,
          unit: sellItem.stock.unit,
          barcode: sellItem.stock.barcode,
          lowStockThreshold: sellItem.stock.lowStockThreshold,
          createdAt: sellItem.stock.createdAt,
        );

        await _firebaseService.updateStock(sellItem.stock.id!, updatedStock);
        completedSales.add(sale);
      }

      widget.onSaleCompleted?.call(completedSales);

      if (mounted) {
        widget.controller.hide();
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            showFToast(
              context: context,
              style: .delta(padding: EdgeInsets.all(16)),
              icon: const Icon(FIcons.check, color: Colors.green),
              title: const Text('Sales Completed'),
              description: Text('${completedSales.length} item(s) sold successfully'),
              suffixBuilder: (context, entry) =>
                  GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
              alignment: .topCenter,
              duration: const Duration(seconds: 3),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          style: .delta(padding: EdgeInsets.all(16)),
          icon: const Icon(FIcons.circleAlert, color: Colors.red),
          title: const Text('Error'),
          description: Text('Failed to process sales: $e'),
          suffixBuilder: (context, entry) =>
              GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
          alignment: .topCenter,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _saleDate) {
      setState(() {
        _saleDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: context.theme.colors.background,
          border: Border.symmetric(
            horizontal: BorderSide(color: context.theme.colors.border),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.theme.colors.border),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sell Items',
                    style: context.theme.typography.xl2.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => widget.controller.hide(),
                  ),
                ],
              ),
            ),

            // Sale Date Picker
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.theme.colors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: context.theme.colors.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Sale Date: ${_saleDate.day}/${_saleDate.month}/${_saleDate.year}',
                        style: context.theme.typography.base,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Items List
            Expanded(
              child: StreamBuilder<List<Stocks>>(
                stream: _firebaseService.getStocksStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var items = snapshot.data ?? [];
                  
                  // Filter items with sell price and in stock
                  items = items.where((item) => 
                    item.sellPrice != null && 
                    item.stockPrice != null &&
                    item.itemCount > 0 &&
                    (_searchQuery.isEmpty || 
                     item.itemName.toLowerCase().contains(_searchQuery))
                  ).toList();
                  
                  // Pre-select scanned item if provided
                  if (!_hasInitializedScannedItem && (widget.scannedItem != null || widget.scannedBarcode != null)) {
                    _hasInitializedScannedItem = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Stocks? itemToSelect;
                      
                      if (widget.scannedItem != null) {
                        itemToSelect = items.firstWhere(
                          (item) => item.id == widget.scannedItem!.id,
                          orElse: () => items.first,
                        );
                      } else if (widget.scannedBarcode != null) {
                        itemToSelect = items.firstWhere(
                          (item) => item.barcode == widget.scannedBarcode,
                          orElse: () => items.first,
                        );
                      }
                      
                      if (itemToSelect != null && itemToSelect.id != null) {
                        setState(() {
                          if (!_selectedItems.containsKey(itemToSelect!.id)) {
                            _selectedItems[itemToSelect.id!] = SellItem(stock: itemToSelect, quantityToSell: 1);
                          } else {
                            _selectedItems[itemToSelect.id!]!.quantityToSell = 1;
                          }
                          
                          if (!_quantityControllers.containsKey(itemToSelect.id)) {
                            _quantityControllers[itemToSelect.id!] = TextEditingController(text: '1');
                          } else {
                            _quantityControllers[itemToSelect.id]!.text = '1';
                          }
                        });
                      }
                    });
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty 
                              ? 'No items available for sale'
                              : 'No matching items found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      
                      if (!_quantityControllers.containsKey(item.id)) {
                        _quantityControllers[item.id!] = TextEditingController();
                      }
                      
                      if (!_focusNodes.containsKey(item.id)) {
                        final focusNode = FocusNode();
                        _focusNodes[item.id!] = focusNode;
                        
                        // Update quantity only when field loses focus
                        focusNode.addListener(() {
                          if (!focusNode.hasFocus) {
                            final controller = _quantityControllers[item.id];
                            final sellItem = _selectedItems[item.id];
                            if (controller != null && sellItem != null) {
                              final newQuantity = int.tryParse(controller.text) ?? 0;
                              if (sellItem.quantityToSell != newQuantity) {
                                setState(() {
                                  sellItem.quantityToSell = newQuantity;
                                });
                              }
                            }
                          }
                        });
                      }
                      
                      if (!_selectedItems.containsKey(item.id)) {
                        _selectedItems[item.id!] = SellItem(stock: item);
                      }

                      final profit = item.sellPrice != null && item.stockPrice != null
                          ? (item.sellPrice! - item.stockPrice!)
                          : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.itemName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Available: ${item.itemCount}${item.unit != null ? " ${item.unit}" : ""}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatRupiah(item.sellPrice!),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        'Profit: ${formatRupiah(profit)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _quantityControllers[item.id],
                                      focusNode: _focusNodes[item.id],
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Quantity to sell',
                                        hintText: '0',
                                        border: const OutlineInputBorder(),
                                        suffixText: item.unit,
                                      ),
                                    ),
                                  ),
                                  if (_selectedItems[item.id]!.quantityToSell > 0) ...[
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            formatRupiah(profit * _selectedItems[item.id]!.quantityToSell),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Total Profit',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.theme.colors.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FButton(
                      onPress: () => widget.controller.hide(),
                      variant: .outline,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FButton(
                      onPress: _isLoading ? null : _processSales,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Complete Sale'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
