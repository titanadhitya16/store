import 'package:forui/forui.dart';
import 'package:flutter/material.dart';
import 'package:storehsk/screens/storage.dart';
import 'package:storehsk/screens/home.dart';
import 'package:storehsk/screens/camera_scanner.dart';
import 'package:storehsk/screens/settings.dart';
import 'package:storehsk/component/itemForm.dart';
  
final headers = [
  const FHeader(),
  const FHeader( title: Text('Storage'),),
  FHeader(
    title: const Text('Settings'),
    suffixes: [FHeaderAction(icon: const Icon(FIcons.ellipsis), onPress: () {})],
  ),
];

final contents = [
  const Home(),
  const Storage(),
  const Settings(),
];

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int _index = 0;

  void _showAddItemOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: const Text('How would you like to add an item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openCameraScanner(context);
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan with Camera'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openManualForm(context);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Manual Entry'),
          ),
        ],
      ),
    );
  }

  void _openCameraScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScanner(
          onItemDetected: (newItem) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${newItem.itemName} added successfully!'),
                backgroundColor: Colors.green,
              ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newItem.itemName} added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
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
        FBottomNavigationBarItem(icon: Icon(FIcons.settings), label: Text('Settings')),
      ],
    ),
    child: Stack(children: [
      contents[_index],
      Positioned(
        bottom: 40.0, 
        right: 16.0,
        child: FButton(
          style: FButtonStyle.primary(),
          onPress: () {
            _showAddItemOptions(context);
          },
          child: const Icon(FIcons.plus),
        ),
      ),
    ]),
  );
}