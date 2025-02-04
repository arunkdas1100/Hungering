import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/animations.dart';

class FarmAssistantScreen extends StatefulWidget {
  const FarmAssistantScreen({super.key});

  @override
  State<FarmAssistantScreen> createState() => _FarmAssistantScreenState();
}

class _FarmAssistantScreenState extends State<FarmAssistantScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final model = GenerativeModel(
    model: 'gemini-pro',
    apiKey: 'AIzaSyCoax7u0MmNt4aNsv3oWeSxociT66zNnV8',
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
    
    // Add initial welcome message
    _messages.add(
      ChatMessage(
        text: '''Welcome to Dr.Farm! 👨‍🌾 I'm here to help you with:

1. Weather guidance for farming
2. Crop management advice
3. Fertilizer recommendations
4. Pest control solutions
5. Soil health tips
6. Sustainable farming practices

How can I assist you today?''',
        isBot: true,
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: query, isBot: false));
      _isLoading = true;
      _queryController.clear();
    });
    _scrollToBottom();

    try {
      final prompt = '''You are an expert farming assistant. Provide accurate, practical advice for farmers.
Current query: $query

Guidelines for response:
1. Keep responses concise but informative
2. Include specific, actionable recommendations
3. Consider sustainable farming practices
4. If discussing chemicals/pesticides, mention safety precautions
5. For weather-related queries, explain impact on farming
6. Add relevant emojis to make responses engaging

Respond in a helpful, farmer-friendly manner.''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      
      setState(() {
        _messages.add(ChatMessage(text: response.text ?? 'No response generated. Please try again.', isBot: true));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error. Please try again.',
          isBot: true,
          isError: true,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(
        left: message.isBot ? 8 : 50,
        right: message.isBot ? 50 : 8,
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: message.isBot
            ? (message.isError ? Colors.red[50] : Colors.green[50])
            : Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.isBot)
              Row(
                children: [
                  Icon(
                    message.isError ? Icons.error_outline : Icons.agriculture,
                    size: 20,
                    color: message.isError ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message.isError ? 'Error' : 'Dr.Farm',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: message.isError ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            if (message.isBot) const SizedBox(height: 8),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 16,
                color: message.isError ? Colors.red : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.agriculture,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr.Farm',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Your Smart Farming Assistant',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chat Messages
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(_messages[index]);
                  },
                ),
              ),
            ),

            // Loading Indicator
            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('Dr.Farm is thinking...'),
                  ],
                ),
              ),

            // Input Area
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: 'Ask about farming, weather, or crops...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: const Icon(Icons.send),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isBot;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isBot,
    this.isError = false,
  });
} 