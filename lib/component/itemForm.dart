import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:storehsk/screens/storage.dart';

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
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  
  late FSelectController<String> _itemNameController;
  late FSelectController<String> _categoryController;
  late FSelectController<String> _unitController;
  
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
    _itemNameController = FSelectController<String>();
    _categoryController = FSelectController<String>();
    _unitController = FSelectController<String>();
    
    if (widget.item != null) {
      _populateForm(widget.item!);
    } else if (widget.initialItemName != null) {
      _itemNameController.value = widget.initialItemName;
    }
  }

  void _populateForm(Stocks item) {
    _itemNameController.value = item.itemName;
    _quantityController.text = item.itemCount.toString();
    // Add more fields as your Stocks model expands
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _itemNameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_itemNameController.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an item'),
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
        itemName: _itemNameController.value!,
        itemCount: int.parse(_quantityController.text.trim()),
      );

      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

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

    if (confirmed == true) {
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
                    // Item Name Picker
                    _buildSearchSelect(
                      label: 'Item Name *',
                      controller: _itemNameController,
                      items: {for (var item in inventory) item.itemName: item.itemName},
                      hint: 'Search for an item',
                      prefixIcon: Icons.inventory,
                    ),
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



  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FButton(
            style: FButtonStyle.primary(),
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
            style: FButtonStyle.outline(),
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

  Widget _buildSearchSelect({
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
        FSelect<String>.search(
          hint: hint,
          filter: (query) async {
            final lowerQuery = query.toLowerCase();
            return items.entries
                .where((entry) => entry.key.toLowerCase().contains(lowerQuery))
                .map((entry) => entry.value)
                .toList();
          },
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