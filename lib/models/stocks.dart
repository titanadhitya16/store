import 'package:cloud_firestore/cloud_firestore.dart';

class Items {
  final String dayName;
  final double totalSales;

  Items({required this.dayName, required this.totalSales});
}

class Stocks {
  final String? id;
  final String itemName;
  final int itemCount;
  final DateTime itemDate;
  final String? description;
  final String? category;
  final double? stockPrice;  // Cost price (buying price)
  final double? sellPrice;   // Selling price
  final String? unit;
  final int? lowStockThreshold;  // Threshold for low stock warning
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Stocks({
    this.id,
    required this.itemName,
    required this.itemCount,
    required this.itemDate,
    this.description,
    this.category,
    this.stockPrice,
    this.sellPrice,
    this.unit,
    this.lowStockThreshold,
    this.createdAt,
    this.updatedAt,
  });

  // Convert Stocks to Firestore document
  Map<String, dynamic> toFirestore() {
    final data = {
      'itemName': itemName,
      'itemCount': itemCount,
      'itemDate': Timestamp.fromDate(itemDate),
      'description': description,
      'category': category,
      'stockPrice': stockPrice,
      'sellPrice': sellPrice,
      'unit': unit,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    print('DEBUG toFirestore: lowStockThreshold = $lowStockThreshold');
    print('DEBUG toFirestore: data = $data');
    return data;
  }

  // Create Stocks from Firestore document
  factory Stocks.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Stocks(
      id: doc.id,
      itemName: data['itemName'] ?? '',
      itemCount: data['itemCount'] ?? 0,
      itemDate: (data['itemDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: data['description'],
      category: data['category'],
      stockPrice: data['stockPrice']?.toDouble(),
      sellPrice: data['sellPrice']?.toDouble(),
      unit: data['unit'],
      lowStockThreshold: data['lowStockThreshold']?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Calculate profit per unit
  double? get profitPerUnit {
    if (sellPrice != null && stockPrice != null) {
      return sellPrice! - stockPrice!;
    }
    return null;
  }

  // Calculate total profit for all items
  double? get totalProfit {
    if (profitPerUnit != null) {
      return profitPerUnit! * itemCount;
    }
    return null;
  }

  // Calculate profit margin percentage
  double? get profitMargin {
    if (sellPrice != null && stockPrice != null && stockPrice! > 0) {
      return ((sellPrice! - stockPrice!) / stockPrice!) * 100;
    }
    return null;
  }

  // Check if item is low on stock based on threshold
  bool get isLowStock {
    final threshold = lowStockThreshold ?? 10;
    return itemCount > 0 && itemCount <= threshold;
  }

  // Check if item is out of stock
  bool get isOutOfStock {
    return itemCount == 0;
  }

  // Check if item is in stock (above low stock threshold)
  bool get isInStock {
    final threshold = lowStockThreshold ?? 10;
    return itemCount > threshold;
  }

  // Create a copy with updated fields
  Stocks copyWith({
    String? id,
    String? itemName,
    int? itemCount,
    DateTime? itemDate,
    String? description,
    String? category,
    double? stockPrice,
    double? sellPrice,
    String? unit,
    int? lowStockThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Stocks(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      itemCount: itemCount ?? this.itemCount,
      itemDate: itemDate ?? this.itemDate,
      description: description ?? this.description,
      category: category ?? this.category,
      stockPrice: stockPrice ?? this.stockPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      unit: unit ?? this.unit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}