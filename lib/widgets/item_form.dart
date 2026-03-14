import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/stocks.dart';
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

    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      return const TextEditingValue();
    }

    // Parse and format
    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    // Format with dots as thousand separators
    final formatted = _formatter.format(number).replaceAll(',', '.');

    // Calculate new cursor position
    int cursorPosition = formatted.length;
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

class ItemFormContent extends StatefulWidget {
  final Stocks? item;
  final String? initialItemName;
  final String? initialBarcode;
  final Function(Stocks)? onItemSaved;
  final VoidCallback? onItemDeleted;
  final FPersistentSheetController controller;

  const ItemFormContent({
    super.key,
    this.item,
    this.initialItemName,
    this.initialBarcode,
    this.onItemSaved,
    this.onItemDeleted,
    required this.controller,
  });

  @override
  State<ItemFormContent> createState() => _ItemFormContentState();
}

class _ItemFormContentState extends State<ItemFormContent> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _stockPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  final _barcodeController = TextEditingController();
  
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
    _unitController = FSelectController<String>();
    
    if (widget.item != null) {
      _populateForm(widget.item!);
    } else {
      if (widget.initialItemName != null) {
        _itemNameController.text = widget.initialItemName!;
      }
      if (widget.initialBarcode != null) {
        _barcodeController.text = widget.initialBarcode!;
      }
    }
  }

  void _populateForm(Stocks item) {
    _itemNameController.text = item.itemName;
    _quantityController.text = item.itemCount.toString();
    _selectedDate = item.itemDate;
    
    // Format prices with thousand separators
    if (item.stockPrice != null) {
      final formatted = NumberFormat('#,##0', 'id_ID').format(item.stockPrice!.toInt());
      _stockPriceController.text = formatted.replaceAll(',', '.');
    }
    if (item.sellPrice != null) {
      final formatted = NumberFormat('#,##0', 'id_ID').format(item.sellPrice!.toInt());
      _sellPriceController.text = formatted.replaceAll(',', '.');
    }
    
    if (item.lowStockThreshold != null) {
      _lowStockThresholdController.text = item.lowStockThreshold.toString();
    }
    
    if (item.unit != null) {
      _unitController.value = item.unit;
    }
    
    if (item.barcode != null) {
      _barcodeController.text = item.barcode!;
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _stockPriceController.dispose();
    _sellPriceController.dispose();
    _lowStockThresholdController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  double? _parsePrice(String text) {
    if (text.trim().isEmpty) return null;
    // Remove dots (thousand separators) and parse
    final digitsOnly = text.replaceAll('.', '');
    return double.tryParse(digitsOnly);
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_itemNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nama item terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final itemName = _itemNameController.text.trim();
      final newQuantity = int.parse(_quantityController.text.trim());
      
      // If editing an existing item, just update it normally
      if (widget.item != null) {
        final lowStockValue = _lowStockThresholdController.text.trim().isEmpty ? null : int.tryParse(_lowStockThresholdController.text.trim());
        final updatedItem = Stocks(
          id: widget.item!.id,
          itemName: itemName,
          itemCount: newQuantity,
          itemDate: _selectedDate,
          description: widget.item!.description,
          stockPrice: _parsePrice(_stockPriceController.text),
          sellPrice: _parsePrice(_sellPriceController.text),
          unit: _unitController.value,
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          lowStockThreshold: lowStockValue,
          createdAt: widget.item!.createdAt,
        );
        
        
        await _firebaseService.updateStock(widget.item!.id!, updatedItem);
        widget.onItemSaved?.call(updatedItem);
        
        if (mounted) {
          widget.controller.hide();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item berhasil diperbarui!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
      
      // For new items, check if an item with the same name already exists
      final existingItem = await _firebaseService.findStockByExactName(itemName);
      
      if (existingItem != null) {
        // Item exists, merge quantities
        final mergedQuantity = existingItem.itemCount + newQuantity;
        
        if (mergedQuantity < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tidak dapat mengurangi item melebihi jumlah yang ada'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        final lowStockValue = _lowStockThresholdController.text.trim().isEmpty 
            ? existingItem.lowStockThreshold 
            : int.tryParse(_lowStockThresholdController.text.trim());
        
        final updatedItem = Stocks(
          id: existingItem.id,
          itemName: existingItem.itemName,
          itemCount: mergedQuantity,
          itemDate: _selectedDate,
          description: existingItem.description,
          stockPrice: _parsePrice(_stockPriceController.text) ?? existingItem.stockPrice,
          sellPrice: _parsePrice(_sellPriceController.text) ?? existingItem.sellPrice,
          unit: _unitController.value ?? existingItem.unit,
          barcode: _barcodeController.text.trim().isEmpty ? existingItem.barcode : _barcodeController.text.trim(),
          lowStockThreshold: lowStockValue,
          createdAt: existingItem.createdAt,
        );
        
        await _firebaseService.updateStock(existingItem.id!, updatedItem);
        widget.onItemSaved?.call(updatedItem);
        
        if (mounted) {
          widget.controller.hide();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kuantitas diperbarui: ${existingItem.itemCount} → $mergedQuantity'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        // Item doesn't exist, add as new
        if (newQuantity < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tidak dapat menambahkan item dengan kuantitas negatif'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        final lowStockValue = _lowStockThresholdController.text.trim().isEmpty ? null : int.tryParse(_lowStockThresholdController.text.trim());
        
        final newItem = Stocks(
          id: null,
          itemName: itemName,
          itemCount: newQuantity,
          itemDate: _selectedDate,
          description: null,
          stockPrice: _parsePrice(_stockPriceController.text),
          sellPrice: _parsePrice(_sellPriceController.text),
          unit: _unitController.value,
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
          lowStockThreshold: lowStockValue,
          createdAt: DateTime.now(),
        );
        
        await _firebaseService.addStock(newItem);
        widget.onItemSaved?.call(newItem);
        
        if (mounted) {
          widget.controller.hide();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item berhasil ditambahkan!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error menyimpan item: $e'),
            backgroundColor: Colors.red,
          ),
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
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item Name
                    _buildTextField(
                      label: 'Nama Item *',
                      controller: _itemNameController,
                      hint: 'Masukkan nama item',
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Nama item diperlukan';
                        return null;
                      },
                      prefixIcon: Icons.inventory,
                    ),
                    const SizedBox(height: 16),

                    // Barcode
                    _buildTextField(
                      label: 'Barcode',
                      controller: _barcodeController,
                      hint: 'Masukkan atau pindai barcode',
                      prefixIcon: Icons.qr_code,
                    ),
                    const SizedBox(height: 16),

                    // Item Date (Required)
                    _buildDateField(),
                    const SizedBox(height: 16),

                    // Quantity and Unit
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            label: 'Jumlah *',
                            controller: _quantityController,
                            hint: '0',
                            keyboardType: const TextInputType.numberWithOptions(signed: true),
                            validator: (value) {
                              if (value?.isEmpty == true) return 'Jumlah diperlukan';
                              if (int.tryParse(value!) == null) return 'Masukkan angka yang valid';
                              return null;
                            },
                            prefixIcon: Icons.numbers,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelect(
                            label: 'Unit',
                            controller: _unitController,
                            items: _units,
                            hint: 'Pilih unit',
                            prefixIcon: Icons.straighten,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Stock Price and Sell Price
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'Harga Stok (Biaya)',
                            controller: _stockPriceController,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsSeparatorInputFormatter()],
                            validator: (value) {
                              if (value?.isNotEmpty == true) {
                                final price = _parsePrice(value!);
                                if (price == null) return 'Masukkan harga yang valid';
                                if (price < 0) return 'Harga tidak boleh negatif';
                              }
                              return null;
                            },
                            prefixIcon: Icons.shopping_cart,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Harga Jual',
                            controller: _sellPriceController,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsSeparatorInputFormatter()],
                            validator: (value) {
                              if (value?.isNotEmpty == true) {
                                final price = _parsePrice(value!);
                                if (price == null) return 'Masukkan harga yang valid';
                                if (price < 0) return 'Harga tidak boleh negatif';
                              }
                              return null;
                            },
                            prefixIcon: Icons.attach_money,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Low Stock Threshold
                    _buildTextField(
                      label: 'Batas Stok Rendah',
                      controller: _lowStockThresholdController,
                      hint: 'Masukkan jumlah threshold untuk peringatan stok rendah',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isNotEmpty == true) {
                          final threshold = int.tryParse(value!);
                          if (threshold == null) return 'Masukkan angka yang valid';
                          if (threshold < 0) return 'Threshold tidak boleh negatif';
                        }
                        return null;
                      },
                      prefixIcon: Icons.warning_amber,
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item Date *',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FButton(
            onPress: _isLoading ? null : _saveItem,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.item == null ? 'Add Item' : 'Update Item'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FButton(
            onPress: () => widget.controller.hide(),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    IconData? prefixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSelect({
    required String label,
    required FSelectController<String> controller,
    required List<String> items,
    required String hint,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        FSelect<String>.rich(
          control: .managed(
            controller: controller,
            onChange: (value) {
              controller.value = value;
            },
          ),
          hint: hint,
          format: (value) => value,
          children: [
            for (final item in items)
              FSelectItem(
                title: Row(
                  children: [
                    if (prefixIcon != null) ...[
                      Icon(prefixIcon, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(item),
                  ],
                ),
                value: item,
              ),
          ],
        ),
      ],
    );
  }
}

// Helper function to show the item form sheet
FPersistentSheetController showItemFormSheet(
  BuildContext context, {
  Stocks? item,
  String? itemName,
  String? barcode,
  Function(Stocks)? onItemSaved,
  VoidCallback? onItemDeleted,
}) {
  return showFPersistentSheet(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    mainAxisMaxRatio: 0.9,
    resizeToAvoidBottomInset: true,
    builder: (context, controller) => ItemFormContent(
      item: item,
      initialItemName: itemName,
      initialBarcode: barcode,
      onItemSaved: onItemSaved,
      onItemDeleted: onItemDeleted,
      controller: controller,
    ),
  );
}