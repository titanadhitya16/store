import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceEntry {
  final String? id;
  final DateTime date;
  final double uangAwal;
  final double penghasilan;
  final double pengeluaran;
  final double labaBersihHarian;
  final double modalAwal;
  final double bagiHasil;
  final double pram;
  final double tabRollo;
  final DateTime createdAt;

  FinanceEntry({
    this.id,
    required this.date,
    required this.uangAwal,
    required this.penghasilan,
    required this.pengeluaran,
    required this.labaBersihHarian,
    required this.modalAwal,
    required this.bagiHasil,
    required this.pram,
    required this.tabRollo,
    required this.createdAt,
  });

  factory FinanceEntry.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return FinanceEntry(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      uangAwal: (data['uangAwal'] as num).toDouble(),
      penghasilan: (data['penghasilan'] as num).toDouble(),
      pengeluaran: (data['pengeluaran'] as num).toDouble(),
      labaBersihHarian: (data['labaBersihHarian'] as num).toDouble(),
      modalAwal: (data['modalAwal'] as num).toDouble(),
      bagiHasil: (data['bagiHasil'] as num).toDouble(),
      pram: (data['pram'] as num).toDouble(),
      tabRollo: (data['tabRollo'] as num).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'uangAwal': uangAwal,
      'penghasilan': penghasilan,
      'pengeluaran': pengeluaran,
      'labaBersihHarian': labaBersihHarian,
      'modalAwal': modalAwal,
      'bagiHasil': bagiHasil,
      'pram': pram,
      'tabRollo': tabRollo,
      'createdAt': createdAt,
    };
  }
}
