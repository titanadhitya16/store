import 'package:flutter/material.dart';
import 'dart:convert';
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
  final HtmlEscape _htmlEscape = const HtmlEscape();

  String _encodeModelResponse(String text) {
    final tokenPattern = RegExp(r'\*\*\{([^{}]+)\}\*\*');
    return text.replaceAllMapped(tokenPattern, (match) {
      final content = match.group(1) ?? '';
      final encoded = _htmlEscape.convert(content);
      return '**$encoded**';
    });
  }

  @override
  void initState() {
    super.initState();
    _aiService.initialize();
    _initSpeech();
    
    // Add welcome message
    _messages.add(
      ChatMessage(
        text: "Hello! I'm your StoreHSK inventory assistant. How can I help you today?\n\nYou can ask me about:\n• Inventory status\n• Low stock items\n• Sales reports\n• Item details\n• And more!",
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

  void _clearChat() {
    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        style: style,
        animation: animation,
        title: const Text('Clear Chat'),
        body: const Text('Are you sure you want to clear the chat history?'),
        actions: [
          FButton(
            onPress: () => Navigator.of(context).pop(),
            variant: FButtonVariant.outline,
            child: const Text('Cancel'),
          ),
          FButton(
            onPress: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    text: "Hello! I'm your StoreHSK inventory assistant. How can I help you today?",
                    isUser: false,
                    timestamp: DateTime.now(),
                  ),
                );
              });
              _aiService.resetChat();
              Navigator.of(context).pop();
            },
            variant: FButtonVariant.destructive,
            child: const Text('Clear'),
          ),
        ],
      ),
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FIcons.sparkles,
                        size: 64,
                        color: context.theme.colors.mutedForeground,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ask me anything!',
                        style: context.theme.typography.xl2.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
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
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            child: Row(
              children: [
                // Speech to text button
                if (_speechAvailable)
                  IconButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    icon: Icon(
                      _isListening ? FIcons.micOff : FIcons.mic,
                      color: _isListening ? Colors.red : null,
                    ),
                  ),
                
                const SizedBox(width: 8),
                
                // Text input
                Expanded(
                  child: FTextField(
                    control: FTextFieldControl.managed(
                      controller: _messageController,
                      onChange: (value) {},
                    ),
                    hint: _isListening ? 'Listening...' : 'Ask me anything...',
                    enabled: !_isLoading && !_isListening,
                    maxLines: null,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    onSubmit: (_) => _sendMessage(),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Send button
                IconButton(
                  onPressed: _isLoading || _isListening ? null : _sendMessage,
                  icon: Icon(
                    FIcons.send,
                    color: _isLoading || _isListening
                        ? context.theme.colors.mutedForeground
                        : context.theme.colors.primary,
                  ),
                ),
              ],
            ),
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
              child: Text(
                message.text,
                style: context.theme.typography.base.copyWith(
                  color: message.isUser
                      ? Colors.white
                      : (message.isError
                          ? Colors.red
                          : context.theme.colors.foreground),
                ),
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
 