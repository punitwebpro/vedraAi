import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VAttachment {
  final String name;
  final String path;
  final String kind; // image | video | file
  VAttachment(this.name, this.path, this.kind);

  Map<String, dynamic> toJson() => {'n': name, 'p': path, 'k': kind};

  factory VAttachment.fromJson(Map<String, dynamic> j) =>
      VAttachment('${j['n']}', '${j['p']}', '${j['k']}');
}

class VChatMessage {
  final String text;
  final bool isUser;
  final List<VAttachment> attachments;
  VChatMessage(this.text, this.isUser, [this.attachments = const []]);

  Map<String, dynamic> toJson() => {
        't': text,
        'u': isUser,
        'a': attachments.map((a) => a.toJson()).toList(),
      };

  factory VChatMessage.fromJson(Map<String, dynamic> j) => VChatMessage(
        '${j['t']}',
        j['u'] == true,
        ((j['a'] as List?) ?? [])
            .map((e) =>
                VAttachment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class VChatSession {
  String id;
  String title;
  bool pinned;
  bool archived;
  DateTime updatedAt;
  final List<VChatMessage> messages;

  VChatSession({
    String? id,
    this.title = 'New chat',
    this.pinned = false,
    this.archived = false,
    DateTime? updatedAt,
    List<VChatMessage>? messages,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'pinned': pinned,
        'archived': archived,
        'updated': updatedAt.millisecondsSinceEpoch,
        'msgs': messages.map((m) => m.toJson()).toList(),
      };

  factory VChatSession.fromJson(Map<String, dynamic> j) => VChatSession(
        id: '${j['id']}',
        title: '${j['title']}',
        pinned: j['pinned'] == true,
        archived: j['archived'] == true,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (j['updated'] as num?)?.toInt() ?? 0),
        messages: ((j['msgs'] as List?) ?? [])
            .map((e) =>
                VChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class VedraChatScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const VedraChatScreen({super.key, this.onLogout});

  @override
  State<VedraChatScreen> createState() => _VedraChatScreenState();
}

class _VedraChatScreenState extends State<VedraChatScreen> {
  final _controller = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();
  final _speech = SpeechToText();

  final List<VChatSession> _sessions = [];
  late VChatSession _cur;
  final List<VAttachment> _pending = [];
  bool _listening = false;
  bool _speechReady = false;
  bool _typing = false;
  bool _isFirst = false;
  String _query = '';
  String _subtitle = 'Aaj kya banana ya seekhna hai?';

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _name {
    final n = _user?.displayName;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return 'Friend';
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Suprabhat';
    if (h < 17) return 'Namaste';
    if (h < 21) return 'Shubh sandhya';
    return 'Shubh ratri';
  }

  String get _key => 'chats_${_user?.uid ?? 'x'}';

  @override
  void initState() {
    super.initState();
    _cur = VChatSession();
    _sessions.add(_cur);
    _controller.addListener(() => setState(() {}));
    _loadGreeting();
    _loadChats();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    _scroll.dispose();
    _speech.stop();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadGreeting() async {
    const subs = [
      'Aaj kya banana ya seekhna hai?',
      'Main aapki kaise madad kar sakta hoon?',
      'Kahan se shuru karein?',
      'Aaj kis baare mein baat karein?',
      'Kuch bhi poochho, main yahan hoon.',
    ];
    final p = await SharedPreferences.getInstance();
    final key = 'welcomed_${_user?.uid ?? 'x'}';
    final seen = p.getBool(key) ?? false;
    await p.setBool(key, true);
    if (!mounted) return;
    setState(() {
      _isFirst = _isFirst || !seen;
      _subtitle = subs[DateTime.now().second % subs.length];
    });
  }

  Future<void> _loadChats() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) {
        if (mounted) setState(() => _isFirst = true);
        return;
      }
      final list = (jsonDecode(raw) as List)
          .map((e) =>
              VChatSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (!mounted) return;
      setState(() {
        _sessions
          ..clear()
          ..addAll(list);
        _cur = VChatSession();
        _sessions.insert(0, _cur);
        if (list.every((x) => x.messages.isEmpty)) _isFirst = true;
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      final data = _sessions
          .where((s) => s.messages.isNotEmpty)
          .map((s) => s.toJson())
          .toList();
      await p.setString(_key, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pending.isEmpty) return;
    if (_listening) {
      await _speech.stop();
      _listening = false;
    }
    final files = List<VAttachment>.from(_pending);
    final s = _cur;
    setState(() {
      if (s.messages.isEmpty) {
        final t = text.isNotEmpty ? text : files.first.name;
        s.title = t.length > 30 ? '${t.substring(0, 30)}...' : t;
      }
      s.messages.add(VChatMessage(text, true, files));
      s.updatedAt = DateTime.now();
      _pending.clear();
      _controller.clear();
      _typing = true;
    });
    _save();
    _scrollDown();

    // TODO: yahan asli AI API call aayegi. Abhi demo jawab hai.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _typing = false;
      s.messages.add(VChatMessage(
        'Ye abhi demo jawab hai. Jab AI jod denge, yahan asli jawab aayega.',
        false,
      ));
      s.updatedAt = DateTime.now();
    });
    _save();
    _scrollDown();
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (!_speechReady) {
      _speechReady = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    }
    if (!_speechReady) {
      _snack('Mic permission nahi mili ya speech support nahi hai.');
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (r) {
        _controller.text = r.recognizedWords;
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
      },
    );
  }

  Future<void> _pick(String what) async {
    try {
      if (what == 'gallery') {
        final x = await _picker.pickImage(source: ImageSource.gallery);
        if (x != null) _pending.add(VAttachment(x.name, x.path, 'image'));
      } else if (what == 'camera') {
        final x = await _picker.pickImage(source: ImageSource.camera);
        if (x != null) _pending.add(VAttachment(x.name, x.path, 'image'));
      } else if (what == 'video') {
        final x = await _picker.pickVideo(source: ImageSource.gallery);
        if (x != null) _pending.add(VAttachment(x.name, x.path, 'video'));
      } else {
        final f = await FilePicker.pickFile();
        if (f != null && f.path != null) {
          _pending.add(VAttachment(f.name, f.path!, 'file'));
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      _snack('File select nahi ho paayi: $e');
    }
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        Widget item(IconData icon, String label, String key) => ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () {
                Navigator.pop(ctx);
                _pick(key);
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(Icons.photo_outlined, 'Photo (gallery)', 'gallery'),
              item(Icons.photo_camera_outlined, 'Camera', 'camera'),
              item(Icons.videocam_outlined, 'Video', 'video'),
              item(Icons.attach_file, 'File', 'file'),
            ],
          ),
        );
      },
    );
  }

  void _newChat() {
    final empty = _sessions.where((s) => s.messages.isEmpty).toList();
    setState(() {
      _isFirst = true;
      if (empty.isNotEmpty) {
        _cur = empty.first;
      } else {
        _cur = VChatSession();
        _sessions.insert(0, _cur);
      }
      _pending.clear();
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Kya aap logout karna chahte ho?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      widget.onLogout?.call();
    }
  }

  String _groupOf(DateTime d) {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(d.year, d.month, d.day);
    final diff = a.difference(b).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) return 'Previous 7 days';
    return 'Older';
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(yes)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteChat(VChatSession s) async {
    final ok = await _confirm(
        'Delete chat?', 'Ye chat hamesha ke liye hat jayegi.', 'Delete');
    if (!ok) return;
    setState(() {
      _sessions.remove(s);
      if (s == _cur) _isFirst = true;
      if (s == _cur || _sessions.isEmpty) {
        _cur = VChatSession();
        _sessions.insert(0, _cur);
      }
    });
    _save();
  }

  Future<void> _deleteAll() async {
    final ok = await _confirm('Delete all chats?',
        'Saari chats hamesha ke liye hat jayengi.', 'Delete all');
    if (!ok) return;
    setState(() {
      _sessions.clear();
      _isFirst = true;
      _cur = VChatSession();
      _sessions.add(_cur);
    });
    _save();
  }

  Future<void> _chatAction(VChatSession s, String v) async {
    if (v == 'pin') {
      setState(() => s.pinned = !s.pinned);
      _save();
    } else if (v == 'rename') {
      final c = TextEditingController(text: s.title);
      final name = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rename chat'),
          content: TextField(controller: c, autofocus: true),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('Save')),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) {
        setState(() => s.title = name);
        _save();
      }
    } else if (v == 'copy') {
      final buf = StringBuffer();
      for (final m in s.messages) {
        buf.writeln('${m.isUser ? 'Aap' : 'Vedra'}: ${m.text}');
      }
      await Clipboard.setData(ClipboardData(text: buf.toString()));
      _snack('Chat copy ho gayi');
    } else if (v == 'archive') {
      setState(() => s.archived = true);
      if (s == _cur) _newChat();
      _save();
    } else if (v == 'delete') {
      await _deleteChat(s);
    }
  }

  void _showArchived() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final list = _sessions
            .where((s) => s.archived && s.messages.isNotEmpty)
            .toList();
        if (list.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(child: Text('Koi archived chat nahi')),
          );
        }
        return ListView(
          shrinkWrap: true,
          children: [
            for (final s in list)
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(s.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Unarchive',
                      icon: const Icon(Icons.unarchive_outlined),
                      onPressed: () {
                        setState(() => s.archived = false);
                        _save();
                        setSt(() {});
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _deleteChat(s);
                        setSt(() {});
                      },
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vedra'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _newChat,
          ),
        ],
      ),
      drawer: _buildDrawer(cs),
      body: Column(
        children: [
          Expanded(
            child: _cur.messages.isEmpty
                ? _buildEmpty(cs)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _cur.messages.length + (_typing ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _cur.messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Vedra soch raha hai...'),
                          ),
                        );
                      }
                      return _bubble(_cur.messages[i], cs);
                    },
                  ),
          ),
          _buildInput(cs),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    final first = _name.split(' ').first;
    const suggestions = [
      'Ek shayari likho',
      'Business idea do',
      'Padhai mein madad karo',
      'Ek chhoti kahani sunao',
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 44, color: cs.primary),
            const SizedBox(height: 16),
            Text(_isFirst ? 'Welcome, $first!' : '$_greeting, $first',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(_isFirst ? 'Vedra mein aapka swagat hai' : _subtitle),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () {
                      _controller.text = s;
                      _send();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(VChatMessage m, ColorScheme cs) {
    final bg = m.isUser ? cs.primaryContainer : cs.surfaceContainerHighest;
    return Align(
      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in m.attachments) _attachmentView(a),
            if (m.text.isNotEmpty) Text(m.text),
          ],
        ),
      ),
    );
  }

  Widget _attachmentView(VAttachment a) {
    if (a.kind == 'image') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(a.path),
            height: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image_not_supported_outlined, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(a.kind == 'video' ? Icons.videocam : Icons.insert_drive_file,
              size: 18),
          const SizedBox(width: 6),
          Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildInput(ColorScheme cs) {
    final canSend = _controller.text.trim().isNotEmpty || _pending.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pending.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final a in _pending)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          label: SizedBox(
                            width: 110,
                            child: Text(a.name, overflow: TextOverflow.ellipsis),
                          ),
                          onDeleted: () => setState(() => _pending.remove(a)),
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _showAttachSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText:
                            _listening ? 'Sun raha hoon...' : 'Vedra se poochho',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (canSend)
                    IconButton(
                      icon: Icon(Icons.send, color: cs.primary),
                      onPressed: _send,
                    )
                  else
                    IconButton(
                      icon: Icon(
                        _listening ? Icons.stop_circle : Icons.mic_none,
                        color: _listening ? Colors.redAccent : null,
                      ),
                      onPressed: _toggleMic,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatTile(VChatSession s) {
    return ListTile(
      leading: Icon(
        s.pinned ? Icons.push_pin : Icons.chat_bubble_outline,
        size: 20,
      ),
      title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: s == _cur,
      onTap: () {
        Navigator.pop(context);
        setState(() => _cur = s);
        _scrollDown();
      },
      trailing: PopupMenuButton<String>(
        onSelected: (v) => _chatAction(s, v),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'pin', child: Text(s.pinned ? 'Unpin' : 'Pin')),
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          const PopupMenuItem(value: 'copy', child: Text('Copy chat')),
          const PopupMenuItem(value: 'archive', child: Text('Archive')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    final q = _query.trim().toLowerCase();
    bool match(VChatSession s) =>
        q.isEmpty ||
        s.title.toLowerCase().contains(q) ||
        s.messages.any((m) => m.text.toLowerCase().contains(q));
    final list = _sessions
        .where((s) => s.messages.isNotEmpty && !s.archived && match(s))
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (list.isEmpty) {
      return Center(
        child: Text(q.isEmpty ? 'Abhi koi chat nahi' : 'Koi chat nahi mili'),
      );
    }
    final groups = <String, List<VChatSession>>{};
    for (final s in list) {
      final g = s.pinned ? 'Pinned' : _groupOf(s.updatedAt);
      groups.putIfAbsent(g, () => []).add(s);
    }
    const order = ['Pinned', 'Today', 'Yesterday', 'Previous 7 days', 'Older'];
    return ListView(
      children: [
        for (final g in order)
          if (groups.containsKey(g)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(g, style: Theme.of(context).textTheme.labelMedium),
            ),
            for (final s in groups[g]!) _chatTile(s),
          ],
      ],
    );
  }

  Widget _buildDrawer(ColorScheme cs) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: _user?.photoURL != null
                    ? NetworkImage(_user!.photoURL!)
                    : null,
                child: _user?.photoURL == null
                    ? Text(_name.isNotEmpty ? _name[0].toUpperCase() : '?')
                    : null,
              ),
              title: Text(_name),
              subtitle: Text(_user?.email ?? _user?.phoneNumber ?? ''),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New chat'),
              onTap: () {
                Navigator.pop(context);
                _newChat();
              },
            ),
            Expanded(child: _buildHistory()),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archived chats'),
              onTap: () {
                Navigator.pop(context);
                _showArchived();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Delete all chats'),
              onTap: () {
                Navigator.pop(context);
                _deleteAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
