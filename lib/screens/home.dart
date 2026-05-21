import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:gap/gap.dart';
import 'package:storehsk/models/finance_entry.dart';
import 'package:storehsk/services/finance_service.dart';
import 'package:storehsk/utils/currency_formatter.dart';

final FinanceService _financeService = FinanceService();

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime? selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return FScaffold(
      child: StreamBuilder<List<FinanceEntry>>(
        stream: _financeService.getFinanceEntriesByDate(selectedDate ?? DateTime.now()),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          
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

                // Finance Overview
                _buildFinanceOverview(entries),

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

  Widget _buildFinanceOverview(List<FinanceEntry> entries) {
    if (entries.isEmpty) {
      return FCard(
        title: const Text('Laporan Keuangan'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Tidak ada data untuk tanggal ini',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // For simplicity, we'll just show the first entry's data.
    // In a real app, you might want to aggregate data if multiple entries can exist for a day.
    final entry = entries.first;

    return FCard(
      title: const Text('Laporan Keuangan'),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildMetricRow('Uang Awal', entry.uangAwal, Icons.account_balance_wallet, Colors.blue),
            const Gap(16),
            _buildMetricRow('Penghasilan', entry.penghasilan, Icons.arrow_upward, Colors.green),
            const Gap(16),
            _buildMetricRow('Pengeluaran', entry.pengeluaran, Icons.arrow_downward, Colors.red),
            const Divider(height: 32),
            _buildMetricRow('Laba Bersih Harian', entry.labaBersihHarian, Icons.monetization_on, Colors.purple),
            const Divider(height: 32),
            _buildDistributionCard(entry),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, double value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28.0),
        ),
        const Gap(16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const Gap(4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatRupiah(value),
                  style: TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionCard(FinanceEntry entry) {
    return FCard(
      title: const Text('Distribusi Laba'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDistributionRow('Modal Awal', entry.modalAwal),
            const Gap(12),
            _buildDistributionRow('Bagi Hasil', entry.bagiHasil),
            const Gap(12),
            _buildDistributionRow('Pram', entry.pram),
            const Gap(12),
            _buildDistributionRow('Tab. Rollo', entry.tabRollo),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        Text(
          formatRupiah(value),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Selamat Pagi';
    }
    if (hour < 17) {
      return 'Selamat Siang';
    }
    return 'Selamat Malam';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}