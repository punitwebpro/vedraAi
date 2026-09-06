import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @overrid 
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final stt.SpeechToText speech = stt.SpeechToText();
  final ImagePicker picker = ImagePicker();

  final List<Map<String, dynamic>> messages = [];

  bool listening = false;

  Future<void> mic() async {
    if (!await speech.initialize()) return;

    if (listening) {
      await speech.stop();
      setState(() => listening = false);
    } else {
      setState(() => listening = true);
      await speech.listen(
        onResult: (r) {
          setState(() => controller.text = r.recognizedWords);
        },
      );
    }
  }

  Future<void> attach() async {
    await picker.pickImage(source: ImageSource.gallery);
  }

  void send() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add({'text': text, 'user': true});
      controller.clear();

      messages.add({
        'text':
            'Bilkul. Main Vedra hoon. Aap mujhse history, business, stories aur creative ideas ke baare mein baat kar sakte hain.',
        'user': false,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0F),
        title: const Text(
          '✦ Vedra',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => messages.clear()),
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Hello, मैं Vedra हूँ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'पूछिए, लिखिए या बोलिए...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final m = messages[i];
                      return Align(
                        alignment: m['user']
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          constraints:
                              const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: m['user']
                                ? const Color(0xFF292933)
                                : const Color(0xFF17171D),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            m['text'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF19191F),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: attach,
                    icon: const Icon(Icons.add, color: Colors.white70),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Message Vedra...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: mic,
                    icon: Icon(
                      listening ? Icons.mic : Icons.mic_none,
                      color: listening ? Colors.red : Colors.white70,
                    ),
                  ),
                  IconButton(
                    onPressed: send,
                    icon: const Icon(
                      Icons.arrow_upward,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
