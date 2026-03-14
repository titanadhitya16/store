import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:storehsk/screens/storage.dart';
import 'package:storehsk/screens/home.dart';
import 'package:storehsk/screens/camera_scanner.dart';
import 'package:storehsk/screens/settings.dart';
import 'package:storehsk/screens/AI_chatbot.dart';
import 'package:storehsk/widgets/item_form.dart';
import 'package:storehsk/widgets/sell_form.dart';
  
final headers = [
  const FHeader(),
  const FHeader(title: Text('Storage')),
  const FHeader(title: Text('AI Assistant')),
  FHeader(
    title: const Text('Settings'),
    suffixes: [FHeaderAction(icon: const Icon(FIcons.ellipsis), onPress: () {})],
  ),
];

final contents = [
  const Home(),
  const Storage(),
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

  void _showAddItemOptions(BuildContext scaffoldContext) {
    // Show bottom sheet for adding items (controller used via builder callback)
    // ignore: unused_result
    showFPersistentSheet(
      context: scaffoldContext,
      side: FLayout.btt,
      useSafeArea: true,
      mainAxisMaxRatio: 0.5,
      builder: (context, controller) => Container(
        width: double.infinity,
        height: double.infinity,
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
                'Tambahkan Item',
                style: context.theme.typography.xl2.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.theme.colors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih cara menambahkan item:',
                style: context.theme.typography.base.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FButton(
                  onPress: () {
                    controller.hide();
                    _openCameraScanner(scaffoldContext);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FIcons.camera),
                      SizedBox(width: 8),
                      Text('Scan dengan Kamera'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FButton(
                  onPress: () {
                    controller.hide();
                    _openManualForm(scaffoldContext);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FIcons.pencil),
                      SizedBox(width: 8),
                      Text('Entri Manual'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FButton(
                  onPress: () {
                    controller.hide();
                    _openSellForm(scaffoldContext);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FIcons.shoppingCart),
                      SizedBox(width: 8),
                      Text('Jual Item'),
                    ],
                  ),
                ),
              ),
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
      ),
    );
  }

  void _openCameraScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScanner(
          onItemDetected: (newItem) {
            showFToast(
              context: context,
              alignment: .topCenter,
              title: Text('Item Ditambahkan'),
              description: Text('${newItem.itemName} berhasil ditambahkan!'),
              style: .context(),
            );
          },
        ),
      ),
    );
  }

  void _openManualForm(BuildContext context) {
    showItemFormSheet(
      context,
      onItemSaved: (newItem) {
        showFToast(
          context: context,
          alignment: .topCenter,
          title: Text('Item Ditambahkan'),
          description: Text('${newItem.itemName} berhasil ditambahkan!'),
          style: .context(),
        );
      },
    );
  }

  void _openSellForm(BuildContext context) {
    showSellFormSheet(
      context,
      onSaleCompleted: (sales) {
        // Sales completion is handled by the sell form toast
      },
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
        FBottomNavigationBarItem(icon: Icon(FIcons.house), label: Text('Home')),
        FBottomNavigationBarItem(icon: Icon(FIcons.warehouse), label: Text('Storage')),
        FBottomNavigationBarItem(icon: Icon(FIcons.sparkles), label: Text('AI')),
        FBottomNavigationBarItem(icon: Icon(FIcons.settings), label: Text('Settings')),
      ],
    ),
    child: Builder(
      builder: (scaffoldContext) => Stack(children: [
        contents[_index],
        if (_showFloatingButton)
          Positioned(
            bottom: 20.0,
            right: 16.0,
            child: FloatingActionButton(
              onPressed: () {
                _showAddItemOptions(scaffoldContext);
              },
              child: const Icon(FIcons.plus),
            ),
          ),
      ]),
    ),
  );
}