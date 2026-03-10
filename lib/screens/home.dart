import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gap/gap.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:storehsk/services/sales_service.dart';
import 'package:storehsk/models/sale.dart';
import 'package:storehsk/utils/currency_formatter.dart';

final FirebaseService _firebaseService = FirebaseService();
final SalesService _salesService = SalesService();

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime? selectedDate = DateTime.now();

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: StreamBuilder(
        stream: _firebaseService.getStocksStream(),
        builder: (context, inventorySnapshot) {
          final inventory = inventorySnapshot.data ?? [];
          final lowStock = inventory.where((item) => item.isLowStock).length;
          final outOfStock = inventory.where((item) => item.isOutOfStock).length;
          
          return StreamBuilder<List<Sale>>(
            stream: _salesService.getSalesByDate(selectedDate ?? DateTime.now()),
            builder: (context, salesSnapshot) {
              final sales = salesSnapshot.data ?? [];
              
              // Calculate metrics from real sales data
              double actualProfit = 0.0;
              int itemsSold = 0;
              double totalRevenue = 0.0;
              double totalCost = 0.0;
              
              for (var sale in sales) {
                actualProfit += sale.profit;
                itemsSold += sale.quantitySold;
                totalRevenue += sale.sellPrice * sale.quantitySold;
                totalCost += sale.stockPrice * sale.quantitySold;
              }
              
              final profitMargin = totalRevenue > 0 ? (actualProfit / totalRevenue) * 100 : 0.0;

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dashboard',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            '${_getGreeting()} • ${_formatDate(selectedDate ?? DateTime.now())}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),

                    // Calendar
                    _buildCalendarCard(),

                    FDivider(axis: Axis.horizontal,),

                    const Gap(16),

                    // Profit Overview
                    _buildProfitOverview(actualProfit, profitMargin, itemsSold, inventory.length, totalRevenue),

                    const Gap(16),

                    // Quick Insights
                    _buildQuickInsights(lowStock, outOfStock),

                    const Gap(16),

                    // Recent Activity (Sales)
                    _buildRecentActivity(sales),

                    const Gap(80), // Space for bottom nav
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCalendarCard() {
    return FLineCalendar(
          control: FLineCalendarControl.managed(
            initial: selectedDate,
            onChange: (DateTime? newDate) {
              setState(() {
                selectedDate = newDate;
              });
            },
          ),
    );
  }

  Widget _buildProfitOverview(double actualProfit, double profitMargin, int itemsSold, int totalItems, double totalRevenue) {
    final profitColor = actualProfit >= 0 ? Colors.green : Colors.red;
    final formattedProfit = formatRupiah(actualProfit);
    final formattedMargin = profitMargin.toStringAsFixed(1);
    final formattedRevenue = formatRupiah(totalRevenue);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing based on screen width
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth < 420;
        
        // Adjust sizes based on screen width
        final iconSize = isSmallScreen ? 24.0 : 28.0;
        final profitFontSize = isSmallScreen ? 24.0 : isMediumScreen ? 28.0 : 32.0;
        final labelFontSize = isSmallScreen ? 11.0 : 13.0;
        final metricFontSize = isSmallScreen ? 18.0 : 22.0;
        final padding = isSmallScreen ? 12.0 : 16.0;
        final cardPadding = isSmallScreen ? 12.0 : 20.0;

        return FCard(
          title: const Text('Laporan Penjualan'),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              children: [
                // Total Sales Display
                Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 12.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.monetization_on,
                          color: Colors.blue,
                          size: iconSize,
                        ),
                      ),
                      Gap(isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Terjual',
                              style: TextStyle(
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Gap(4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formattedRevenue,
                                style: TextStyle(
                                  fontSize: profitFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                // Main Profit Display
                Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: actualProfit >= 0
                          ? [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)]
                          : [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: profitColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 12.0),
                        decoration: BoxDecoration(
                          color: profitColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          actualProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                          color: profitColor,
                          size: iconSize,
                        ),
                      ),
                      Gap(isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Untung Bersih',
                              style: TextStyle(
                                fontSize: labelFontSize,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Gap(4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formattedProfit,
                                style: TextStyle(
                                  fontSize: profitFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: profitColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                    ),
                const Gap(20),
                // Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(padding),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.percent_rounded,
                              color: Colors.blue,
                              size: iconSize,
                            ),
                            const Gap(8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formattedMargin,
                                style: TextStyle(
                                  fontSize: metricFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const Gap(4),
                            Text(
                              'Avg. Margin',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10.0 : 11.0,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(padding),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              color: Colors.purple,
                              size: iconSize,
                            ),
                            const Gap(8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$itemsSold',
                                style: TextStyle(
                                  fontSize: metricFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                            const Gap(4),
                            Text(
                              'Terjual',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10.0 : 11.0,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickInsights(int lowStock, int outOfStock) {
    return FCard(
      title: const Text('Kondisi Stok'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (outOfStock > 0)
              _buildInsightRow(
                Icons.error,
                'Critical',
                '$outOfStock barang habis stok',
                Colors.red,
              ),
            if (lowStock > 0) ...[
              if (outOfStock > 0) const Gap(12),
              _buildInsightRow(
                Icons.warning_amber,
                'Warning',
                '$lowStock barang hampir habis stok',
                Colors.orange,
              ),
            ],
            if (outOfStock == 0 && lowStock == 0)
              _buildInsightRow(
                Icons.check_circle,
                'Stok Terpenuhi',
                'Semua stok dalam kondisi baik',
                Colors.green,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(List<Sale> sales) {
    if (sales.isEmpty) {
      return FCard(
        title: const Text('Penjualan Terkini'),
        subtitle: const Text('Penjualan untuk tanggal terpilih'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No sales for this date',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FCard(
      title: const Text('Penjualan Terkini'),
      subtitle: Text('${sales.length} penjualan untuk ${_formatDate(selectedDate ?? DateTime.now())}'),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: sales.map((sale) {
            final profitColor = sale.profit >= 0 ? Colors.green : Colors.red;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: profitColor.withOpacity(0.1),
                    child: Icon(
                      Icons.shopping_cart,
                      color: profitColor,
                      size: 20,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.itemName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          'Qty: ${sale.quantitySold} • Untung: ${formatRupiah(sale.profit)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatRupiah(sale.sellPrice * sale.quantitySold),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Pendapatan',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}