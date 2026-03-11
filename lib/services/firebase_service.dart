import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:storehsk/services/notification_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'stocks';
  final NotificationService _notificationService = NotificationService();

  // Get reference to stocks collection
  CollectionReference get _stocksCollection =>
      _firestore.collection(_collectionName);

  // Create a new stock item
  Future<String> addStock(Stocks stock) async {
    try {
      DocumentReference docRef = await _stocksCollection.add(stock.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add stock: $e');
    }
  }

  // Get all stocks as a stream
  Stream<List<Stocks>> getStocksStream() {
    return _stocksCollection
        .orderBy('itemDate', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Stocks.fromFirestore(doc)).toList();
    });
  }

  // Get all stocks as a future
  Future<List<Stocks>> getStocks() async {
    try {
      QuerySnapshot querySnapshot = await _stocksCollection
          .orderBy('itemDate', descending: true)
          .get();
      return querySnapshot.docs
          .map((doc) => Stocks.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch stocks: $e');
    }
  }

  // Get a single stock by ID
  Future<Stocks?> getStockById(String id) async {
    try {
      DocumentSnapshot doc = await _stocksCollection.doc(id).get();
      if (doc.exists) {
        return Stocks.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch stock: $e');
    }
  }

  // Update a stock item
  Future<void> updateStock(String id, Stocks stock) async {
    try {
      // Get the previous stock to check if it became empty
      final previousStock = await getStockById(id);
      
      await _stocksCollection.doc(id).update(stock.toFirestore());
      
      // Check if stock just became empty
      if (previousStock != null && 
          previousStock.itemCount > 0 && 
          stock.itemCount == 0) {
        await _notificationService.showOutOfStockNotification(
          itemName: stock.itemName,
        );
      }
      // Check if stock just became low (using item-specific threshold)
      else if (previousStock != null && stock.itemCount > 0) {
        final threshold = stock.lowStockThreshold ?? 10;
        if (previousStock.itemCount > threshold && 
            stock.itemCount <= threshold) {
          await _notificationService.showLowStockNotification(
            itemName: stock.itemName,
            quantity: stock.itemCount,
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }

  // Delete a stock item
  Future<void> deleteStock(String id) async {
    try {
      await _stocksCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete stock: $e');
    }
  }

  // Update stock quantity
  Future<void> updateStockQuantity(String id, int newQuantity) async {
    try {
      // Get the previous stock to check if it became empty
      final previousStock = await getStockById(id);
      
      await _stocksCollection.doc(id).update({
        'itemCount': newQuantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Check if stock just became empty
      if (previousStock != null && 
          previousStock.itemCount > 0 && 
          newQuantity == 0) {
        await _notificationService.showOutOfStockNotification(
          itemName: previousStock.itemName,
        );
      }
      // Check if stock just became low (using item-specific threshold)
      else if (previousStock != null && newQuantity > 0) {
        final threshold = previousStock.lowStockThreshold ?? 10;
        if (previousStock.itemCount > threshold && 
            newQuantity <= threshold) {
          await _notificationService.showLowStockNotification(
            itemName: previousStock.itemName,
            quantity: newQuantity,
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to update stock quantity: $e');
    }
  }

  // Search stocks by name
  Future<List<Stocks>> searchStocksByName(String searchTerm) async {
    try {
      QuerySnapshot querySnapshot = await _stocksCollection
          .where('itemName', isGreaterThanOrEqualTo: searchTerm)
          .where('itemName', isLessThanOrEqualTo: '$searchTerm\uf8ff')
          .get();
      return querySnapshot.docs
          .map((doc) => Stocks.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to search stocks: $e');
    }
  }

  // Find stock by exact name match
  Future<Stocks?> findStockByExactName(String itemName) async {
    try {
      QuerySnapshot querySnapshot = await _stocksCollection
          .where('itemName', isEqualTo: itemName)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return Stocks.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to find stock by name: $e');
    }
  }

  // Get low stock items (count < threshold)
  Stream<List<Stocks>> getLowStockItems({int threshold = 10}) {
    return _stocksCollection
        .where('itemCount', isLessThan: threshold)
        .where('itemCount', isGreaterThan: 0)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Stocks.fromFirestore(doc)).toList();
    });
  }

  // Get out of stock items
  Stream<List<Stocks>> getOutOfStockItems() {
    return _stocksCollection
        .where('itemCount', isEqualTo: 0)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Stocks.fromFirestore(doc)).toList();
    });
  }

  // Get stocks by date range
  Stream<List<Stocks>> getStocksByDateRange(DateTime startDate, DateTime endDate) {
    return _stocksCollection
        .where('itemDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('itemDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Stocks.fromFirestore(doc)).toList();
    });
  }

  // Get stocks by category
  Stream<List<Stocks>> getStocksByCategory(String category) {
    return _stocksCollection
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Stocks.fromFirestore(doc)).toList();
    });
  }

  // Batch add multiple stocks (useful for initial data)
  Future<void> addMultipleStocks(List<Stocks> stocks) async {
    try {
      WriteBatch batch = _firestore.batch();
      for (var stock in stocks) {
        DocumentReference docRef = _stocksCollection.doc();
        batch.set(docRef, stock.toFirestore());
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to add multiple stocks: $e');
    }
  }
}
