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
  final double? price;
  final String? unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Stocks({
    this.id,
    required this.itemName,
    required this.itemCount,
    required this.itemDate,
    this.description,
    this.category,
    this.price,
    this.unit,
    this.createdAt,
    this.updatedAt,
  });

  // Convert Stocks to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'itemName': itemName,
      'itemCount': itemCount,
      'itemDate': Timestamp.fromDate(itemDate),
      'description': description,
      'category': category,
      'price': price,
      'unit': unit,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
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
      price: data['price']?.toDouble(),
      unit: data['unit'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Create a copy with updated fields
  Stocks copyWith({
    String? id,
    String? itemName,
    int? itemCount,
    DateTime? itemDate,
    String? description,
    String? category,
    double? price,
    String? unit,
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
      price: price ?? this.price,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}