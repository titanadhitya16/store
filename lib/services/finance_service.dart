import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:storehsk/models/finance_entry.dart';

class FinanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionPath = 'financeEntries';

  Future<void> addFinanceEntry(FinanceEntry entry) async {
    await _db.collection(_collectionPath).add(entry.toFirestore());
  }

  Stream<List<FinanceEntry>> getFinanceEntriesByDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection(_collectionPath)
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThan: endOfDay)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FinanceEntry.fromFirestore(doc))
            .toList());
  }

  Future<void> updateFinanceEntry(String id, FinanceEntry entry) async {
    await _db.collection(_collectionPath).doc(id).update(entry.toFirestore());
  }

  Future<void> deleteFinanceEntry(String id) async {
    await _db.collection(_collectionPath).doc(id).delete();
  }
}
