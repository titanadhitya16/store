import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:intl/intl.dart';

final FirebaseService _firebaseService = FirebaseService();

class ItemFormContent extends StatefulWidget {
  final Stocks? item;
  final String? initialItemName;
  final Function(Stocks)? onItemSaved;
  final VoidCallback? onItemDeleted;
  final FPersistentSheetController controller;

  const ItemFormContent({
    super.key,
    this.item,
    this.initialItemName,
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
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  
  late FSelectController<String> _categoryController;
  late FSelectController<String> _unitController;
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  
  final List<String> _categories = [
    'General',
    'Electronics',
    'Clothing',
    'Food & Beverage',
    'Books',
    'Home & Garden',
    'Sports',
    'Health & Beauty',
  ];

  final List<String> _units = [
    'pcs',
    'kg',
    'lbs',
    'liters',
    'meters',
    'boxes',
    'sets',
    'dozens',
  ];

  @override
  void initState() {
    super.initState();
    _categoryController = FSelectController<String>();
    _unitController = FSelectController<String>();
    
    if (widget.item != null) {
      _populateForm(widget.item!);
    } else if (widget.initialItemName != null) {
      _itemNameController.text = widget.initialItemName!;
    }
  }

  void _populateForm(Stocks item) {
    _itemNameController.text = item.itemName;
    _quantityController.text = item.itemCount.toString();
    _selectedDate = item.itemDate;
    _descriptionController.text = item.description ?? '';
    _priceController.text = item.price?.toString() ?? '';
    if (item.category != null) {
      _categoryController.value = item.category;
    }
    if (item.unit != null) {
      _unitController.value = item.unit;
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_itemNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an item name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create new item
      final newItem = Stocks(
        id: widget.item?.id,
        itemName: _itemNameController.text.trim(),
        itemCount: int.parse(_quantityController.text.trim()),
        itemDate: _selectedDate,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        category: _categoryController.value,
        price: _priceController.text.trim().isNotEmpty 
            ? double.parse(_priceController.text.trim()) 
            : null,
        unit: _unitController.value,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
      );

      // Save to Firebase
      if (widget.item == null) {
        await _firebaseService.addStock(newItem);
      } else {
        await _firebaseService.updateStock(widget.item!.id!, newItem);
      }

      widget.onItemSaved?.call(newItem);
      
      if (mounted) {
        widget.controller.hide();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item == null ? 'Item added successfully!' : 'Item updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving item: $e'),
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

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.item?.id != null) {
      try {
        await _firebaseService.deleteStock(widget.item!.id!);
        widget.onItemDeleted?.call();
        if (mounted) {
          widget.controller.hide();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item deleted successfully!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    final isEditing = widget.item != null;
    
    return Material(
      child: Column(
        children: [
          // Custom header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditing ? 'Edit Item' : 'Add New Item',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isEditing)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteItem,
                  ),
              ],
            ),
          ),
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
                      label: 'Item Name *',
                      controller: _itemNameController,
                      hint: 'Enter item name',
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Item name is required';
                        return null;
                      },
                      prefixIcon: Icons.inventory,
                    ),
                    const SizedBox(height: 16),

                    // Item Date (Required)
                    _buildDateField(),
                    const SizedBox(height: 16),

                    // Description
                    _buildTextField(
                      label: 'Description',
                      controller: _descriptionController,
                      hint: 'Enter item description (optional)',
                      maxLines: 3,
                      prefixIcon: Icons.description,
                    ),
                    const SizedBox(height: 16),

                    // Quantity and Unit
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            label: 'Quantity *',
                            controller: _quantityController,
                            hint: '0',
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value?.isEmpty == true) return 'Quantity is required';
                              if (int.tryParse(value!) == null) return 'Enter valid number';
                              if (int.parse(value) < 0) return 'Quantity cannot be negative';
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
                            items: {for (var unit in _units) unit: unit},
                            hint: 'Select unit',
                            prefixIcon: Icons.straighten,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price
                    _buildTextField(
                      label: 'Price per Unit',
                      controller: _priceController,
                      hint: '0.00',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value?.isNotEmpty == true && double.tryParse(value!) == null) {
                          return 'Enter valid price';
                        }
                        if (value?.isNotEmpty == true && double.parse(value!) < 0) {
                          return 'Price cannot be negative';
                        }
                        return null;
                      },
                      prefixIcon: Icons.attach_money,
                    ),
                    const SizedBox(height: 16),

                    // Category
                    _buildSelect(
                      label: 'Category',
                      controller: _categoryController,
                      items: {for (var category in _categories) category: category},
                      hint: 'Select category',
                      prefixIcon: Icons.category,
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
    required Map<String, String> items,
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
        FSelect<String>(
          expands: false,
          hint: hint,
          items: items,
          prefixBuilder: prefixIcon != null 
            ? (context, style, states) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(prefixIcon, size: 20),
              )
            : null,
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
  Function(Stocks)? onItemSaved,
  VoidCallback? onItemDeleted,
}) {
  return showFPersistentSheet(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    mainAxisMaxRatio: null,
    resizeToAvoidBottomInset: false,
    builder: (context, controller) => ItemFormContent(
      item: item,
      initialItemName: itemName,
      onItemSaved: onItemSaved,
      onItemDeleted: onItemDeleted,
      controller: controller,
    ),
  );
}