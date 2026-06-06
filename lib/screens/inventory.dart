import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gap/gap.dart';
import 'package:rollogames/models/stocks.dart';
import 'package:rollogames/services/firebase_service.dart';
import 'package:rollogames/utils/currency_formatter.dart';
import 'package:rollogames/widgets/quick_sell_dialog.dart';
import 'package:rollogames/widgets/stock_form.dart';

final FirebaseService _firebaseService = FirebaseService();

enum _StockFilter { all, inStock, lowStock, outOfStock }

class Inventory extends StatefulWidget {
  const Inventory({super.key});

  @override
  State<Inventory> createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _StockFilter _filter = _StockFilter.all;
  late final Stream<List<Stocks>> _stocksStream;

  @override
  void initState() {
    super.initState();
    _stocksStream = _firebaseService.getStocksStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Stocks> _applyFilters(List<Stocks> items) {
    Iterable<Stocks> filtered = items;

    filtered = switch (_filter) {
      _StockFilter.inStock => filtered.where((s) => s.isInStock),
      _StockFilter.lowStock => filtered.where((s) => s.isLowStock),
      _StockFilter.outOfStock => filtered.where((s) => s.isOutOfStock),
      _StockFilter.all => filtered,
    };

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        return s.itemName.toLowerCase().contains(q) ||
            (s.category?.toLowerCase().contains(q) ?? false) ||
            (s.barcode?.toLowerCase().contains(q) ?? false);
      });
    }

    return filtered.toList();
  }

  void _openEditForm(Stocks stock) {
    showStockFormSheet(
      context,
      stock: stock,
      onStockSaved: (_) => _showToast('Item diperbarui'),
      onStockDeleted: () => _showToast('Item dihapus'),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    showFToast(
      context: context,
      alignment: .topCenter,
      title: Text(message),
      style: .context(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        type: MaterialType.transparency,
        child: StreamBuilder<List<Stocks>>(
          stream: _stocksStream,
          builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat inventaris.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = snapshot.data ?? [];
          final filtered = _applyFilters(allItems);
          final totalQty = allItems.fold<int>(0, (sum, s) => sum + s.itemCount);
          final lowCount = allItems.where((s) => s.isLowStock).length;
          final outCount = allItems.where((s) => s.isOutOfStock).length;
          final totalValue = allItems.fold<double>(0, (sum, s) {
            if (s.stockPrice != null) {
              return sum + s.stockPrice! * s.itemCount;
            }
            return sum;
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '$totalQty unit • ${allItems.length} item',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              const Gap(12),
              _buildSummaryRow(allItems.length, lowCount, outCount, totalValue),
              const Gap(12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau kategori...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              const Gap(12),
              _buildFilterChips(),
              const Gap(8),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState(allItems.isEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildStockCard(filtered[index]),
                      ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildSummaryRow(int total, int low, int out, double value) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _summaryChip('Total Item', '$total', FIcons.package, Colors.blue),
          const Gap(8),
          _summaryChip('Stok Rendah', '$low', FIcons.triangleAlert, Colors.orange),
          const Gap(8),
          _summaryChip('Habis', '$out', Icons.remove_circle_outline, Colors.red),
          const Gap(8),
          _summaryChip('Nilai Stok', formatRupiah(value), FIcons.wallet, Colors.green),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, IconData icon, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const Gap(8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip('Semua', _StockFilter.all),
          const Gap(8),
          _filterChip('Tersedia', _StockFilter.inStock),
          const Gap(8),
          _filterChip('Stok Rendah', _StockFilter.lowStock),
          const Gap(8),
          _filterChip('Habis', _StockFilter.outOfStock),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _StockFilter filter) {
    return FilterChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
    );
  }

  Widget _buildEmptyState(bool noItemsAtAll) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const Gap(16),
          Text(
            noItemsAtAll
                ? 'Belum ada item inventaris'
                : 'Tidak ada item yang cocok',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          if (noItemsAtAll) ...[
            const Gap(8),
            Text(
              'Tekan + untuk menambah item',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockCard(Stocks stock) {
    final statusColor = stock.isOutOfStock
        ? Colors.red
        : stock.isLowStock
            ? Colors.orange
            : Colors.green;
    final statusLabel = stock.isOutOfStock
        ? 'Habis'
        : stock.isLowStock
            ? 'Stok Rendah'
            : 'Tersedia';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openEditForm(stock),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (stock.category != null) ...[
                          const Gap(2),
                          Text(
                            stock.category!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        _openEditForm(stock);
                      case 'sell':
                        if (stock.itemCount > 0 &&
                            stock.sellPrice != null &&
                            stock.stockPrice != null) {
                          showQuickSellDialog(context, item: stock);
                        } else {
                          _showToast('Harga belum lengkap atau stok habis');
                        }
                      case 'delete':
                        _confirmDelete(stock);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'sell', child: Text('Jual')),
                    PopupMenuItem(value: 'delete', child: Text('Hapus')),
                  ],
                ),
              ],
            ),
            const Gap(10),
            InkWell(
              onTap: () => _openEditForm(stock),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  _infoChip(
                    Icons.inventory,
                    '${stock.itemCount}${stock.unit != null ? " ${stock.unit}" : ""}',
                  ),
                  if (stock.sellPrice != null) ...[
                    const Gap(12),
                    _infoChip(Icons.sell, formatRupiah(stock.sellPrice!)),
                  ],
                  if (stock.profitPerUnit != null) ...[
                    const Gap(12),
                    _infoChip(
                      Icons.trending_up,
                      '+${formatRupiah(stock.profitPerUnit!)}',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const Gap(4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Future<void> _confirmDelete(Stocks stock) async {
    final confirmed = await showFDialog<bool>(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Hapus Item'),
        body: Text('Yakin ingin menghapus "${stock.itemName}"?'),
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

    if (confirmed == true && stock.id != null) {
      await _firebaseService.deleteStock(stock.id!);
      if (mounted) _showToast('Item dihapus');
    }
  }
}
