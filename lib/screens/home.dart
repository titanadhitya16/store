import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
  // Date-specific data structure with actual items sold
  final Map<String, Map<String, dynamic>> dailyData = {
    '2026-02-12': {
      'sales': [12.5, 18.3, 14.7, 22.1, 19.8, 25.4, 21.0],
      'itemsSoldData': [
        {'itemName': 'Spark Plug', 'quantity': 2, 'sellPrice': 2.0, 'buyPrice': 1.0},  // Profit: (2-1) * 2 = $2
        {'itemName': 'Oil Filter', 'quantity': 3, 'sellPrice': 8.0, 'buyPrice': 5.0},  // Profit: (8-5) * 3 = $9
        {'itemName': 'Air Filter', 'quantity': 4, 'sellPrice': 12.0, 'buyPrice': 8.0},  // Profit: (12-8) * 4 = $16
        {'itemName': 'Brake Pads', 'quantity': 1, 'sellPrice': 35.0, 'buyPrice': 25.0},  // Profit: (35-25) * 1 = $10
        {'itemName': 'Wiper Blades', 'quantity': 2, 'sellPrice': 6.0, 'buyPrice': 3.5},  // Profit: (6-3.5) * 2 = $5
      ],  // Total profit: $42
      'activities': [
        {'icon': Icons.add_box, 'title': 'New item added', 'subtitle': 'Product A • 2h ago', 'color': Colors.green},
        {'icon': Icons.shopping_cart, 'title': 'Sale completed', 'subtitle': 'Product B • 3h ago', 'color': Colors.blue},
        {'icon': Icons.warning, 'title': 'Low stock alert', 'subtitle': 'Product C • 5h ago', 'color': Colors.orange},
      ],
    },
    '2026-02-11': {
      'sales': [10.2, 15.5, 12.8, 19.3, 17.5, 22.1, 18.6],
      'itemsSoldData': [
        {'itemName': 'Spark Plug', 'quantity': 3, 'sellPrice': 2.0, 'buyPrice': 1.0},  // Profit: $3
        {'itemName': 'Engine Oil', 'quantity': 2, 'sellPrice': 15.0, 'buyPrice': 10.0},  // Profit: $10
        {'itemName': 'Battery', 'quantity': 1, 'sellPrice': 80.0, 'buyPrice': 60.0},  // Profit: $20
        {'itemName': 'Coolant', 'quantity': 2, 'sellPrice': 12.0, 'buyPrice': 8.0},  // Profit: $8
      ],  // Total profit: $41
      'activities': [
        {'icon': Icons.update, 'title': 'Stock updated', 'subtitle': 'Product D • 1d ago', 'color': Colors.blue},
        {'icon': Icons.local_shipping, 'title': 'Delivery received', 'subtitle': 'Product E • 1d ago', 'color': Colors.green},
      ],
    },
    '2026-02-10': {
      'sales': [14.1, 16.7, 13.2, 20.5, 18.9, 24.3, 19.8],
      'itemsSoldData': [
        {'itemName': 'Headlight Bulb', 'quantity': 4, 'sellPrice': 7.0, 'buyPrice': 4.0},  // Profit: $12
        {'itemName': 'Transmission Fluid', 'quantity': 2, 'sellPrice': 18.0, 'buyPrice': 12.0},  // Profit: $12
        {'itemName': 'Cabin Filter', 'quantity': 3, 'sellPrice': 10.0, 'buyPrice': 6.0},  // Profit: $12
        {'itemName': 'Fuse Set', 'quantity': 2, 'sellPrice': 5.0, 'buyPrice': 2.5},  // Profit: $5
      ],  // Total profit: $41
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
    final itemsSoldData = dailyData[dateKey]?['itemsSoldData'] as List<Map<String, dynamic>>?;
    
    if (itemsSoldData == null) return 0.0;
    
    double revenue = 0.0;
    for (var item in itemsSoldData) {
      revenue += (item['sellPrice'] as double) * (item['quantity'] as int);
    }
    return revenue;
  }

  double get selectedDateProfit {
    final dateKey = _formatDateKey(selectedDate ?? DateTime.now());
    final itemsSoldData = dailyData[dateKey]?['itemsSoldData'] as List<Map<String, dynamic>>?;
    
    if (itemsSoldData == null) return 0.0;
    
    double profit = 0.0;
    for (var item in itemsSoldData) {
      final sellPrice = item['sellPrice'] as double;
      final buyPrice = item['buyPrice'] as double;
      final quantity = item['quantity'] as int;
      profit += (sellPrice - buyPrice) * quantity;
    }
    return profit;
  }

  double get selectedDateProfitMargin {
    final dateKey = _formatDateKey(selectedDate ?? DateTime.now());
    final itemsSoldData = dailyData[dateKey]?['itemsSoldData'] as List<Map<String, dynamic>>?;
    
    if (itemsSoldData == null) return 0.0;
    
    double totalCost = 0.0;
    double totalRevenue = 0.0;
    
    for (var item in itemsSoldData) {
      final sellPrice = item['sellPrice'] as double;
      final buyPrice = item['buyPrice'] as double;
      final quantity = item['quantity'] as int;
      totalCost += buyPrice * quantity;
      totalRevenue += sellPrice * quantity;
    }
    
    if (totalCost == 0) return 0.0;
    return ((totalRevenue - totalCost) / totalCost) * 100;
  }

  int get selectedDateItemsSold {
    final dateKey = _formatDateKey(selectedDate ?? DateTime.now());
    final itemsSoldData = dailyData[dateKey]?['itemsSoldData'] as List<Map<String, dynamic>>?;
    
    if (itemsSoldData == null) return 0;
    
    int totalItems = 0;
    for (var item in itemsSoldData) {
      totalItems += item['quantity'] as int;
    }
    return totalItems;
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
          
          // Get actual profit metrics for selected date
          final actualProfit = selectedDateProfit;
          final profitMargin = selectedDateProfitMargin;
          final itemsSold = selectedDateItemsSold;

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
                _buildProfitOverview(actualProfit, profitMargin, itemsSold, inventory.length),

                const Gap(16),

                // Quick Insights
                _buildQuickInsights(lowStock, outOfStock),

                const Gap(16),

                // Recent Activity
                _buildRecentActivity(),

                const Gap(80), // Space for bottom nav
              ],
            ),
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

  Widget _buildProfitOverview(double actualProfit, double profitMargin, int itemsSold, int totalItems) {
    final profitColor = actualProfit >= 0 ? Colors.green : Colors.red;
    final formattedProfit = actualProfit.toStringAsFixed(2);
    final formattedMargin = profitMargin.toStringAsFixed(1);

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
          title: const Text('Profit Analytics'),
          subtitle: Text('Sales data for ${_formatDate(selectedDate ?? DateTime.now())}'),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              children: [
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
                              'Actual Profit',
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
                                '\$$formattedProfit',
                                style: TextStyle(
                                  fontSize: profitFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: profitColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const Gap(4),
                            Text(
                              'From sales on selected date',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10.0 : 11.0,
                                color: Colors.grey[500],
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
                                '$formattedMargin',
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
                              'Items Sold',
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