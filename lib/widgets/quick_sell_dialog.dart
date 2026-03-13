import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:storehsk/models/sale.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:storehsk/services/sales_service.dart';
import 'package:storehsk/utils/currency_formatter.dart';

final FirebaseService _firebaseService = FirebaseService();
final SalesService _salesService = SalesService();

Future<bool> showQuickSellDialog(
  BuildContext context, {
  required Stocks item,
  Function(Sale)? onSaleCompleted,
}) async {
  final result = await showFDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context, style, animation) => _QuickSellDialog(
      item: item,
      onSaleCompleted: onSaleCompleted,
    ),
  );
  return result ?? false;
}

class _QuickSellDialog extends StatefulWidget {
  final Stocks item;
  final Function(Sale)? onSaleCompleted;

  const _QuickSellDialog({
    required this.item,
    this.onSaleCompleted,
  });

  @override
  State<_QuickSellDialog> createState() => _QuickSellDialogState();
}

class _QuickSellDialogState extends State<_QuickSellDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _processSale() async {
    if (!_formKey.currentState!.validate()) return;

    final quantityToSell = int.tryParse(_quantityController.text.trim()) ?? 0;

    if (quantityToSell <= 0) {
      showFToast(
        context: context,
        style: .delta(padding: EdgeInsets.all(16)),
        icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
        title: const Text('Invalid Quantity'),
        description: const Text('Please enter a valid quantity'),
        suffixBuilder: (context, entry) =>
            GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
        alignment: .topCenter,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (quantityToSell > widget.item.itemCount) {
      showFToast(
        context: context,
        style: .delta(padding: EdgeInsets.all(16)),
        icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
        title: const Text('Insufficient Stock'),
        description: Text('Only ${widget.item.itemCount} available'),
        suffixBuilder: (context, entry) =>
            GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
        alignment: .topCenter,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    if (widget.item.stockPrice == null || widget.item.sellPrice == null) {
      showFToast(
        context: context,
        style: .delta(padding: EdgeInsets.all(16)),
        icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
        title: const Text('Missing Prices'),
        description: const Text('Stock price and sell price are required'),
        suffixBuilder: (context, entry) =>
            GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
        alignment: .topCenter,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Calculate profit
      final profit = (widget.item.sellPrice! - widget.item.stockPrice!) * quantityToSell;

      // Create sale record
      final sale = Sale(
        itemId: widget.item.id!,
        itemName: widget.item.itemName,
        quantitySold: quantityToSell,
        stockPrice: widget.item.stockPrice!,
        sellPrice: widget.item.sellPrice!,
        profit: profit,
        saleDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Add sale to database
      await _salesService.addSale(sale);

      // Update stock quantity
      final newQuantity = widget.item.itemCount - quantityToSell;
      final updatedStock = Stocks(
        id: widget.item.id,
        itemName: widget.item.itemName,
        itemCount: newQuantity,
        itemDate: widget.item.itemDate,
        description: widget.item.description,
        stockPrice: widget.item.stockPrice,
        sellPrice: widget.item.sellPrice,
        unit: widget.item.unit,
        barcode: widget.item.barcode,
        lowStockThreshold: widget.item.lowStockThreshold,
        createdAt: widget.item.createdAt,
      );

      await _firebaseService.updateStock(widget.item.id!, updatedStock);
      widget.onSaleCompleted?.call(sale);

      if (mounted) {
        Navigator.pop(context, true);
        showFToast(
          context: context,
          style: .delta(padding: EdgeInsets.all(16)),
          icon: const Icon(FIcons.check, color: Colors.green),
          title: const Text('Sale Completed'),
          description: Text('Sale completed! Profit: ${formatRupiah(profit)}'),
          suffixBuilder: (context, entry) =>
              GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
          alignment: .topCenter,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          style: .delta(padding: EdgeInsets.all(16)),
          icon: const Icon(FIcons.circleAlert, color: Colors.red),
          title: const Text('Error'),
          description: Text('Error processing sale: $e'),
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

  @override
  Widget build(BuildContext context) {
    final profit = widget.item.sellPrice != null && widget.item.stockPrice != null
        ? (widget.item.sellPrice! - widget.item.stockPrice!)
        : 0.0;

    return FDialog(
      title: const Text('Sell Item'),
      body: Material(
        color: Colors.transparent,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.item.itemName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available: ${widget.item.itemCount} ${widget.item.unit ?? "pcs"}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    if (widget.item.barcode != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Barcode: ${widget.item.barcode}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Pricing info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sell Price:'),
                        Text(
                          formatRupiah(widget.item.sellPrice ?? 0),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Profit per item:'),
                        Text(
                          formatRupiah(profit),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Quantity input
              FTextField(
                control: .managed(
                  controller: _quantityController,
                  onChange: (value) {
                    _quantityController.value = value;
                  },
                ),
                label: const Text('Quantity to Sell *'),
                hint: 'Enter quantity',
                keyboardType: TextInputType.number,
                onSubmit: (value) {
                  setState(() {}); // Trigger rebuild to update total
                },
              ),
              const SizedBox(height: 16),
              
              // Total calculation
              if (_quantityController.text.isNotEmpty && int.tryParse(_quantityController.text) != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Sale:'),
                          Text(
                            formatRupiah((widget.item.sellPrice ?? 0) * int.parse(_quantityController.text)),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Profit:'),
                          Text(
                            formatRupiah(profit * int.parse(_quantityController.text)),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
      actions: [
        FButton(
          onPress: _isLoading ? null : () => Navigator.pop(context, false),
          variant: .outline,
          child: const Text('Cancel'),
        ),
        FButton(
          onPress: _isLoading ? null : _processSale,
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
      ],
    );
  }
}
