import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:intl/intl.dart';

final FirebaseService _firebaseService = FirebaseService();

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,##0', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatter.format(number).replaceAll(',', '.');
    int cursorPosition = formatted.length;
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

Future<bool> showQuickItemDialog(
  BuildContext context, {
  required String barcode,
  Function(Stocks)? onItemSaved,
}) async {
  final result = await showFDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context, style, animation) => _QuickItemDialog(
      barcode: barcode,
      onItemSaved: onItemSaved,
    ),
  );
  return result ?? false;
}

class _QuickItemDialog extends StatefulWidget {
  final String barcode;
  final Function(Stocks)? onItemSaved;

  const _QuickItemDialog({
    required this.barcode,
    this.onItemSaved,
  });

  @override
  State<_QuickItemDialog> createState() => _QuickItemDialogState();
}

class _QuickItemDialogState extends State<_QuickItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _stockPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  
  late FSelectController<String> _unitController;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  
  final List<String> _units = [
    'pcs',
    'kg',
    'liters',
    'meters',
    'boxes',
    'sets',
  ];
  
  @override
  void initState() {
    super.initState();
    _unitController = FSelectController<String>(value: 'pcs');
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _stockPriceController.dispose();
    _sellPriceController.dispose();
    _lowStockThresholdController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  double? _parsePrice(String text) {
    if (text.trim().isEmpty) return null;
    final digitsOnly = text.replaceAll('.', '');
    return double.tryParse(digitsOnly);
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_itemNameController.text.trim().isEmpty) {
      showFToast(
        context: context,
        style: .delta(padding: EdgeInsets.all(16)),
        icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
        title: const Text('Item Name Required'),
        description: const Text('Please enter an item name'),
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
      final itemName = _itemNameController.text.trim();
      final newQuantity = int.parse(_quantityController.text.trim());
      
      if (newQuantity <= 0) {
        if (mounted) {
          showFToast(
            context: context,
            style: .delta(padding: EdgeInsets.all(16)),
            icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
            title: const Text('Invalid Quantity'),
            description: const Text('Quantity must be greater than 0'),
            suffixBuilder: (context, entry) =>
                GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
            alignment: .topCenter,
            duration: const Duration(seconds: 3),
          );
        }
        return;
      }
      
      // Check if item already exists by name
      final existingItem = await _firebaseService.findStockByExactName(itemName);
      
      if (existingItem != null) {
        // Item exists, merge quantities
        final mergedQuantity = existingItem.itemCount + newQuantity;
        
        final updatedItem = Stocks(
          id: existingItem.id,
          itemName: existingItem.itemName,
          itemCount: mergedQuantity,
          itemDate: _selectedDate,
          description: existingItem.description,
          stockPrice: _parsePrice(_stockPriceController.text) ?? existingItem.stockPrice,
          sellPrice: _parsePrice(_sellPriceController.text) ?? existingItem.sellPrice,
          unit: _unitController.value ?? existingItem.unit,
          barcode: widget.barcode,
          lowStockThreshold: _lowStockThresholdController.text.trim().isEmpty 
              ? existingItem.lowStockThreshold 
              : int.tryParse(_lowStockThresholdController.text.trim()),
          createdAt: existingItem.createdAt,
        );
        
        await _firebaseService.updateStock(existingItem.id!, updatedItem);
        widget.onItemSaved?.call(updatedItem);
        
        if (mounted) {
          Navigator.pop(context, true);
          showFToast(
            context: context,
            style: .delta(padding: EdgeInsets.all(16)),
            icon: const Icon(FIcons.check, color: Colors.blue),
            title: const Text('Quantity Updated'),
            description: Text('Quantity updated: ${existingItem.itemCount} → $mergedQuantity'),
            suffixBuilder: (context, entry) =>
                GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
            alignment: .topCenter,
            duration: const Duration(seconds: 3),
          );
        }
      } else {
        // Create new item
        final newItem = Stocks(
          id: null,
          itemName: itemName,
          itemCount: newQuantity,
          itemDate: _selectedDate,
          description: null,
          stockPrice: _parsePrice(_stockPriceController.text),
          sellPrice: _parsePrice(_sellPriceController.text),
          unit: _unitController.value,
          barcode: widget.barcode,
          lowStockThreshold: _lowStockThresholdController.text.trim().isEmpty 
              ? null 
              : int.tryParse(_lowStockThresholdController.text.trim()),
          createdAt: DateTime.now(),
        );
        
        await _firebaseService.addStock(newItem);
        widget.onItemSaved?.call(newItem);
        
        if (mounted) {
          Navigator.pop(context, true);
          showFToast(
            context: context,
            style: .delta(padding: EdgeInsets.all(16)),
            icon: const Icon(FIcons.check, color: Colors.green),
            title: const Text('Success'),
            description: const Text('Item added successfully!'),
            suffixBuilder: (context, entry) =>
                GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
            alignment: .topCenter,
            duration: const Duration(seconds: 3),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          style: .delta(padding: EdgeInsets.all(16)),
          icon: const Icon(FIcons.circleAlert, color: Colors.red),
          title: const Text('Error'),
          description: Text('Error saving item: $e'),
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
    return FDialog(
      title: const Text('Add New Item'),
      body: Material(
        color: Colors.transparent,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              // Show barcode
              FTextField(
                control: .managed(
                  controller: TextEditingController(text: widget.barcode),
                  onChange: (_) {},
                ),
                label: const Text('Barcode'),
                hint: 'Scanned barcode',
                enabled: false,
              ),
              const SizedBox(height: 16),
              
              // Item Name
              FTextField(
                control: .managed(
                  controller: _itemNameController,
                  onChange: (value) {
                    _itemNameController.value = value;
                  },
                ),
                label: const Text('Item Name *'),
                hint: 'Enter item name',
              ),
              const SizedBox(height: 16),
              
              // Quantity and Unit
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: FTextField(
                      control: .managed(
                        controller: _quantityController,
                        onChange: (value) {
                          _quantityController.value = value;
                        },
                      ),
                      label: const Text('Quantity *'),
                      hint: 'Enter quantity',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FSelect<String>.rich(
                      control: .managed(
                        controller: _unitController,
                        onChange: (value) {
                          _unitController.value = value;
                        },
                      ),
                      hint: 'Unit',
                      format: (value) => value,
                      children: [
                        for (final unit in _units)
                          FSelectItem(
                            title: Text(unit),
                            value: unit,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Item Date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Item Date *',
                    prefixIcon: Icon(Icons.calendar_today, size: 20),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Stock Price
              FTextField(
                control: .managed(
                  controller: _stockPriceController,
                  onChange: (value) {
                    _stockPriceController.value = value;
                  },
                ),
                label: const Text('Stock Price (Optional)'),
                hint: 'Enter stock price',
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
              ),
              const SizedBox(height: 16),
              
              // Sell Price
              FTextField(
                control: .managed(
                  controller: _sellPriceController,
                  onChange: (value) {
                    _sellPriceController.value = value;
                  },
                ),
                label: const Text('Sell Price (Optional)'),
                hint: 'Enter sell price',
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsSeparatorInputFormatter()],
              ),
              const SizedBox(height: 16),
              
              // Low Stock Threshold
              FTextField(
                control: .managed(
                  controller: _lowStockThresholdController,
                  onChange: (value) {
                    _lowStockThresholdController.value = value;
                  },
                ),
                label: const Text('Low Stock Threshold (Optional)'),
                hint: 'Alert when stock is low',
                keyboardType: TextInputType.number,
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
          onPress: _isLoading ? null : _saveItem,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Item'),
        ),
      ],
    );
  }
}
