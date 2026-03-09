import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:storehsk/models/sale.dart';

class SalesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'sales';

  CollectionReference get _salesCollection =>
      _firestore.collection(_collectionName);

  // Add a new sale
  Future<String> addSale(Sale sale) async {
    try {
      DocumentReference docRef = await _salesCollection.add(sale.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add sale: $e');
    }
  }

  // Get all sales as a stream
  Stream<List<Sale>> getSalesStream() {
    return _salesCollection
        .orderBy('saleDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();
    });
  }

  // Get sales for a specific date
  Stream<List<Sale>> getSalesByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _salesCollection
        .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();
    });
  }

  // Get sales for a date range
  Stream<List<Sale>> getSalesByDateRange(DateTime startDate, DateTime endDate) {
    return _salesCollection
        .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Sale.fromFirestore(doc)).toList();
    });
  }

  // Get total profit for a date
  Future<double> getTotalProfitByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      QuerySnapshot querySnapshot = await _salesCollection
          .where('saleDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('saleDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      double totalProfit = 0.0;
      for (var doc in querySnapshot.docs) {
        Sale sale = Sale.fromFirestore(doc);
        totalProfit += sale.profit;
      }
      return totalProfit;
    } catch (e) {
      throw Exception('Failed to get total profit: $e');
    }
  }

  // Delete a sale
  Future<void> deleteSale(String id) async {
    try {
      await _salesCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete sale: $e');
    }
  }
}
