import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/akjol_theme.dart';

class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String senderId;
  final String senderType; // 'courier' or 'customer'
  final String recipientName;
  final String recipientPhone;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.senderId,
    required this.senderType,
    required this.recipientName,
    required this.recipientPhone,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribe();
    // Fallback polling every 3s in case Realtime is not working
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_sending) _loadMessages();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase
          .from('delivery_order_messages')
          .select()
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: true);
      if (mounted) {
        final newList = List<Map<String, dynamic>>.from(data);
        // Only rebuild if there are new messages
        if (newList.length != _messages.length || _loading) {
          setState(() {
            _messages = newList;
            _loading = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Chat load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribe() {
    _channel = _supabase
        .channel('chat_${widget.orderId}_${widget.senderType}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'delivery_order_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (_) {
            // Reload all messages to ensure complete data and no duplicates
            _loadMessages();
          },
        )
        .subscribe();
  }

  Future<void> _sendMessage([String? text]) async {
    final msg = text ?? _msgCtrl.text.trim();
    if (msg.isEmpty || _sending) return;

    setState(() => _sending = true);
    if (text == null) _msgCtrl.clear();

    try {
      await _supabase.from('delivery_order_messages').insert({
        'order_id': widget.orderId,
        'sender_type': widget.senderType,
        'sender_id': widget.senderId,
        'message': msg,
      });
      // Immediately reload to show the sent message
      await _loadMessages();
    } catch (e) {
      debugPrint('Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $e')),
        );
        if (text == null) _msgCtrl.text = msg;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _callRecipient() async {
    final uri = Uri.parse('tel:${widget.recipientPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  List<String> get _quickReplies {
    if (widget.senderType == 'courier') {
      return [
        'Здравствуйте!',
        'Уже еду',
        'Я у подъезда',
        'Позвоните пожалуйста',
      ];
    } else {
      return [
        'Здравствуйте!',
        'Когда будете?',
        'Я на месте',
        'Спасибо!',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AkJolTheme.primary,
                    AkJolTheme.primary.withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.senderType == 'courier'
                    ? Icons.person_rounded
                    : Icons.delivery_dining_rounded,
                color: Colors.white, size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.recipientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('Онлайн',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: AkJolTheme.primary),
            onPressed: _callRecipient,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AkJolTheme.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: AkJolTheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_bubble_outline_rounded,
                                  size: 32, color: AkJolTheme.primary.withValues(alpha: 0.5)),
                            ),
                            const SizedBox(height: 16),
                            Text('Начните диалог',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                )),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final isSystem = (msg['message'] as String?)?.startsWith('Оплата отправлена') == true ||
                              (msg['message'] as String?)?.startsWith('Оплата подтверждена') == true;
                          
                          return isSystem
                              ? _SystemMessage(message: msg)
                              : _MessageBubble(
                                  message: msg,
                                  isMe: msg['sender_type'] == widget.senderType,
                                );
                        },
                      ),
          ),

          // Quick replies
          if (_messages.isEmpty || _messages.length < 3)
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _quickReplies.map((reply) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(reply,
                          style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      backgroundColor: AkJolTheme.primary.withValues(alpha: 0.15),
                      side: BorderSide(color: AkJolTheme.primary.withValues(alpha: 0.3)),
                      onPressed: () => _sendMessage(reply),
                    ),
                  ),
                ).toList(),
              ),
            ),

          // Input
          Container(
            padding: EdgeInsets.fromLTRB(
              12, 10, 12,
              MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Написать сообщение...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sending ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AkJolTheme.primary,
                          AkJolTheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AkJolTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
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

// ═══════════════════════════════════════════════════════════
// SYSTEM MESSAGE
// ═══════════════════════════════════════════════════════════

class _SystemMessage extends StatelessWidget {
  final Map<String, dynamic> message;
  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final text = message['message'] ?? '';
    final time = DateTime.tryParse(message['created_at'] ?? '');
    final timeStr = time != null
        ? '${time.toLocal().hour.toString().padLeft(2, '0')}:${time.toLocal().minute.toString().padLeft(2, '0')}'
        : '';

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AkJolTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AkJolTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AkJolTheme.primary.withValues(alpha: 0.9),
                )),
            const SizedBox(height: 4),
            Text(timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: AkJolTheme.primary.withValues(alpha: 0.5),
                )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// MESSAGE BUBBLE — Dark mode
// ═══════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  bool _isImageUrl(String text) {
    final lower = text.toLowerCase().trim();
    if (!lower.startsWith('http')) return false;
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('/storage/v1/object/');
  }

  @override
  Widget build(BuildContext context) {
    final text = message['message'] ?? '';
    final time = DateTime.tryParse(message['created_at'] ?? '');
    final timeStr = time != null
        ? '${time.toLocal().hour.toString().padLeft(2, '0')}:${time.toLocal().minute.toString().padLeft(2, '0')}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AkJolTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 16,
                  color: AkJolTheme.primary.withValues(alpha: 0.7)),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe
                  ? AkJolTheme.primary
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: isMe
                  ? [BoxShadow(color: AkJolTheme.primary.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isImageUrl(text))
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      text,
                      width: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 220, height: 150,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AkJolTheme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_rounded, size: 16,
                              color: isMe ? Colors.white70 : Colors.grey),
                          const SizedBox(width: 4),
                          Text('Изображение',
                              style: TextStyle(
                                color: isMe ? Colors.white70 : Colors.grey,
                                fontSize: 13,
                              )),
                        ],
                      ),
                    ),
                  )
                else
                  Text(text,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.3,
                      )),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(timeStr,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                        )),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.done_all, size: 14,
                          color: Colors.white.withValues(alpha: 0.6)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
