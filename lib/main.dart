import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

void main() {
  runApp(const RoboMunchApp());
}

class RoboMunchApp extends StatelessWidget {
  const RoboMunchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoboMunch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RoboMunchHome(),
    );
  }
}

class RoboMunchHome extends StatefulWidget {
  const RoboMunchHome({super.key});
  @override
  State<RoboMunchHome> createState() => _RoboMunchHomeState();
}

const String kLocalBackendUrl = 'http://192.168.1.102:8000';
const String kCloudBackendUrl = 'http://13.61.176.214:8080';

class _RoboMunchHomeState extends State<RoboMunchHome> {
  final String _localUrl = 'http://192.168.1.102:8000';
  final String _cloudUrl = 'http://13.61.176.214:8080';

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _chatController   = TextEditingController();
  final ScrollController _scrollController      = ScrollController();

  Uint8List? _generatedImage;
  Uint8List? _colorizedImage;
  bool _isGenerating  = false;
  bool _isChatLoading = false;
  bool _isColorizing  = false;
  bool _isListening   = false;
  String _statusMessage = '';
  final List<Map<String, String>> _chatMessages = [];

  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => setState(() => _statusMessage = 'Speech error: \$e'),
    );
    setState(() {});
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) {
      setState(() => _statusMessage = 'Speech not available');
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        setState(() => _chatController.text = result.recognizedWords);
      },
      localeId: 'en_US',
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _generateImage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _isGenerating = true;
      _statusMessage = 'Generating image...';
    });
    try {
      final response = await http.post(
        Uri.parse('$_localUrl/generate-image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 600));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _generatedImage = base64Decode(data['image'] as String);
          _colorizedImage = null;
          _statusMessage  = 'Image generated!';
        });
      } else {
        setState(() => _statusMessage = 'Error: \${response.statusCode}');
      }
    } catch (e) {
      setState(() => _statusMessage = 'Connection error: \$e');
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;
    setState(() {
      _chatMessages.add({'role': 'user', 'text': message});
      _chatController.clear();
      _isChatLoading = true;
    });
    _scrollToBottom();
    try {
      final response = await http.post(
        Uri.parse('$_localUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      ).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _chatMessages.add({'role': 'munch', 'text': data['reply'] as String}));
      } else {
        setState(() => _chatMessages.add({'role': 'munch', 'text': 'Error: \${response.statusCode}'}));
      }
    } catch (e) {
      setState(() => _chatMessages.add({'role': 'munch', 'text': 'Connection error: \$e'}));
    } finally {
      setState(() => _isChatLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _colorize() async {
    if (_generatedImage == null) {
      setState(() => _statusMessage = 'Generate an image first!');
      return;
    }
    setState(() {
      _isColorizing = true;
      _statusMessage = 'Converting to grayscale...';
    });
    try {
      final response = await http.post(
        Uri.parse('$_cloudUrl/convert/grayscale'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Encode(_generatedImage!)}),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _colorizedImage = base64Decode(data['image'] as String);
          _statusMessage  = 'Grayscale conversion done!';
        });
      } else {
        setState(() => _statusMessage = 'Cloud error: ' + response.statusCode.toString());
      }
    } catch (e) {
      setState(() => _statusMessage = 'Cloud connection error: \$e');
    } finally {
      setState(() => _isColorizing = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(
          children: [
            Text('ROBO',  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            Text('MUNCH', style: TextStyle(color: Color(0xFFE94560), fontWeight: FontWeight.bold, fontSize: 20)),
            SizedBox(width: 8),
            Text('Art Studio', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildArtStudio(),
            const SizedBox(height: 16),
            _buildChatStudio(),
          ],
        ),
      ),
    );
  }

  Widget _buildArtStudio() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Art Studio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A4A)),
            ),
            child: _isGenerating
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Color(0xFFE94560)), SizedBox(height: 8), Text('Generating...', style: TextStyle(color: Colors.white54))]))
                : _colorizedImage != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_colorizedImage!, fit: BoxFit.contain))
                    : _generatedImage != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_generatedImage!, fit: BoxFit.contain))
                        : const Center(child: Text('Image will appear here', style: TextStyle(color: Colors.white38))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _promptController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Type your prompt here...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0F0F1A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2A4A))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2A2A4A))),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateImage,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE94560), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(_isGenerating ? 'Generating...' : 'Paint'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isColorizing ? null : _colorize,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF533483), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(_isColorizing ? 'Converting...' : 'colorize'),
          ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_statusMessage, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _buildChatStudio() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Chat Studio', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A4A)),
            ),
            child: _chatMessages.isEmpty
                ? const Center(child: Text('Chat messages will appear here', style: TextStyle(color: Colors.white38)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _chatMessages.length + (_isChatLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _chatMessages.length) {
                        return const Padding(padding: EdgeInsets.only(top: 8), child: Row(children: [SizedBox(width: 8), SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE94560))), SizedBox(width: 8), Text('MUNCH is thinking...', style: TextStyle(color: Colors.white38, fontSize: 12))]));
                      }
                      final msg    = _chatMessages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFFE94560) : const Color(0xFF2A2A4A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isUser ? 'YOU' : 'MUNCH', style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(msg['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTapDown: (_) => _startListening(),
                onTapUp:   (_) => _stopListening(),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _isListening ? const Color(0xFFE94560) : const Color(0xFF2A2A4A),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type your message here...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F0F1A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF2A2A4A))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF2A2A4A))),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: const Color(0xFFE94560), borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
