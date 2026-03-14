import 'package:firebase_ai/firebase_ai.dart';
import 'package:storehsk/services/firebase_service.dart';
import 'package:storehsk/services/sales_service.dart';
import 'package:intl/intl.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();
  
  final FirebaseService _firebaseService = FirebaseService();
  final SalesService _salesService = SalesService();
  
  GenerativeModel? _model;
  GenerativeModel? _fallbackModel;
  ChatSession? _chatSession;
  ChatSession? _fallbackChatSession;
  bool _usingFallback = false;

  List<Tool> _buildTools() {
    return [
      Tool.functionDeclarations([
          // Tool for getting inventory status
          FunctionDeclaration(
            'getInventoryStatus',
            'Ambil status inventaris saat ini termasuk total item, peringatan stok menipis, dan item yang habis',
            parameters: {},
          ),
          // Tool for searching items
          FunctionDeclaration(
            'searchItems',
            'Cari item di inventaris berdasarkan nama',
            parameters: {
              'searchTerm': Schema.string(
                description: 'Kata kunci pencarian untuk dicocokkan dengan nama item',
              ),
            },
          ),
          // Tool for getting item details
          FunctionDeclaration(
            'getItemDetails',
            'Ambil informasi detail tentang item tertentu',
            parameters: {
              'itemName': Schema.string(
                description: 'Nama item yang tepat untuk diambil detailnya',
              ),
            },
          ),
          // Tool for getting stock report
          FunctionDeclaration(
            'getSalesReport',
            'Ambil laporan stok inventaris untuk tanggal tertentu yang menampilkan nilai stok dan item yang ditambahkan',
            parameters: {
              'date': Schema.string(
                description: 'Tanggal dengan format YYYY-MM-DD (opsional, default hari ini)',
              ),
            },
            optionalParameters: ['date'],
          ),
          // Tool for getting low stock items
          FunctionDeclaration(
            'getLowStockItems',
            'Ambil daftar item yang stoknya mulai menipis',
            parameters: {},
          ),
          // Tool for adding new item suggestion
          FunctionDeclaration(
            'suggestAddItem',
            'Berikan saran untuk menambahkan item baru ke inventaris beserta nilai rekomendasinya',
            parameters: {
              'itemName': Schema.string(
                description: 'Nama item yang ingin ditambahkan',
              ),
              'quantity': Schema.integer(
                description: 'Jumlah yang disarankan',
              ),
              'unit': Schema.string(
                description: 'Satuan pengukuran (pcs, kg, liter, dll.)',
              ),
            },
            optionalParameters: ['quantity', 'unit'],
          ),
          // Tool for getting daily sales summary
          FunctionDeclaration(
            'getSalesSummary',
            'Ambil ringkasan penjualan harian seperti total transaksi, pendapatan, laba, dan item terjual',
            parameters: {
              'date': Schema.string(
                description: 'Tanggal dengan format YYYY-MM-DD (opsional, default hari ini)',
              ),
            },
            optionalParameters: ['date'],
          ),
          // Tool for getting sales data in date range
          FunctionDeclaration(
            'getSalesDataByRange',
            'Ambil data penjualan dalam rentang tanggal tertentu',
            parameters: {
              'startDate': Schema.string(
                description: 'Tanggal mulai dengan format YYYY-MM-DD',
              ),
              'endDate': Schema.string(
                description: 'Tanggal akhir dengan format YYYY-MM-DD',
              ),
            },
          ),
          // Tool for top selling items
          FunctionDeclaration(
            'getTopSellingItems',
            'Ambil daftar item paling laris berdasarkan jumlah terjual pada rentang tanggal tertentu',
            parameters: {
              'startDate': Schema.string(
                description: 'Tanggal mulai dengan format YYYY-MM-DD (opsional, default 7 hari terakhir)',
              ),
              'endDate': Schema.string(
                description: 'Tanggal akhir dengan format YYYY-MM-DD (opsional, default hari ini)',
              ),
              'limit': Schema.integer(
                description: 'Jumlah item teratas yang ditampilkan (opsional, default 5)',
              ),
            },
            optionalParameters: ['startDate', 'endDate', 'limit'],
          ),
        ]),
      ];
  }

  void initialize() {
    if (_model != null) {
      return;
    }

    final tools = _buildTools();

    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3-flash-preview',
      tools: tools,
    );

    _fallbackModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      tools: tools,
    );

    _fallbackModel = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      tools: tools,
    );

    _startNewChat();
  }

  void _ensureInitialized() {
    if (_model == null) {
      initialize();
    }
  }

  List<Content> _buildChatHistory() {
    return [
      Content.text(
        '''Anda adalah asisten AI yang membantu untuk aplikasi manajemen inventaris toko bernama StoreHSK.

Peran Anda adalah:
- Membantu pengguna mengelola inventaris mereka
- Menjawab pertanyaan tentang level stok, nilai inventaris, dan pengelolaan inventaris
- Memberikan insight dan rekomendasi
- Membantu mengotomatiskan tugas seperti menambah item, memeriksa level stok, dan membuat laporan inventaris

Anda memiliki akses ke beberapa alat untuk berinteraksi dengan sistem inventaris. Gunakan alat tersebut saat diperlukan agar dapat memberikan informasi yang akurat dan real-time.

Bersikaplah ramah, ringkas, dan membantu. Saat merespons:
- Jaga jawaban tetap singkat dan dapat langsung ditindaklanjuti
- Gunakan bullet point untuk daftar
- Sorot informasi penting
- Sarankan langkah berikutnya jika sesuai

Pengguna dapat bertanya melalui teks atau suara.'''
      ),
      Content.model([TextPart('Halo! Saya asisten inventaris StoreHSK Anda. Ada yang bisa saya bantu hari ini?')]),
    ];
  }

  void _startNewChat() {
    _ensureInitialized();
    _usingFallback = false;
    _chatSession = _model!.startChat(
      history: _buildChatHistory(),
    );
  }

  void _startFallbackChat() {
    _ensureInitialized();
    _usingFallback = true;
    _fallbackChatSession = _fallbackModel!.startChat(
      history: _buildChatHistory(),
    );
  }

  bool _isRateLimitError(dynamic e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('429') ||
        msg.contains('resource_exhausted') ||
        msg.contains('rate') ||
        msg.contains('quota');
  }

  Future<String> sendMessage(String message) async {
    _ensureInitialized();
    if (_chatSession == null) {
      _startNewChat();
    }

    try {
      return await _runSession(
        session: _chatSession!,
        message: message,
        useFallbackOnRateLimit: true,
      );
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  Future<String> _runSession({
    required ChatSession session,
    required String message,
    bool useFallbackOnRateLimit = false,
  }) async {
    try {
      var response = await session.sendMessage(Content.text(message));

      // Some prompts require multiple tool-call rounds before the model returns text.
      for (int round = 0; round < 5; round++) {
        if (response.functionCalls.isEmpty) {
          final text = response.text;
          if (text != null && text.trim().isNotEmpty) {
            return text;
          }
          return 'Permintaan Anda sudah diproses, tetapi saya tidak dapat membuat respons.';
        }

        final functionResponses = <FunctionResponse>[];
        for (final functionCall in response.functionCalls) {
          final result = await _handleFunctionCall(functionCall);
          functionResponses.add(FunctionResponse(functionCall.name, result));
        }

        response = await session.sendMessage(
          Content.functionResponses(functionResponses),
        );
      }

      return response.text ?? 'Permintaan Anda sudah diproses, tetapi respons akhir belum tersedia.';
    } catch (e) {
      if (useFallbackOnRateLimit && _isRateLimitError(e)) {
        // Switch to fallback model for the rest of the session
        if (_fallbackChatSession == null) {
          _startFallbackChat();
        }
        return await _runSession(
          session: _fallbackChatSession!,
          message: message,
          useFallbackOnRateLimit: false,
        );
      }
      rethrow;
    }
  }

  DateTime? _parseFlexibleDate(String? input, {DateTime? fallback}) {
    final now = DateTime.now();
    if (input == null || input.trim().isEmpty) {
      return fallback;
    }

    final raw = input.trim();
    final lower = raw.toLowerCase();

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed;
    }

    if (lower == 'today' || lower == 'hari ini') {
      return now;
    }
    if (lower == 'yesterday' || lower == 'kemarin') {
      return now.subtract(const Duration(days: 1));
    }

    final numberWords = <String, int>{
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'six': 6,
      'seven': 7,
      'eight': 8,
      'nine': 9,
      'ten': 10,
      'satu': 1,
      'dua': 2,
      'tiga': 3,
      'empat': 4,
      'lima': 5,
      'enam': 6,
      'tujuh': 7,
      'delapan': 8,
      'sembilan': 9,
      'sepuluh': 10,
    };

    final daysAgoDigits = RegExp(r'(\d+)\s*(hari|day|days)\s*(lalu|ago|prior)');
    final matchDigits = daysAgoDigits.firstMatch(lower);
    if (matchDigits != null) {
      final days = int.tryParse(matchDigits.group(1)!);
      if (days != null) {
        return now.subtract(Duration(days: days));
      }
    }

    final daysAgoWords = RegExp(r'([a-z]+)\s*(hari|day|days)\s*(lalu|ago|prior)');
    final matchWords = daysAgoWords.firstMatch(lower);
    if (matchWords != null) {
      final word = matchWords.group(1)!;
      final days = numberWords[word];
      if (days != null) {
        return now.subtract(Duration(days: days));
      }
    }

    return fallback;
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

      case 'getSalesSummary':
        final dateStr = call.args['date'] as String?;
        return await _getSalesSummary(dateStr);

      case 'getSalesDataByRange':
        final startDate = call.args['startDate'] as String;
        final endDate = call.args['endDate'] as String;
        return await _getSalesDataByRange(startDate, endDate);

      case 'getTopSellingItems':
        final startDate = call.args['startDate'] as String?;
        final endDate = call.args['endDate'] as String?;
        final limit = (call.args['limit'] as num?)?.toInt();
        return await _getTopSellingItems(startDate, endDate, limit);
      
      default:
        return {'error': 'Fungsi tidak dikenal: ${call.name}'};
    }
  }

  Future<Map<String, dynamic>> _getSalesSummary(String? dateStr) async {
    try {
      final targetDate = _parseFlexibleDate(dateStr, fallback: DateTime.now());
      if (targetDate == null) {
        return {'error': 'Format tanggal tidak valid. Gunakan YYYY-MM-DD atau frasa seperti "3 hari lalu".'};
      }

      final sales = await _salesService.getSalesByDate(targetDate).first;
      final totalTransactions = sales.length;
      final totalItemsSold = sales.fold<int>(0, (sum, sale) => sum + sale.quantitySold);
      final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + (sale.sellPrice * sale.quantitySold));
      final totalProfit = sales.fold<double>(0, (sum, sale) => sum + sale.profit);
      final averageTransactionValue = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

      return {
        'date': DateFormat('yyyy-MM-dd').format(targetDate),
        'totalTransactions': totalTransactions,
        'totalItemsSold': totalItemsSold,
        'totalRevenue': totalRevenue,
        'totalProfit': totalProfit,
        'averageTransactionValue': averageTransactionValue,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getSalesDataByRange(String startDate, String endDate) async {
    try {
      final start = _parseFlexibleDate(startDate);
      final end = _parseFlexibleDate(endDate);
      if (start == null || end == null) {
        return {'error': 'Format rentang tanggal tidak valid. Gunakan YYYY-MM-DD atau frasa tanggal relatif.'};
      }
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

      final sales = await _salesService.getSalesByDateRange(start, endOfDay).first;

      final totalTransactions = sales.length;
      final totalItemsSold = sales.fold<int>(0, (sum, sale) => sum + sale.quantitySold);
      final totalRevenue = sales.fold<double>(0, (sum, sale) => sum + (sale.sellPrice * sale.quantitySold));
      final totalProfit = sales.fold<double>(0, (sum, sale) => sum + sale.profit);

      return {
        'startDate': DateFormat('yyyy-MM-dd').format(start),
        'endDate': DateFormat('yyyy-MM-dd').format(end),
        'totalTransactions': totalTransactions,
        'totalItemsSold': totalItemsSold,
        'totalRevenue': totalRevenue,
        'totalProfit': totalProfit,
        'sales': sales.map((sale) => {
              'itemId': sale.itemId,
              'itemName': sale.itemName,
              'quantitySold': sale.quantitySold,
              'stockPrice': sale.stockPrice,
              'sellPrice': sale.sellPrice,
              'profit': sale.profit,
              'saleDate': DateFormat('yyyy-MM-dd').format(sale.saleDate),
            }).toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getTopSellingItems(String? startDate, String? endDate, int? limit) async {
    try {
      final end = _parseFlexibleDate(endDate, fallback: DateTime.now());
      if (end == null) {
        return {'error': 'Tanggal akhir tidak valid.'};
      }
      final start = _parseFlexibleDate(
        startDate,
        fallback: end.subtract(const Duration(days: 6)),
      );
      if (start == null) {
        return {'error': 'Tanggal mulai tidak valid.'};
      }
      final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
      final takeCount = (limit == null || limit <= 0) ? 5 : limit;

      final sales = await _salesService.getSalesByDateRange(start, endOfDay).first;
      final grouped = <String, Map<String, dynamic>>{};

      for (final sale in sales) {
        final existing = grouped[sale.itemName];
        if (existing == null) {
          grouped[sale.itemName] = {
            'itemName': sale.itemName,
            'totalQuantitySold': sale.quantitySold,
            'totalRevenue': sale.sellPrice * sale.quantitySold,
            'totalProfit': sale.profit,
          };
        } else {
          existing['totalQuantitySold'] = (existing['totalQuantitySold'] as int) + sale.quantitySold;
          existing['totalRevenue'] = (existing['totalRevenue'] as double) + (sale.sellPrice * sale.quantitySold);
          existing['totalProfit'] = (existing['totalProfit'] as double) + sale.profit;
        }
      }

      final topItems = grouped.values.toList()
        ..sort((a, b) => (b['totalQuantitySold'] as int).compareTo(a['totalQuantitySold'] as int));

      return {
        'startDate': DateFormat('yyyy-MM-dd').format(start),
        'endDate': DateFormat('yyyy-MM-dd').format(end),
        'totalUniqueItemsSold': grouped.length,
        'topItems': topItems.take(takeCount).toList(),
      };
    } catch (e) {
      return {'error': e.toString()};
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
          'status': item.isOutOfStock ? 'stok habis' : (item.isLowStock ? 'stok menipis' : 'stok tersedia'),
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
        return {'found': false, 'message': 'Item tidak ditemukan'};
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
        'status': item.isOutOfStock ? 'stok habis' : (item.isLowStock ? 'stok menipis' : 'stok tersedia'),
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
      'suggestion': 'Tambahkan item ke inventaris',
      'itemName': itemName,
      'recommendedQuantity': quantity ?? 10,
      'recommendedUnit': unit ?? 'pcs',
      'note': 'Anda dapat menambahkan item ini menggunakan opsi "Input Manual" atau "Pindai dengan Kamera" dari tombol Tambah.',
    };
  }

  void resetChat() {
    _ensureInitialized();
    _usingFallback = false;
    _fallbackChatSession = null;
    _startNewChat();
  }

  void dispose() {
    _chatSession = null;
    _fallbackChatSession = null;
  }
}
