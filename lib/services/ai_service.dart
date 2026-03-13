import 'package:firebase_ai/firebase_ai.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:intl/intl.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();
  
  final FirebaseService _firebaseService = FirebaseService();
  
  GenerativeModel? _model;
  ChatSession? _chatSession;

  void initialize() {
    if (_model != null) {
      return;
    }

    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3-flash-preview',
      tools: [
        Tool.functionDeclarations([
          // Tool for getting inventory status
          FunctionDeclaration(
            'getInventoryStatus',
            'Get current inventory status including total items, low stock alerts, and out of stock items',
            parameters: {},
          ),
          // Tool for searching items
          FunctionDeclaration(
            'searchItems',
            'Search for items in the inventory by name',
            parameters: {
              'searchTerm': Schema.string(
                description: 'The search term to look for in item names',
              ),
            },
          ),
          // Tool for getting item details
          FunctionDeclaration(
            'getItemDetails',
            'Get detailed information about a specific item',
            parameters: {
              'itemName': Schema.string(
                description: 'The exact name of the item to get details for',
              ),
            },
          ),
          // Tool for getting stock report
          FunctionDeclaration(
            'getSalesReport',
            'Get inventory stock report for a specific date showing stock values and items added',
            parameters: {
              'date': Schema.string(
                description: 'Date in format YYYY-MM-DD (optional, defaults to today)',
              ),
            },
            optionalParameters: ['date'],
          ),
          // Tool for getting low stock items
          FunctionDeclaration(
            'getLowStockItems',
            'Get list of items that are running low on stock',
            parameters: {},
          ),
          // Tool for adding new item suggestion
          FunctionDeclaration(
            'suggestAddItem',
            'Suggest adding a new item to inventory with recommended values',
            parameters: {
              'itemName': Schema.string(
                description: 'Name of the item to add',
              ),
              'quantity': Schema.integer(
                description: 'Suggested quantity',
              ),
              'unit': Schema.string(
                description: 'Unit of measurement (pcs, kg, liters, etc.)',
              ),
            },
            optionalParameters: ['quantity', 'unit'],
          ),
        ]),
      ],
    );

    _startNewChat();
  }

  void _ensureInitialized() {
    if (_model == null) {
      initialize();
    }
  }

  void _startNewChat() {
    _ensureInitialized();
    _chatSession = _model!.startChat(
      history: [
        Content.text(
          '''You are a helpful AI assistant for a store inventory management app called StoreHSK. 
          
Your role is to:
- Help users manage their inventory
- Answer questions about stock levels, inventory value, and inventory management
- Provide insights and recommendations
- Help with automating tasks like adding items, checking stock levels, and generating inventory reports

You have access to several tools to interact with the inventory system. Use them when appropriate to provide accurate, real-time information.

Be friendly, concise, and helpful. When responding:
- Keep answers brief and actionable
- Use bullet points for lists
- Highlight important information
- Suggest next steps when appropriate

The user can ask you questions via text or voice.'''
        ),
        Content.model([TextPart('Hello! I\'m your StoreHSK inventory assistant. How can I help you today?')]),
      ],
    );
  }

  Future<String> sendMessage(String message) async {
    _ensureInitialized();
    if (_chatSession == null) {
      _startNewChat();
    }

    try {
      final response = await _chatSession!.sendMessage(Content.text(message));
      
      // Handle function calls if present
      if (response.functionCalls.isNotEmpty) {
        final functionResponses = <FunctionResponse>[];
        
        for (final functionCall in response.functionCalls) {
          final result = await _handleFunctionCall(functionCall);
          functionResponses.add(FunctionResponse(functionCall.name, result));
        }
        
        // Send function responses back to the model
        final finalResponse = await _chatSession!.sendMessage(
          Content.functionResponses(functionResponses),
        );
        
        return finalResponse.text ?? 'I processed your request, but couldn\'t generate a response.';
      }
      
      return response.text ?? 'I\'m sorry, I couldn\'t generate a response.';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  Future<Map<String, dynamic>> _handleFunctionCall(FunctionCall call) async {
    switch (call.name) {
      case 'getInventoryStatus':
        return await _getInventoryStatus();
      
      case 'searchItems':
        final searchTerm = call.args['searchTerm'] as String;
        return await _searchItems(searchTerm);
      
      case 'getItemDetails':
        final itemName = call.args['itemName'] as String;
        return await _getItemDetails(itemName);
      
      case 'getSalesReport':
        final dateStr = call.args['date'] as String?;
        return await _getSalesReport(dateStr);
      
      case 'getLowStockItems':
        return await _getLowStockItems();
      
      case 'suggestAddItem':
        final itemName = call.args['itemName'] as String;
        final quantity = call.args['quantity'] as int?;
        final unit = call.args['unit'] as String?;
        return _suggestAddItem(itemName, quantity, unit);
      
      default:
        return {'error': 'Unknown function: ${call.name}'};
    }
  }

  Future<Map<String, dynamic>> _getInventoryStatus() async {
    try {
      final stocks = await _firebaseService.getStocks();
      final lowStockItems = stocks.where((s) => s.isLowStock && !s.isOutOfStock).toList();
      final outOfStockItems = stocks.where((s) => s.isOutOfStock).toList();
      
      return {
        'totalItems': stocks.length,
        'totalQuantity': stocks.fold<int>(0, (sum, item) => sum + item.itemCount),
        'lowStockCount': lowStockItems.length,
        'outOfStockCount': outOfStockItems.length,
        'lowStockItems': lowStockItems.map((s) => {
          'name': s.itemName,
          'quantity': s.itemCount,
          'unit': s.unit,
        }).toList(),
        'outOfStockItems': outOfStockItems.map((s) => s.itemName).toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _searchItems(String searchTerm) async {
    try {
      final results = await _firebaseService.searchStocksByName(searchTerm);
      return {
        'count': results.length,
        'items': results.map((item) => {
          'name': item.itemName,
          'quantity': item.itemCount,
          'unit': item.unit,
          'stockPrice': item.stockPrice,
          'sellPrice': item.sellPrice,
          'status': item.isOutOfStock ? 'out of stock' : (item.isLowStock ? 'low stock' : 'in stock'),
        }).toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getItemDetails(String itemName) async {
    try {
      final item = await _firebaseService.findStockByExactName(itemName);
      if (item == null) {
        return {'found': false, 'message': 'Item not found'};
      }
      
      return {
        'found': true,
        'name': item.itemName,
        'quantity': item.itemCount,
        'unit': item.unit,
        'stockPrice': item.stockPrice,
        'sellPrice': item.sellPrice,
        'barcode': item.barcode,
        'lowStockThreshold': item.lowStockThreshold,
        'status': item.isOutOfStock ? 'out of stock' : (item.isLowStock ? 'low stock' : 'in stock'),
        'dateAdded': DateFormat('yyyy-MM-dd').format(item.itemDate),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getSalesReport(String? dateStr) async {
    try {
      DateTime targetDate = DateTime.now();
      if (dateStr != null) {
        targetDate = DateTime.parse(dateStr);
      }
      
      final stocks = await _firebaseService.getStocks();
      
      // Filter stocks by date if needed
      final stocksOnDate = stocks.where((stock) {
        final stockDate = DateTime(
          stock.itemDate.year,
          stock.itemDate.month,
          stock.itemDate.day,
        );
        final targetDateOnly = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        return stockDate.isAtSameMomentAs(targetDateOnly);
      }).toList();
      
      final totalStockValue = stocks.fold<double>(
        0,
        (sum, stock) => sum + ((stock.stockPrice ?? 0) * stock.itemCount),
      );
      final totalSellValue = stocks.fold<double>(
        0,
        (sum, stock) => sum + ((stock.sellPrice ?? 0) * stock.itemCount),
      );
      final totalItems = stocks.fold<int>(0, (sum, stock) => sum + stock.itemCount);
      
      // Get top value items
      final sortedByValue = stocks
          .where((s) => s.sellPrice != null && s.sellPrice! > 0)
          .toList()
        ..sort((a, b) => ((b.sellPrice ?? 0) * b.itemCount)
            .compareTo((a.sellPrice ?? 0) * a.itemCount));
      
      return {
        'date': DateFormat('yyyy-MM-dd').format(targetDate),
        'totalStockItems': stocks.length,
        'itemsAddedOnDate': stocksOnDate.length,
        'totalStockValue': totalStockValue,
        'totalPotentialSellValue': totalSellValue,
        'totalQuantityInStock': totalItems,
        'topValueItems': sortedByValue.take(5).map((stock) => {
              'itemName': stock.itemName,
              'quantity': stock.itemCount,
              'unit': stock.unit,
              'totalValue': (stock.sellPrice ?? 0) * stock.itemCount,
            }).toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getLowStockItems() async {
    try {
      final stocks = await _firebaseService.getStocks();
      final lowStockItems = stocks.where((s) => s.isLowStock && !s.isOutOfStock).toList();
      
      return {
        'count': lowStockItems.length,
        'items': lowStockItems.map((item) => {
          'name': item.itemName,
          'currentQuantity': item.itemCount,
          'threshold': item.lowStockThreshold ?? 10,
          'unit': item.unit,
          'suggestedRestock': (item.lowStockThreshold ?? 10) * 3, // Suggest 3x threshold
        }).toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> _suggestAddItem(String itemName, int? quantity, String? unit) {
    return {
      'suggestion': 'Add item to inventory',
      'itemName': itemName,
      'recommendedQuantity': quantity ?? 10,
      'recommendedUnit': unit ?? 'pcs',
      'note': 'You can add this item using the "Manual Entry" or "Scan with Camera" option from the Add button.',
    };
  }

  void resetChat() {
    _ensureInitialized();
    _startNewChat();
  }

  void dispose() {
    _chatSession = null;
  }
}
