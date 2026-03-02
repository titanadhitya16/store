import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gap/gap.dart';
import 'package:storehsk/services/firebase_service.dart';

final FirebaseService _firebaseService = FirebaseService();

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime? selectedDate = DateTime.now();

  // Sample data - in real app, this would come from a database/API
  // Date-specific data structure
  final Map<String, Map<String, dynamic>> dailyData = {
    '2026-02-12': {
      'sales': [12.5, 18.3, 14.7, 22.1, 19.8, 25.4, 21.0],
      'revenue': 133.3,
      'activities': [
        {'icon': Icons.add_box, 'title': 'New item added', 'subtitle': 'Product A • 2h ago', 'color': Colors.green},
        {'icon': Icons.shopping_cart, 'title': 'Sale completed', 'subtitle': 'Product B • 3h ago', 'color': Colors.blue},
        {'icon': Icons.warning, 'title': 'Low stock alert', 'subtitle': 'Product C • 5h ago', 'color': Colors.orange},
      ],
    },
    '2026-02-11': {
      'sales': [10.2, 15.5, 12.8, 19.3, 17.5, 22.1, 18.6],
      'revenue': 116.0,
      'activities': [
        {'icon': Icons.update, 'title': 'Stock updated', 'subtitle': 'Product D • 1d ago', 'color': Colors.blue},
        {'icon': Icons.local_shipping, 'title': 'Delivery received', 'subtitle': 'Product E • 1d ago', 'color': Colors.green},
      ],
    },
    '2026-02-10': {
      'sales': [14.1, 16.7, 13.2, 20.5, 18.9, 24.3, 19.8],
      'revenue': 127.5,
      'activities': [
        {'icon': Icons.inventory, 'title': 'Inventory check', 'subtitle': 'Product F • 2d ago', 'color': Colors.blue},
        {'icon': Icons.trending_up, 'title': 'High demand alert', 'subtitle': 'Product G • 2d ago', 'color': Colors.green},
      ],
    },
  };
  
  final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Get data for selected date
  List<double> get selectedDateSales {
    final dateKey = _formatDateKey(selectedDate ?? DateTime.now());
    return dailyData[dateKey]?['sales'] ?? [12.5, 18.3, 14.7, 22.1, 19.8, 25.4, 21.0];
  }

  double get selectedDateRevenue {
    final dateKey = _formatDateKey(selectedDate ?? DateTime.now());
    return dailyData[dateKey]?['revenue'] ?? 133.3;
  }

  List<Map<String, dynamic>> get selectedDateActivities {
    final dateKey = _formatDateKey(selectedDate ?? DateTime.now());
    return dailyData[dateKey]?['activities'] ?? [];
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: StreamBuilder(
        stream: _firebaseService.getStocksStream(),
        builder: (context, snapshot) {
          final inventory = snapshot.data ?? [];
          final lowStock = inventory.where((item) => item.itemCount > 0 && item.itemCount < 10).length;
          final outOfStock = inventory.where((item) => item.itemCount == 0).length;
          
          // Calculate profit metrics
          double totalPotentialProfit = 0;
          double totalStockValue = 0;
          double totalSellValue = 0;
          int itemsWithPricing = 0;
          
          for (var item in inventory) {
            if (item.stockPrice != null && item.sellPrice != null && item.itemCount > 0) {
              totalPotentialProfit += (item.sellPrice! - item.stockPrice!) * item.itemCount;
              totalStockValue += item.stockPrice! * item.itemCount;
              totalSellValue += item.sellPrice! * item.itemCount;
              itemsWithPricing++;
            }
          }
          
          double averageProfitMargin = totalStockValue > 0 
              ? ((totalSellValue - totalStockValue) / totalStockValue) * 100 
              : 0;

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
                _buildProfitOverview(totalPotentialProfit, averageProfitMargin, itemsWithPricing, inventory.length),

                const Gap(16),

                // Quick Insights
                _buildQuickInsights(lowStock, outOfStock),

                const Gap(16),

                // Recent Activity
                _buildRecentActivity(),

                const Gap(16),
                
                 // Sales Trend Chart
                _buildSalesTrendCard(),

                const Gap(80), // Space for bottom nav
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalesTrendCard() {
    return FCard(
      title: const Text('Sales Trend'),
      subtitle: const Text('Last 7 days performance'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value.toInt() >= 0 && value.toInt() < weekDays.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            weekDays[value.toInt()],
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 10,
                    reservedSize: 35,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        '\$${value.toInt()}k',
                        style: const TextStyle(
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: 30,
              lineBarsData: [
                LineChartBarData(
                  spots: selectedDateSales.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value);
                  }).toList(),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.blue,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.blue.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
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

  Widget _buildProfitOverview(double totalProfit, double avgMargin, int itemsWithPricing, int totalItems) {
    final profitColor = totalProfit >= 0 ? Colors.green : Colors.red;
    final formattedProfit = totalProfit.toStringAsFixed(2);
    final formattedMargin = avgMargin.toStringAsFixed(1);

    return FCard(
      title: const Text('Profit Overview'),
      subtitle: Text('Based on $itemsWithPricing of $totalItems items'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Total Potential Profit
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: profitColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        totalProfit >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: profitColor,
                        size: 20,
                      ),
                    ),
                    const Gap(12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Potential Profit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          '\$$formattedProfit',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: profitColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Gap(16),
            const Divider(),
            const Gap(16),
            // Average Profit Margin
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'Avg. Margin',
                  '$formattedMargin%',
                  Icons.percent,
                  avgMargin >= 0 ? Colors.blue : Colors.red,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.withOpacity(0.3),
                ),
                _buildMetric(
                  'Items Tracked',
                  '$itemsWithPricing',
                  Icons.inventory_2,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const Gap(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const Gap(2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickInsights(int lowStock, int outOfStock) {
    return FCard(
      title: const Text('Quick Insights'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (outOfStock > 0)
              _buildInsightRow(
                Icons.error,
                'Critical',
                '$outOfStock items are out of stock',
                Colors.red,
              ),
            if (lowStock > 0) ...[
              if (outOfStock > 0) const Gap(12),
              _buildInsightRow(
                Icons.warning_amber,
                'Warning',
                '$lowStock items running low on stock',
                Colors.orange,
              ),
            ],
            if (outOfStock == 0 && lowStock == 0)
              _buildInsightRow(
                Icons.check_circle,
                'All Good',
                'All inventory levels are healthy',
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

  Widget _buildRecentActivity() {
    final activities = selectedDateActivities.isNotEmpty 
      ? selectedDateActivities 
      : [
          {'icon': Icons.info, 'title': 'No activity', 'subtitle': 'No records for this date', 'color': Colors.grey},
        ];

    return FCard(
      title: const Text('Recent Activity'),
      subtitle: const Text('Latest updates'),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: activities.map((activity) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (activity['color'] as Color).withOpacity(0.1),
                    child: Icon(
                      activity['icon'] as IconData,
                      color: activity['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['title'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          activity['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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