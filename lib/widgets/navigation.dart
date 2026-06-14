import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:storehsk/screens/home.dart';
import 'package:storehsk/screens/inventory.dart';
import 'package:storehsk/screens/settings.dart';
import 'package:storehsk/screens/AI_chatbot.dart';
import 'package:storehsk/widgets/item_form.dart';
import 'package:storehsk/widgets/sell_form.dart';
import 'package:storehsk/widgets/stock_form.dart';

final headers = [
  const FHeader(),
  const FHeader(title: Text('Inventaris')),
  const FHeader(title: Text('AI Assistant')),
  FHeader(
    title: const Text('Settings'),
    suffixes: [
      FHeaderAction(icon: const Icon(FIcons.ellipsis), onPress: () {}),
    ],
  ),
];

final contents = [
  const Home(),
  const Inventory(),
  const AIChatbot(),
  const Settings(),
];

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int _index = 0;

  bool get _showFloatingButton => _index == 0 || _index == 1;

  void _showFabOptions(BuildContext scaffoldContext) {
    if (_index == 0) {
      _showFinanceOptions(scaffoldContext);
    } else if (_index == 1) {
      _showInventoryOptions(scaffoldContext);
    }
  }

  void _showFinanceOptions(BuildContext scaffoldContext) {
    // ignore: unused_result
    showFPersistentSheet(
      context: scaffoldContext,
      side: FLayout.btt,
      useSafeArea: true,
      mainAxisMaxRatio: 0.5,
      builder: (context, controller) => _buildSheet(
        context,
        controller,
        title: 'Tambahkan Laporan Keuangan',
        actions: [
          _sheetButton(
            icon: FIcons.pencil,
            label: 'Entri Manual',
            onPress: () {
              controller.hide();
              _openFinanceForm(scaffoldContext);
            },
          ),
        ],
      ),
    );
  }

  void _showInventoryOptions(BuildContext scaffoldContext) {
    // ignore: unused_result
    showFPersistentSheet(
      context: scaffoldContext,
      side: FLayout.btt,
      useSafeArea: true,
      mainAxisMaxRatio: 0.4,
      builder: (context, controller) => _buildSheet(
        context,
        controller,
        title: 'Inventaris',
        actions: [
          _sheetButton(
            icon: FIcons.plus,
            label: 'Tambah Item',
            onPress: () {
              controller.hide();
              showStockFormSheet(
                scaffoldContext,
                onStockSaved: (_) =>
                    _showToast(scaffoldContext, 'Item ditambahkan'),
              );
            },
          ),
          const SizedBox(height: 12),
          _sheetButton(
            icon: FIcons.shoppingCart,
            label: 'Jual Item',
            onPress: () {
              controller.hide();
              showSellFormSheet(scaffoldContext);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSheet(
    BuildContext context,
    FPersistentSheetController controller, {
    required String title,
    required List<Widget> actions,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.theme.colors.background,
        border: Border.symmetric(
          horizontal: BorderSide(color: context.theme.colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.theme.typography.xl2.copyWith(
                fontWeight: FontWeight.w600,
                color: context.theme.colors.foreground,
              ),
            ),
            const SizedBox(height: 24),
            ...actions,
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FButton(
                onPress: () => controller.hide(),
                child: const Text('Batal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetButton({
    required IconData icon,
    required String label,
    required VoidCallback onPress,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FButton(
        onPress: onPress,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  void _openFinanceForm(BuildContext context) {
    showItemFormSheet(
      context,
      onItemSaved: (newEntry) {
        showFToast(
          context: context,
          alignment: .topCenter,
          title: const Text('Laporan Disimpan'),
          description: Text(
            'Laporan keuangan untuk tanggal ${newEntry.date.day}/${newEntry.date.month} berhasil disimpan!',
          ),
          style: .context(),
        );
      },
    );
  }

  void _showToast(BuildContext context, String message) {
    showFToast(
      context: context,
      alignment: .topCenter,
      title: Text(message),
      style: .context(),
    );
  }

  @override
  Widget build(BuildContext context) => FScaffold(
        resizeToAvoidBottomInset: false,
        header: headers[_index],
        footer: FBottomNavigationBar(
          index: _index,
          onChange: (index) => setState(() => _index = index),
          children: const [
            FBottomNavigationBarItem(
              icon: Icon(FIcons.house),
              label: Text('Home'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.package),
              label: Text('Inventaris'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.sparkles),
              label: Text('AI'),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.settings),
              label: Text('Settings'),
            ),
          ],
        ),
        child: Builder(
          builder: (scaffoldContext) => Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: contents[_index]),
              if (_showFloatingButton)
                Positioned(
                  bottom: 20.0,
                  right: 16.0,
                  child: FloatingActionButton(
                    onPressed: () => _showFabOptions(scaffoldContext),
                    child: const Icon(FIcons.plus),
                  ),
                ),
            ],
          ),
        ),
      );
}
