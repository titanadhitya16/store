import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/models/finance_entry.dart';
import 'package:storehsk/services/finance_service.dart';
import 'package:intl/intl.dart';

final FinanceService _financeService = FinanceService();

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
  final FinanceEntry? entry;
  final Function(FinanceEntry)? onItemSaved;
  final VoidCallback? onItemDeleted;
  final FPersistentSheetController controller;

  const ItemFormContent({
    super.key,
    this.entry,
    this.onItemSaved,
    this.onItemDeleted,
    required this.controller,
  });

  @override
  State<ItemFormContent> createState() => _ItemFormContentState();
}

class _ItemFormContentState extends State<ItemFormContent> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _uangAwalController = TextEditingController();
  final _penghasilanController = TextEditingController();
  final _pengeluaranController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _uangAwalController.dispose();
    _penghasilanController.dispose();
    _pengeluaranController.dispose();
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

    setState(() {
      _isLoading = true;
    });

    try {
      final uangAwal = _parsePrice(_uangAwalController.text) ?? 0;
      final penghasilan = _parsePrice(_penghasilanController.text) ?? 0;
      final pengeluaran = _parsePrice(_pengeluaranController.text) ?? 0;

      final labaBersihHarian = uangAwal + penghasilan - pengeluaran;
      final modalAwal = labaBersihHarian * (100 / 542);
      final bagiHasil = labaBersihHarian * (350 / 542);
      final pram = labaBersihHarian * (50 / 542);
      final tabRollo = labaBersihHarian * (70 / 542);

      final newEntry = FinanceEntry(
        date: _selectedDate,
        uangAwal: uangAwal,
        penghasilan: penghasilan,
        pengeluaran: pengeluaran,
        labaBersihHarian: labaBersihHarian,
        modalAwal: modalAwal,
        bagiHasil: bagiHasil,
        pram: pram,
        tabRollo: tabRollo,
        createdAt: DateTime.now(),
      );

      await _financeService.addFinanceEntry(newEntry);

      if (mounted) {
        widget.controller.hide();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan keuangan berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onItemSaved?.call(newEntry);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error menyimpan laporan: $e'),
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
                    // Item Date (Required)
                    _buildDateField(),
                    const SizedBox(height: 16),

                    // Uang Awal
                    _buildTextField(
                      label: 'Uang Awal',
                      controller: _uangAwalController,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      prefixIcon: Icons.account_balance_wallet,
                    ),
                    const SizedBox(height: 16),

                    // Penghasilan
                    _buildTextField(
                      label: 'Penghasilan',
                      controller: _penghasilanController,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      prefixIcon: Icons.arrow_upward,
                    ),
                    const SizedBox(height: 16),

                    // Pengeluaran
                    _buildTextField(
                      label: 'Pengeluaran',
                      controller: _pengeluaranController,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      prefixIcon: Icons.arrow_downward,
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
          'Tanggal Laporan *',
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
                : Text(widget.entry == null ? 'Add Entry' : 'Update Entry'),
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


}

// Helper function to show the item form sheet
FPersistentSheetController showItemFormSheet(
  BuildContext context, {
  FinanceEntry? entry,
  Function(FinanceEntry)? onItemSaved,
  VoidCallback? onItemDeleted,
}) {
  return showFPersistentSheet(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    mainAxisMaxRatio: 0.9,
    resizeToAvoidBottomInset: true,
    builder: (context, controller) => ItemFormContent(
      entry: entry,
      onItemSaved: onItemSaved,
      onItemDeleted: onItemDeleted,
      controller: controller,
    ),
  );
}