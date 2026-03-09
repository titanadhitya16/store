import 'package:cloud_firestore/cloud_firestore.dart';

class Sale {
  final String? id;
  final String itemId;
  final String itemName;
  final int quantitySold;
  final double stockPrice;  // Cost price
  final double sellPrice;   // Selling price
  final double profit;      // Calculated profit
  final DateTime saleDate;
  final DateTime createdAt;

  Sale({
    this.id,
    required this.itemId,
    required this.itemName,
    required this.quantitySold,
    required this.stockPrice,
    required this.sellPrice,
    required this.profit,
    required this.saleDate,
    required this.createdAt,
  });

  // Convert Sale to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'quantitySold': quantitySold,
      'stockPrice': stockPrice,
      'sellPrice': sellPrice,
      'profit': profit,
      'saleDate': Timestamp.fromDate(saleDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Create Sale from Firestore document
  factory Sale.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Sale(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      quantitySold: data['quantitySold'] ?? 0,
      stockPrice: data['stockPrice']?.toDouble() ?? 0.0,
      sellPrice: data['sellPrice']?.toDouble() ?? 0.0,
      profit: data['profit']?.toDouble() ?? 0.0,
      saleDate: (data['saleDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}
