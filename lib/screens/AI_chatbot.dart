import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/services/ai_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class AIChatbot extends StatefulWidget {
  const AIChatbot({super.key});

  @override
  State<AIChatbot> createState() => _AIChatbotState();
}

class _AIChatbotState extends State<AIChatbot> {
  final AIService _aiService = AIService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  String? _speechLocaleId;

  String _encodeModelResponse(String text) {
    final tokenPattern = RegExp(r'\*\*\{([^{}]+)\}\*\*');
    return text.replaceAllMapped(tokenPattern, (match) {
      final content = match.group(1) ?? '';
      return '**${content.trim()}**';
    });
  }

  List<TextSpan> _buildMessageSpans(String text, TextStyle baseStyle) {
    final boldPattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
    final matches = boldPattern.allMatches(text).toList();

    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    int cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start), style: baseStyle));
      }

      final boldText = match.group(1) ?? '';
      spans.add(
        TextSpan(
          text: boldText,
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ),
      );

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return spans;
  }

  @override
  void initState() {
    super.initState();
    _aiService.initialize();
    _initSpeech();
    
    // Add welcome message
    _messages.add(
      ChatMessage(
        text: "Saya adalah Asisten Keuangan Anda.\n\nFokus utama saya adalah membantu Anda mencatat, memantau, dan menganalisis kesehatan finansial toko Anda dengan cepat dan akurat.\n\nBerikut adalah hal-hal yang bisa saya lakukan untuk Anda:\n • Pencatatan Transaksi: Mencatat pemasukan (penjualan) dan pengeluaran (operasional, restok) secara real-time.\n • Laporan Laba Rugi: Menghitung selisih antara pendapatan dan biaya untuk melihat keuntungan bersih.\n • Arus Kas (Cash Flow): Memantau uang masuk dan keluar agar operasional tetap lancar.\n • Analisis Margin: Memberikan insight mengenai produk mana yang memberikan keuntungan tertinggi.\n • Pengingat Hutang/Piutang: Mencatat tagihan yang harus dibayar atau ditagih kepada supplier/pelanggan.",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<void> _initSpeech() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        _speechAvailable = await _speech.initialize(
          onError: (error) {
            setState(() => _isListening = false);
            _showErrorToast('Speech error: ${error.errorMsg}');
          },
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
        );

        if (_speechAvailable) {
          final locales = await _speech.locales();
          final indonesianLocale = locales.cast<stt.LocaleName?>().firstWhere(
            (locale) {
              final id = (locale?.localeId ?? '').replaceAll('_', '-').toLowerCase();
              return id == 'id-id' || id.startsWith('id-');
            },
            orElse: () => null,
          );
          _speechLocaleId = indonesianLocale?.localeId;
        }

        setState(() {});
      }
    } catch (e) {
      _speechAvailable = false;
    }
  }

  void _startListening() async {
    if (!_speechAvailable) {
      _showErrorToast('Speech recognition not available');
      return;
    }

    if (!_isListening) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _messageController.text = result.recognizedWords;
          });
          
          if (result.finalResult) {
            _stopListening();
            if (_messageController.text.isNotEmpty) {
              _sendMessage();
            }
          }
        },
        listenMode: stt.ListenMode.confirmation,
        localeId: _speechLocaleId,
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(
        ChatMessage(
          text: message,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final response = await _aiService.sendMessage(message);
      final encodedResponse = _encodeModelResponse(response);
      
      setState(() {
        _messages.add(
          ChatMessage(
            text: encodedResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Sorry, I encountered an error: ${e.toString()}',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorToast(String message) {
    showFToast(
      context: context,
      style: .delta(padding: const EdgeInsets.all(16)),
      icon: const Icon(FIcons.circleAlert, color: Colors.red),
      title: const Text('Error'),
      description: Text(message),
      suffixBuilder: (context, entry) =>
          GestureDetector(onTap: entry.dismiss, child: const Icon(FIcons.x)),
      alignment: .topCenter,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        children: [
          // Chat messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: FCard(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                FIcons.sparkles,
                                size: 64,
                                color: context.theme.colors.mutedForeground,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tanyakan sesuatu kepada saya!',
                                textAlign: TextAlign.center,
                                style: context.theme.typography.xl2.copyWith(
                                  color: context.theme.colors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isLoading) {
                        return _buildLoadingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: context.theme.colors.background,
              border: Border(
                top: BorderSide(
                  color: context.theme.colors.border,
                  
                ),
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
                children: [
                  if (_speechAvailable)
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: FButton(
                        onPress: _isListening ? _stopListening : _startListening,
                        variant: _isListening
                            ? FButtonVariant.destructive
                            : FButtonVariant.outline,
                        child: Icon(
                          _isListening ? FIcons.micOff : FIcons.mic,
                          size: 18,
                        ),
                      ),
                    ),
                  if (_speechAvailable) const SizedBox(width: 8),
                  Expanded(
                    child: FTextField(
                      control: FTextFieldControl.managed(
                        controller: _messageController,
                        onChange: (value) {},
                      ),
                      hint: _isListening ? 'Mendengarkan...' : 'Tanyakan apa saja...',
                      enabled: !_isLoading && !_isListening,
                      maxLines: null,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      onSubmit: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
        ],     
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.theme.colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                FIcons.sparkles,
                size: 20,
                color: context.theme.colors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? context.theme.colors.primary
                    : (message.isError
                        ? Colors.red.withOpacity(0.1)
                        : context.theme.colors.secondary),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Builder(
                builder: (context) {
                  final baseStyle = context.theme.typography.base.copyWith(
                    color: message.isUser
                        ? context.theme.colors.secondary
                        : (message.isError
                            ? Colors.red
                            : context.theme.colors.foreground),
                  );

                  if (message.isUser) {
                    return Text(message.text, style: baseStyle);
                  }

                  return RichText(
                    text: TextSpan(
                      children: _buildMessageSpans(message.text, baseStyle),
                    ),
                  );
                },
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.theme.colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                FIcons.user,
                size: 20,
                color: context.theme.colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.theme.colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              FIcons.sparkles,
              size: 20,
              color: context.theme.colors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.theme.colors.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.theme.colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Thinking...',
                  style: context.theme.typography.base.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}
 