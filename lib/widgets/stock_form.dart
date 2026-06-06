import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:rollogames/models/stocks.dart';
import 'package:rollogames/services/firebase_service.dart';
import 'package:rollogames/utils/input_formatters.dart';

final FirebaseService _firebaseService = FirebaseService();

class StockFormContent extends StatefulWidget {
  final Stocks? stock;
  final Function(Stocks)? onStockSaved;
  final VoidCallback? onStockDeleted;
  final FPersistentSheetController controller;

  const StockFormContent({
    super.key,
    this.stock,
    this.onStockSaved,
    this.onStockDeleted,
    required this.controller,
  });

  @override
  State<StockFormContent> createState() => _StockFormContentState();
}

class _StockFormContentState extends State<StockFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _stockPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _lowStockThresholdController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _barcodeController = TextEditingController();

  late FSelectController<String> _unitController;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  final List<String> _units = ['pcs', 'kg', 'liters', 'meters', 'boxes', 'sets'];

  bool get _isEditing => widget.stock != null;

  @override
  void initState() {
    super.initState();
    _unitController = FSelectController<String>(value: 'pcs');

    if (widget.stock != null) {
      final s = widget.stock!;
      _itemNameController.text = s.itemName;
      _quantityController.text = s.itemCount.toString();
      _stockPriceController.text = _formatPrice(s.stockPrice);
      _sellPriceController.text = _formatPrice(s.sellPrice);
      _lowStockThresholdController.text = s.lowStockThreshold?.toString() ?? '';
      _categoryController.text = s.category ?? '';
      _descriptionController.text = s.description ?? '';
      _barcodeController.text = s.barcode ?? '';
      _selectedDate = s.itemDate;
      if (s.unit != null && _units.contains(s.unit)) {
        _unitController.value = s.unit;
      }
    } else {
      _quantityController.text = '1';
    }
  }

  String _formatPrice(double? price) {
    if (price == null) return '';
    return NumberFormat('#,##0', 'id_ID').format(price.toInt()).replaceAll(',', '.');
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _stockPriceController.dispose();
    _sellPriceController.dispose();
    _lowStockThresholdController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _barcodeController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  double? _parsePrice(String text) {
    if (text.trim().isEmpty) return null;
    return double.tryParse(text.replaceAll('.', ''));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    final itemName = _itemNameController.text.trim();
    if (itemName.isEmpty) {
      _showError('Nama item wajib diisi');
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity < 0) {
      _showError('Jumlah harus angka 0 atau lebih');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final stock = Stocks(
        id: widget.stock?.id,
        itemName: itemName,
        itemCount: quantity,
        itemDate: _selectedDate,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        stockPrice: _parsePrice(_stockPriceController.text),
        sellPrice: _parsePrice(_sellPriceController.text),
        unit: _unitController.value,
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        lowStockThreshold: _lowStockThresholdController.text.trim().isEmpty
            ? null
            : int.tryParse(_lowStockThresholdController.text.trim()),
        createdAt: widget.stock?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await _firebaseService.updateStock(widget.stock!.id!, stock);
      } else {
        await _firebaseService.addStock(stock);
      }

      widget.onStockSaved?.call(stock);
      if (mounted) widget.controller.hide();
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          alignment: .topCenter,
          icon: const Icon(FIcons.circleAlert, color: Colors.red),
          title: const Text('Error'),
          description: Text('Gagal menyimpan: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    showFToast(
      context: context,
      alignment: .topCenter,
      icon: const Icon(FIcons.triangleAlert, color: Colors.orange),
      title: const Text('Periksa data'),
      description: Text(message),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Hapus Item'),
        body: Text('Yakin ingin menghapus "${widget.stock!.itemName}"?'),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context, false),
            variant: .outline,
            child: const Text('Batal'),
          ),
          FButton(
            onPress: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _firebaseService.deleteStock(widget.stock!.id!);
      widget.onStockDeleted?.call();
      if (mounted) widget.controller.hide();
    } catch (e) {
      if (mounted) {
        showFToast(
          context: context,
          alignment: .topCenter,
          icon: const Icon(FIcons.circleAlert, color: Colors.red),
          title: const Text('Error'),
          description: Text('Gagal menghapus: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: context.theme.colors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Item' : 'Tambah Item',
                    style: context.theme.typography.xl2.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => widget.controller.hide(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FTextField(
                        control: .managed(
                          controller: _itemNameController,
                          onChange: (v) => _itemNameController.value = v,
                        ),
                        label: const Text('Nama Item *'),
                        hint: 'Masukkan nama item',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: FTextField(
                              control: .managed(
                                controller: _quantityController,
                                onChange: (v) => _quantityController.value = v,
                              ),
                              label: const Text('Jumlah *'),
                              hint: '0',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FSelect<String>.rich(
                              control: .managed(
                                controller: _unitController,
                                onChange: (v) => _unitController.value = v,
                              ),
                              hint: 'Satuan',
                              format: (v) => v,
                              children: [
                                for (final unit in _units)
                                  FSelectItem(title: Text(unit), value: unit),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tanggal *',
                            prefixIcon: Icon(Icons.calendar_today, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        control: .managed(
                          controller: _categoryController,
                          onChange: (v) => _categoryController.value = v,
                        ),
                        label: const Text('Kategori'),
                        hint: 'Contoh: Makanan, Elektronik',
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        control: .managed(
                          controller: _descriptionController,
                          onChange: (v) => _descriptionController.value = v,
                        ),
                        label: const Text('Deskripsi'),
                        hint: 'Catatan tambahan',
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        control: .managed(
                          controller: _barcodeController,
                          onChange: (v) => _barcodeController.value = v,
                        ),
                        label: const Text('Barcode'),
                        hint: 'Opsional',
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        control: .managed(
                          controller: _stockPriceController,
                          onChange: (v) => _stockPriceController.value = v,
                        ),
                        label: const Text('Harga Modal'),
                        hint: 'Harga beli',
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsSeparatorInputFormatter()],
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        control: .managed(
                          controller: _sellPriceController,
                          onChange: (v) => _sellPriceController.value = v,
                        ),
                        label: const Text('Harga Jual'),
                        hint: 'Harga jual',
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsSeparatorInputFormatter()],
                      ),
                      const SizedBox(height: 16),
                      FTextField(
                        control: .managed(
                          controller: _lowStockThresholdController,
                          onChange: (v) => _lowStockThresholdController.value = v,
                        ),
                        label: const Text('Batas Stok Rendah'),
                        hint: 'Default: 10',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.theme.colors.border)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FButton(
                      onPress: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditing ? 'Simpan Perubahan' : 'Tambah Item'),
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FButton(
                        onPress: _isLoading ? null : _delete,
                        variant: .destructive,
                        child: const Text('Hapus Item'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FButton(
                      onPress: () => widget.controller.hide(),
                      variant: .outline,
                      child: const Text('Batal'),
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

void showStockFormSheet(
  BuildContext context, {
  Stocks? stock,
  Function(Stocks)? onStockSaved,
  VoidCallback? onStockDeleted,
}) {
  // ignore: unused_result
  showFPersistentSheet(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    mainAxisMaxRatio: 0.92,
    resizeToAvoidBottomInset: true,
    builder: (context, controller) => StockFormContent(
      stock: stock,
      onStockSaved: onStockSaved,
      onStockDeleted: onStockDeleted,
      controller: controller,
    ),
  );
}
