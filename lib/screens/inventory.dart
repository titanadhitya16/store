import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gap/gap.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:storehsk/utils/currency_formatter.dart';
import 'package:storehsk/widgets/quick_sell_dialog.dart';
import 'package:storehsk/widgets/stock_form.dart';

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
    return FScaffold(
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

          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = snapshot.data ?? [];
          final filtered = _applyFilters(allItems);
          final totalQty =
              allItems.fold<int>(0, (sum, s) => sum + s.itemCount);
          final lowCount = allItems.where((s) => s.isLowStock).length;
          final outCount = allItems.where((s) => s.isOutOfStock).length;
          final totalValue = allItems.fold<double>(0, (sum, s) {
            if (s.stockPrice != null) {
              return sum + s.stockPrice! * s.itemCount;
            }
            return sum;
          });

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '$totalQty unit • ${allItems.length} item',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Gap(12)),
              SliverToBoxAdapter(
                child: _buildSummaryRow(
                  allItems.length,
                  lowCount,
                  outCount,
                  totalValue,
                ),
              ),
              const SliverToBoxAdapter(child: Gap(12)),
              SliverToBoxAdapter(
                child: Padding(
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
              ),
              const SliverToBoxAdapter(child: Gap(12)),
              SliverToBoxAdapter(child: _buildFilterChips()),
              const SliverToBoxAdapter(child: Gap(8)),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(allItems.isEmpty),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildStockCard(filtered[index]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
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
          _summaryChip(
            'Stok Rendah',
            '$low',
            FIcons.triangleAlert,
            Colors.orange,
          ),
          const Gap(8),
          _summaryChip(
            'Habis',
            '$out',
            Icons.remove_circle_outline,
            Colors.red,
          ),
          const Gap(8),
          _summaryChip(
            'Nilai Stok',
            formatRupiah(value),
            FIcons.wallet,
            Colors.green,
          ),
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
    final selected = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openEditForm(stock),
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
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  FButton(
                    variant: .ghost,
                    onPress: () => _showItemActions(stock),
                    child: const Icon(FIcons.ellipsis, size: 18),
                  ),
                ],
              ),
              const Gap(10),
              GestureDetector(
                onTap: () => _openEditForm(stock),
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
      ),
    );
  }

  void _showItemActions(Stocks stock) {
    showFPersistentSheet(
      context: context,
      side: FLayout.btt,
      useSafeArea: true,
      mainAxisMaxRatio: 0.35,
      builder: (context, controller) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stock.itemName,
              style: context.theme.typography.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(16),
            FButton(
              onPress: () {
                controller.hide();
                _openEditForm(stock);
              },
              child: const Text('Edit'),
            ),
            const Gap(8),
            FButton(
              onPress: () {
                controller.hide();
                if (stock.itemCount > 0 &&
                    stock.sellPrice != null &&
                    stock.stockPrice != null) {
                  showQuickSellDialog(context, item: stock);
                } else {
                  _showToast('Harga belum lengkap atau stok habis');
                }
              },
              child: const Text('Jual'),
            ),
            const Gap(8),
            FButton(
              onPress: () {
                controller.hide();
                _confirmDelete(stock);
              },
              variant: .destructive,
              child: const Text('Hapus'),
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
