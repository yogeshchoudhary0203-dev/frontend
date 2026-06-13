// chat_screen.dart
// Features added:
//   • Long-press bottom sheet → quick emoji reactions + Reply + Delete
//   • Reply preview strip in input bar (swipe/tap close to cancel)
//   • Reply quoted-text box inside bubble
//   • Reaction chips below bubble with real-time WebSocket updates
//   • Tap own reaction chip to toggle it off

import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_badge_service.dart';
import '../services/chat_service.dart';
import '../services/fcm_service.dart';
import '../services/agora_service.dart';
import '../services/block_service.dart';
import '../services/report_service.dart';
import '../widgets/report_sheet.dart';
import '../l10n/app_localizations.dart';
import '../utils/error_dialog.dart';
import '../utils/shared_post.dart';
import '../widgets/chat/shared_post_card.dart';
import 'glass_common.dart';
import 'call_screens.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/user_service.dart';


// ── Quick emoji choices ───────────────────────────────────────
const _kQuickEmojis = ['❤️', '😂', '😮', '😢', '🔥', '👏', '🎉', '💯', '👍', '🥺'];

class ChatScreen extends StatefulWidget {
  final bool dark;
  final ChatConversation conversation;
  final String myUserId;

  const ChatScreen({
    super.key,
    required this.dark,
    required this.conversation,
    required this.myUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Color? _customSenderColor;
  Color? _customReceiverColor;
  String _customBgType = 'default';
  Color? _customBgColor;
  String? _customBgImagePath;

  Future<void> _loadCustomBubbleColors() async {
    final prefs = await SharedPreferences.getInstance();
    final senderHex = prefs.getString('chat_sender_bubble_color');
    final receiverHex = prefs.getString('chat_receiver_bubble_color');
    final bgType = prefs.getString('chat_background_type') ?? 'default';
    final bgHex = prefs.getString('chat_background_color');
    final bgImagePath = prefs.getString('chat_background_image_path');

    if (mounted) {
      setState(() {
        _customSenderColor = senderHex != null ? _parseHex(senderHex) : null;
        _customReceiverColor = receiverHex != null ? _parseHex(receiverHex) : null;
        _customBgType = bgType;
        _customBgColor = bgHex != null ? _parseHex(bgHex) : null;
        _customBgImagePath = bgImagePath;
      });
    }
  }

  Color _parseHex(String hex) {
    try {
      String cleanHex = hex.replaceFirst('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return Colors.transparent;
    }
  }

  Widget _buildBackground(bool dark) {
    if (_customBgType == 'image' && _customBgImagePath != null && File(_customBgImagePath!).existsSync()) {
      return Image.file(
        File(_customBgImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_customBgType == 'color' && _customBgColor != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: _customBgColor),
          _blob(dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05), const Alignment(-1, -0.8), 320),
          _blob(dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06), const Alignment( 1, -0.2), 280),
          _blob(dark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04), const Alignment(-0.6, 0.9), 300),
        ],
      );
    }
    return GlassBackdrop(dark: widget.dark);
  }

  Widget _blob(Color c, Alignment a, double size) => Align(
    alignment: a,
    child: IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c, c.withValues(alpha: 0)], stops: const [0, 0.7]),
          ),
        ),
      ),
    ),
  );


  // ── Entrance animation ────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _headerSlide;
  late final Animation<double> _headerFade;
  late final Animation<double> _bodyFade;
  late final Animation<double> _bodyScale;
  late final Animation<Offset> _inputSlide;
  late final Animation<double> _inputFade;
  late final Animation<double> _bgFade;

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isStartingCall = false;
  String? _typingUserId;
  Timer? _typingTimer;
  late StreamSubscription<ChatMessage> _messageSub;
  late StreamSubscription<Map<String, dynamic>> _typingSub;
  late StreamSubscription<Map<String, dynamic>> _reactionSub;
  late StreamSubscription<Map<String, dynamic>> _deletedSub;
  late StreamSubscription<Map<String, dynamic>> _viewOnceSub;
  final Set<String> _animatingIds = {};

  final Set<String> _pendingIds = {};
  ChatMessage? _replyingTo;

  // Older messages pagination — cursor-based (before_id)
  bool _isLoadingOlderMessages = false;
  bool _hasOlderMessages = true;

  @override
  void initState() {
    super.initState();
    _loadCustomBubbleColors();

    // ── Setup entrance animation ────────────────────────────
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Header: slides from -30px top → 0, with fade
    _headerSlide = Tween<double>(begin: -30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    // Message body: scale 0.92→1.0 + fade, slightly delayed
    _bodyFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
      ),
    );
    _bodyScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.15, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    // Input bar: slides from +40px bottom → 0, with fade
    _inputSlide = Tween<Offset>(begin: const Offset(0, 40), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _inputFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOut),
      ),
    );

    // Background subtle fade
    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );

    _entranceCtrl.forward();

    // Tell FCM service which conversation is active so it suppresses
    // redundant notifications while user is viewing this chat.
    FcmService.setActiveConversation(widget.conversation.id);
    _scrollController.addListener(_onChatScroll);
    _loadMessages();
    ChatService().markAsRead(widget.conversation.id);

    _messageSub = ChatService().messageStream.listen((msg) {
      if (!mounted) return;
      if (msg.conversationId == widget.conversation.id) {
        setState(() {
          final existingIndex = _messages.indexWhere((m) => m.id == msg.id);
          if (existingIndex != -1) {
            // Already confirmed — just remove from pending
            _pendingIds.remove(msg.id);
            if (_isDisplayableMessage(msg)) {
              _messages[existingIndex] = msg;
            }
          } else {
            // Check if a pending (optimistic) message matches by sender + time proximity
            final pendingIndex = _messages.indexWhere((m) =>
                _pendingIds.contains(m.id) &&
                m.senderId == msg.senderId &&
                msg.createdAt.difference(m.createdAt).abs().inSeconds < 10);

            if (pendingIndex != -1) {
              final pending = _messages[pendingIndex];
              _pendingIds.remove(pending.id);
              _messages[pendingIndex] = _confirmedFromPending(pending, msg);
            } else if (_isDisplayableMessage(msg)) {
              _messages.insert(0, msg);
              _animatingIds.add(msg.id);
              // Clear animation flag after it plays
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) setState(() => _animatingIds.remove(msg.id));
              });
            }
          }
          if (msg.senderId == _typingUserId) _typingUserId = null;
        });
        ChatService().markAsRead(widget.conversation.id);
      }
    });

    // On WS reconnect, sync messages that arrived while disconnected
    ChatService().presenceStream.listen((_) {
      // presenceStream fires on any presence event — if WS just reconnected,
      // sync to pick up any messages we missed during the disconnect gap
      if (mounted && _messages.isNotEmpty) {
        _syncMissedMessages();
      }
    });

    _typingSub = ChatService().typingStream.listen((event) {
      if (!mounted) return;
      if (event['conversation_id'] == widget.conversation.id &&
          event['user_id'] != widget.myUserId) {
        setState(() => _typingUserId = event['user_id'] as String?);
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _typingUserId = null);
        });
      }
    });

    _reactionSub = ChatService().reactionStream.listen((event) {
      if (!mounted) return;
      if (event['conversation_id'] != widget.conversation.id) return;
      final msgId     = event['message_id'] as String;
      final reactions = event['reactions'] as Map<String, List<String>>;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == msgId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWithReactions(reactions);
        }
      });
    });

    _deletedSub = ChatService().deletedStream.listen((event) {
      if (!mounted) return;
      if (event['conversation_id'] != widget.conversation.id) return;
      final msgId = event['message_id'] as String;
      setState(() {
        _messages.removeWhere((m) => m.id == msgId);
        _pendingIds.remove(msgId);
      });
    });

    _viewOnceSub = ChatService().viewOnceStream.listen((event) {
      if (!mounted) return;
      if (event['conversation_id'] != widget.conversation.id) return;
      final msgId = event['message_id'] as String;
      final viewedBy = List<String>.from(event['view_once_viewed_by'] as List? ?? []);
      final mediaErased = event['media_erased'] as bool? ?? false;
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == msgId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWithViewOnce(
            viewOnceViewedBy: viewedBy,
            clearMediaUrl: mediaErased,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    // Clear active conversation so notifications resume for this chat
    FcmService.setActiveConversation(null);
    // This conversation was just read → its unread reset; refresh the icon badge.
    AppBadgeService.refresh();
    _entranceCtrl.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _messageSub.cancel();
    _typingSub.cancel();
    _reactionSub.cancel();
    _deletedSub.cancel();
    _viewOnceSub.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final convId = widget.conversation.id;

    // Step 1: Show in-memory cache instantly (zero latency)
    final cached = ChatService().getCachedMessages(convId);
    if (cached.isNotEmpty && mounted) {
      final displayable = cached.where(_isDisplayableMessage).toList();
      if (displayable.isNotEmpty) {
        setState(() {
          _messages = displayable;
          _isLoading = false;
        });
      }
    }

    // Step 2: Get messages — returns local DB instantly if available,
    // then silently fetches fresh from API via onRefreshed callback.
    try {
      final msgs = await ChatService().getMessages(
        convId,
        limit: 30,
        onRefreshed: (fresh) {
          // Called when background API refresh completes
          if (!mounted) return;
          final freshDisplayable = fresh.where(_isDisplayableMessage).toList();
          final freshIds = freshDisplayable.map((m) => m.id).toSet();
          final pendingMsgs = _messages
              .where((m) => _pendingIds.contains(m.id) && !freshIds.contains(m.id))
              .toList();
          setState(() {
            _messages = [...pendingMsgs, ...freshDisplayable];
            _hasOlderMessages = fresh.length >= 30;
          });
        },
      );
      if (!mounted) return;
      final freshDisplayable = msgs.where(_isDisplayableMessage).toList();
      final freshIds = freshDisplayable.map((m) => m.id).toSet();
      final pendingMsgs = _messages
          .where((m) => _pendingIds.contains(m.id) && !freshIds.contains(m.id))
          .toList();
      setState(() {
        _messages = [...pendingMsgs, ...freshDisplayable];
        _isLoading = false;
        _hasError = false;
        _hasOlderMessages = msgs.length >= 30;
      });
    } catch (_) {
      if (mounted && _messages.isEmpty) {
        setState(() { _isLoading = false; _hasError = true; });
      } else if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  /// Fetch messages that arrived while WS was disconnected.
  Future<void> _syncMissedMessages() async {
    if (_messages.isEmpty) return;
    final newestId = _messages.first.id;
    if (newestId.startsWith('temp_')) return;
    final missed = await ChatService().syncMessagesAfter(widget.conversation.id, newestId);
    if (!mounted || missed.isEmpty) return;
    final newOnes = missed
        .where(_isDisplayableMessage)
        .where((m) => !_messages.any((e) => e.id == m.id))
        .toList();
    if (newOnes.isNotEmpty) {
      setState(() => _messages.insertAll(0, newOnes));
    }
  }

  void _onChatScroll() {
    // In a reversed ListView, maxScrollExtent is the visual top (oldest messages).
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlderMessages || !_hasOlderMessages || _messages.isEmpty) return;

    // Find oldest real (non-pending) message for cursor
    final oldestReal = _messages.lastWhere(
      (m) => !m.id.startsWith('temp_'),
      orElse: () => _messages.last,
    );
    if (oldestReal.id.startsWith('temp_')) return;

    setState(() => _isLoadingOlderMessages = true);
    try {
      final older = await ChatService().getMessages(
        widget.conversation.id,
        beforeId: oldestReal.id,  // cursor-based — no skip mismatch
        limit: 30,
      );
      final displayable = older
          .where(_isDisplayableMessage)
          .where((m) => !_messages.any((e) => e.id == m.id))
          .toList();
      if (mounted) {
        setState(() {
          _messages.addAll(displayable);
          _hasOlderMessages = older.length >= 30;
          _isLoadingOlderMessages = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOlderMessages = false);
    }
  }

  ChatMessage _confirmedFromPending(ChatMessage pending, ChatMessage confirmed) {
    return ChatMessage(
      id: confirmed.id,
      conversationId: confirmed.conversationId,
      senderId: confirmed.senderId,
      text: pending.text,
      createdAt: confirmed.createdAt,
      readBy: confirmed.readBy,
      encryptedAesKeys: confirmed.encryptedAesKeys,
      reactions: confirmed.reactions,
      replyToId: pending.replyToId,
      replyToText: pending.replyToText,
      mediaUrl: confirmed.mediaUrl,
      mediaType: confirmed.mediaType,
      mediaPublicId: confirmed.mediaPublicId,
      isViewOnce: confirmed.isViewOnce,
      viewOnceViewedBy: confirmed.viewOnceViewedBy,
    );
  }

  bool _isDisplayableMessage(ChatMessage msg) {
    if (msg.isViewOnce) return true;
    final text = msg.text.trim();
    if (text.isEmpty) return false;
    if (text.startsWith('[Decryption error:') ||
        text.contains('Decryption error:') ||
        text == '[Encrypted Message]') {
      return false;
    }
    return !_looksLikeEncryptedPayload(text);
  }

  bool _looksLikeEncryptedPayload(String text) {
    final n = text.replaceAll(RegExp(r'\s+'), '');
    return n.startsWith('{"ct":') && n.contains('"iv":') && n.endsWith('}');
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Block check — show clean pop-up if other user is blocked
    final otherUser = widget.conversation.getOtherParticipant(widget.myUserId);
    if (BlockService.instance.isBlocked(otherUser.id)) {
      _showBlockedDialog(otherUser.username);
      return;
    }

    final sentAt  = DateTime.now();
    final tempId  = 'temp_${sentAt.millisecondsSinceEpoch}';
    final replyTo = _replyingTo;

    final optimistic = ChatMessage(
      id: tempId,
      conversationId: widget.conversation.id,
      senderId: widget.myUserId,
      text: text,
      createdAt: sentAt,
      readBy: [widget.myUserId],
      replyToId: replyTo?.id,
      replyToText: replyTo?.text,
    );

    setState(() {
      _messages.insert(0, optimistic);
      _pendingIds.add(tempId);
      _replyingTo = null;
    });

    _textController.clear();
    HapticFeedback.lightImpact();

    ChatService().sendMessage(
      widget.conversation.id, text, widget.conversation.participants,
      createdAt: sentAt, replyToId: replyTo?.id, replyToText: replyTo?.text,
    );
  }

  void _showAttachmentOptions() {
    final fg = GlassTokens.fg(widget.dark);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.dark
                        ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: widget.dark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: widget.dark ? 0.5 : 0.10),
                        blurRadius: 20, offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SheetTile(
                        dark: widget.dark,
                        icon: Icons.image_rounded,
                        label: 'Send Photo',
                        fg: fg,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickAndSendMedia(ImageSource.gallery, isVideo: false, isViewOnce: false);
                        },
                      ),
                      Divider(
                        height: 1, indent: 56,
                        color: widget.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      _SheetTile(
                        dark: widget.dark,
                        icon: Icons.image_outlined,
                        label: 'Send Photo (View Once)',
                        fg: fg,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickAndSendMedia(ImageSource.gallery, isVideo: false, isViewOnce: true);
                        },
                      ),
                      Divider(
                        height: 1, indent: 56,
                        color: widget.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      _SheetTile(
                        dark: widget.dark,
                        icon: Icons.video_camera_back_rounded,
                        label: 'Send Video',
                        fg: fg,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickAndSendMedia(ImageSource.gallery, isVideo: true, isViewOnce: false);
                        },
                      ),
                      Divider(
                        height: 1, indent: 56,
                        color: widget.dark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      _SheetTile(
                        dark: widget.dark,
                        icon: Icons.video_camera_front_outlined,
                        label: 'Send Video (View Once)',
                        fg: fg,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickAndSendMedia(ImageSource.gallery, isVideo: true, isViewOnce: true);
                        },
                      ),

                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendMedia(ImageSource source, {required bool isVideo, bool isViewOnce = false}) async {
    final picker = ImagePicker();
    XFile? pickedFile;
    try {
      if (isVideo) {
        pickedFile = await picker.pickVideo(source: source);
      } else {
        pickedFile = await picker.pickImage(source: source);
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: 'Could not pick media: $e');
      }
      return;
    }

    if (pickedFile == null) return;
    final file = File(pickedFile.path);

    // Show loading spinner
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Upload to CDN via ChatService().uploadChatMedia
      final uploadResult = await ChatService().uploadChatMedia(file);
      final mediaUrl = uploadResult['url'] as String;
      final mediaPublicId = uploadResult['public_id'] as String;
      final mediaType = uploadResult['media_type'] as String; // "image" or "video"

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // 2. Send message
      final sentAt = DateTime.now();
      final tempId = 'temp_${sentAt.millisecondsSinceEpoch}';

      final optimistic = ChatMessage(
        id: tempId,
        conversationId: widget.conversation.id,
        senderId: widget.myUserId,
        text: '[MEDIA]',
        createdAt: sentAt,
        readBy: [widget.myUserId],
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        mediaPublicId: mediaPublicId,
        isViewOnce: isViewOnce,
        viewOnceViewedBy: isViewOnce ? [widget.myUserId] : const [],
      );

      setState(() {
        _messages.insert(0, optimistic);
        _pendingIds.add(tempId);
      });

      HapticFeedback.lightImpact();

      await ChatService().sendMessage(
        widget.conversation.id,
        '[MEDIA]',
        widget.conversation.participants,
        createdAt: sentAt,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        mediaPublicId: mediaPublicId,
        isViewOnce: isViewOnce,
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading
        showErrorDialog(context, message: 'Could not send media: $e');
      }
    }
  }


  void _showBlockedDialog(String username) {
    final dark = widget.dark;
    final fg   = GlassTokens.fg(dark);
    final sub  = GlassTokens.sub(dark);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AlertDialog(
          backgroundColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Icon(Icons.block_rounded, color: Colors.redAccent, size: 36),
          title: Text(
            'Blocked',
            textAlign: TextAlign.center,
            style: manrope(size: 17, weight: FontWeight.w800, color: fg),
          ),
          content: Text(
            'You have blocked @$username.\nUnblock them to send messages.',
            textAlign: TextAlign.center,
            style: manrope(size: 13, weight: FontWeight.w500, color: sub),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK', style: manrope(size: 14, weight: FontWeight.w700, color: fg)),
            ),
          ],
        ),
      ),
    );
  }

  void _onTyping(String text) {
    if (text.isNotEmpty) ChatService().sendTyping(widget.conversation.id);
  }

  void _onReact(ChatMessage msg, String emoji) {
    HapticFeedback.selectionClick();
    ChatService().sendReaction(widget.conversation.id, msg.id, emoji);

    setState(() {
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx == -1) return;
      final current = Map<String, List<String>>.from(
        _messages[idx].reactions.map((k, v) => MapEntry(k, List<String>.from(v))),
      );
      final users = current[emoji] ?? [];
      if (users.contains(widget.myUserId)) {
        users.remove(widget.myUserId);
        if (users.isEmpty) current.remove(emoji);
      } else {
        users.add(widget.myUserId);
        current[emoji] = users;
      }
      _messages[idx] = _messages[idx].copyWithReactions(current);
    });
  }

  // ── Instagram-style emoji reaction bottom sheet ──────────────
  void _showMessageOptions(ChatMessage msg) {
    HapticFeedback.mediumImpact();
    final isMe = msg.senderId == widget.myUserId;
    final fg   = GlassTokens.fg(widget.dark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── Instagram-style emoji pill ─────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: widget.dark
                            ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: widget.dark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: widget.dark ? 0.5 : 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _kQuickEmojis.map((emoji) {
                            final alreadyReacted =
                                (msg.reactions[emoji] ?? []).contains(widget.myUserId);
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _onReact(msg, emoji);
                              },
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 1.0, end: alreadyReacted ? 1.15 : 1.0),
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.elasticOut,
                                builder: (_, scale, child) => Transform.scale(
                                  scale: scale, child: child,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: alreadyReacted
                                        ? (widget.dark
                                            ? Colors.white.withValues(alpha: 0.18)
                                            : const Color(0xFF0095F6).withValues(alpha: 0.12))
                                        : Colors.transparent,
                                    border: alreadyReacted
                                        ? Border.all(
                                            color: widget.dark
                                                ? Colors.white.withValues(alpha: 0.35)
                                                : const Color(0xFF0095F6).withValues(alpha: 0.5),
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      height: 1.0,
                                      fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Options menu ───────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.dark
                            ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: widget.dark
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.06),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: widget.dark ? 0.5 : 0.10),
                            blurRadius: 20, offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SheetTile(
                            dark: widget.dark,
                            icon: Icons.reply_rounded,
                            label: 'Reply',
                            fg: fg,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => _replyingTo = msg);
                            },
                          ),
                          if (msg.mediaUrl != null && !msg.isViewOnce) ...[
                            Divider(
                              height: 1, indent: 56,
                              color: widget.dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                            _SheetTile(
                              dark: widget.dark,
                              icon: Icons.archive_outlined,
                              label: 'Archive to Profile',
                              fg: fg,
                              onTap: () {
                                Navigator.pop(ctx);
                                _archiveMessageMedia(msg);
                              },
                            ),
                          ],
                          if (isMe) ...[
                            Divider(
                              height: 1, indent: 56,
                              color: widget.dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                            _SheetTile(
                              dark: widget.dark,
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              fg: Colors.red,
                              onTap: () {
                                Navigator.pop(ctx);
                                _deleteMessage(msg.id);
                              },
                            ),
                          ],
                          if (!isMe) ...[
                            Divider(
                              height: 1, indent: 56,
                              color: widget.dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            ),
                            _SheetTile(
                              dark: widget.dark,
                              icon: Icons.outlined_flag_rounded,
                              label: 'Report',
                              fg: Colors.red,
                              onTap: () {
                                Navigator.pop(ctx);
                                showReportSheet(
                                  context,
                                  targetType: ReportService.targetUser,
                                  targetId: msg.senderId,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _archiveMessageMedia(ChatMessage msg) async {
    if (msg.mediaUrl == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Archiving media...'),
        duration: Duration(seconds: 1),
      ),
    );

    final success = await UserService.archiveMedia(msg.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to your Archive successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to archive media (already archived or invalid message).'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }


  // ── Agora Call Methods ─────────────────────────────────────────
  // Flow: send call_invite (callee sees IncomingCallScreen) → open call screen here ("Ringing…")
  void _showCallStartError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not start call. Check your connection.')),
    );
  }

  Future<bool> _ensureCallSocketReady() async {
    if (ChatService().isConnected) return true;
    await ChatService().connectWebSocket();
    return ChatService().isConnected;
  }

  Future<void> _startVoiceCall() async {
    if (_isStartingCall) return;
    HapticFeedback.lightImpact();
    setState(() => _isStartingCall = true);
    final otherUser   = widget.conversation.getOtherParticipant(widget.myUserId);
    final channelName = AgoraService.buildChannelName(widget.myUserId, otherUser.id);
    final ready = await _ensureCallSocketReady();
    if (!mounted) return;
    if (!ready) {
      setState(() => _isStartingCall = false);
      _showCallStartError();
      return;
    }
    final sent = ChatService().sendCallInvite(
      calleeId:    otherUser.id,
      channelName: channelName,
      callType:    'voice',
      callerName:  '',
    );
    if (!sent) {
      setState(() => _isStartingCall = false);
      _showCallStartError();
      return;
    }
    setState(() => _isStartingCall = false);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, _) => FadeTransition(
          opacity: anim,
          child: VoiceCallScreen(
            dark:           widget.dark,
            channelName:    channelName,
            remoteUserName: otherUser.username,
            myUserId:       widget.myUserId,
            remoteUserId:   otherUser.id,
            isCallee:       false,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _startVideoCall() async {
    if (_isStartingCall) return;
    HapticFeedback.lightImpact();
    setState(() => _isStartingCall = true);
    final otherUser   = widget.conversation.getOtherParticipant(widget.myUserId);
    final channelName = AgoraService.buildChannelName(widget.myUserId, otherUser.id);
    final ready = await _ensureCallSocketReady();
    if (!mounted) return;
    if (!ready) {
      setState(() => _isStartingCall = false);
      _showCallStartError();
      return;
    }
    final sent = ChatService().sendCallInvite(
      calleeId:    otherUser.id,
      channelName: channelName,
      callType:    'video',
      callerName:  '',
    );
    if (!sent) {
      setState(() => _isStartingCall = false);
      _showCallStartError();
      return;
    }
    setState(() => _isStartingCall = false);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, anim, _) => FadeTransition(
          opacity: anim,
          child: VideoCallScreen(
            dark:           widget.dark,
            channelName:    channelName,
            remoteUserName: otherUser.username,
            myUserId:       widget.myUserId,
            remoteUserId:   otherUser.id,
            isCallee:       false,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _deleteConversation() async {
    final confirm = await showGlassConfirmDialog(
      context,
      title: 'Delete Chat'.tr(context),
      message: 'Delete this conversation? This cannot be undone.'.tr(context),
      confirmLabel: 'Delete'.tr(context),
      cancelLabel: 'Cancel'.tr(context),
      destructive: true,
    );
    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await ChatService().deleteConversation(widget.conversation.id);
      if (mounted) { Navigator.pop(context); Navigator.pop(context, true); }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showErrorDialog(context, message: 'Could not delete: $e');
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirm = await showGlassConfirmDialog(
      context,
      title: 'Delete Message'.tr(context),
      message: 'Delete this message for everyone?'.tr(context),
      confirmLabel: 'Delete'.tr(context),
      cancelLabel: 'Cancel'.tr(context),
      destructive: true,
    );
    if (confirm != true) return;
    try {
      await ChatService().deleteMessage(widget.conversation.id, messageId);
      if (mounted) setState(() => _messages.removeWhere((m) => m.id == messageId));
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, message: 'Could not delete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(widget.dark);
    final sub = GlassTokens.sub(widget.dark);

    final topPad    = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    final navPad    = MediaQuery.paddingOf(context).bottom;

    const headerH = 66.0;
    const inputH  = 54.0;
    const replyH  = 52.0;
    final headerTop = topPad + 8;

    final effectiveInputH = inputH + (_replyingTo != null ? replyH + 8 : 0);

    final otherUser = widget.conversation.getOtherParticipant(widget.myUserId);

    // Build message list as a stable child — AnimatedBuilder will NOT rebuild
    // this on every animation tick, only on setState (new message/reaction).
    final msgListChild = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _hasError
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Could not load messages'.tr(context), style: manrope(size: 14, color: sub)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _loadMessages, child: Text('Retry'.tr(context))),
                ]),
              )
            : ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                addAutomaticKeepAlives: false,
                itemCount: _messages.length +
                    (_typingUserId != null ? 1 : 0) +
                    1 +
                    (_isLoadingOlderMessages ? 1 : 0),
                itemBuilder: (context, index) {
                  final typingOffset = _typingUserId != null ? 1 : 0;
                  final bannerIndex = _messages.length + typingOffset;
                  final loadingIndex = bannerIndex + 1;

                  // Loading older messages spinner (visually topmost)
                  if (_isLoadingOlderMessages && index == loadingIndex) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.dark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  }

                  // 🔒 E2E banner
                  if (index == bannerIndex) {
                    return _E2EBanner(dark: widget.dark);
                  }
                  if (_typingUserId != null) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: _BubbleTyping(dark: widget.dark, sub: sub),
                      );
                    }
                    index--;
                  }

                  final msg       = _messages[index];
                  final isMe      = msg.senderId == widget.myUserId;
                  final isPending = _pendingIds.contains(msg.id);

                  bool last = true;
                  if (index > 0) {
                    final newer = _messages[index - 1];
                    if (newer.senderId == msg.senderId) last = false;
                  }

                  // ValueKey stabilises element identity when messages are
                  // inserted at index 0 — prevents full list rebuild on each send.
                  final isAnimating = _animatingIds.contains(msg.id);
                  Widget bubble = Padding(
                    key: ValueKey(msg.id),
                    padding: const EdgeInsets.only(bottom: 3),
                    child: SwipeToReply(
                      dark: widget.dark,
                      onReply: () => setState(() => _replyingTo = msg),
                      child: GestureDetector(
                        onLongPress: () => _showMessageOptions(msg),
                        child: _Bubble(
                          m: msg, isMe: isMe, dark: widget.dark,
                          last: last, isPending: isPending,
                          myUserId: widget.myUserId,
                          onReact: (emoji) => _onReact(msg, emoji),
                          customSenderColor: _customSenderColor,
                          customReceiverColor: _customReceiverColor,
                          onViewOnceOpened: () {
                            setState(() {
                              final idx = _messages.indexWhere((element) => element.id == msg.id);
                              if (idx != -1) {
                                final updatedViewedBy = List<String>.from(_messages[idx].viewOnceViewedBy)..add(widget.myUserId);
                                _messages[idx] = _messages[idx].copyWithViewOnce(
                                  viewOnceViewedBy: updatedViewedBy,
                                  clearMediaUrl: true, // clear immediately locally
                                );
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  );
                  // Slide + fade in for newly received messages
                  if (isAnimating) {
                    bubble = TweenAnimationBuilder<double>(
                      key: ValueKey('anim_${msg.id}'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Transform.translate(
                        offset: Offset(isMe ? (1 - v) * 24 : (v - 1) * 24, 0),
                        child: Opacity(opacity: v, child: child),
                      ),
                      child: bubble,
                    );
                  }
                  return bubble;
                },
              );

    return AnimatedBuilder(
      animation: _entranceCtrl,
      child: msgListChild,
      builder: (context, child) => Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: widget.dark ? GlassTokens.bgDark : GlassTokens.bgLight,
      body: Stack(children: [
        Opacity(
          opacity: _bgFade.value,
          child: _buildBackground(widget.dark),
        ),

        // ── Messages list ──────────────────────────────────────
        Positioned(
          top: headerTop + headerH,
          bottom: effectiveInputH + 16 + bottomPad + navPad,
          left: 0, right: 0,
          child: Opacity(
            opacity: _bodyFade.value,
            child: Transform.scale(
              scale: _bodyScale.value,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),

        // ── Header ─────────────────────────────────────────────
        Positioned(
          top: headerTop + _headerSlide.value, left: 12, right: 12,
          child: Opacity(
            opacity: _headerFade.value,
            child: GlassHeader(
            dark: widget.dark,
            height: headerH,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: fg, size: 18),
                ),
              ),
              UserAvatar(
                pictureUrl: otherUser.picture,
                name: otherUser.name.isNotEmpty ? otherUser.name : otherUser.username,
                size: 38,
                dark: widget.dark,
                index: 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(otherUser.username,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: manrope(size: 15, weight: FontWeight.w800, color: fg, letterSpacing: -0.225)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(
                        ChatService().isConnected ? 'Active now' : 'Connecting…',
                        style: manrope(size: 11, weight: FontWeight.w500, color: sub),
                      ),
                      const SizedBox(width: 6),
                      Container(width: 3, height: 3,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: sub)),
                      const SizedBox(width: 6),
                      Icon(Icons.lock_outline_rounded, size: 10, color: sub),
                      const SizedBox(width: 2),
                      Text('E2EE',
                          style: manrope(size: 9.5, weight: FontWeight.w700, color: sub, letterSpacing: 0.5)),
                    ]),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _startVoiceCall(),
                child: GlassCircleButton(dark: widget.dark, icon: Icons.call_outlined, iconSize: 18),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _startVideoCall(),
                child: GlassCircleButton(dark: widget.dark, icon: Icons.videocam_outlined, iconSize: 20),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _deleteConversation,
                child: GlassCircleButton(dark: widget.dark, icon: Icons.delete_outline_rounded, iconSize: 18, fg: Colors.red),
              ),
            ]),
          ),
          ),
        ),

        // ── Input bar + reply strip ─────────────────────────────
        Positioned(
          bottom: bottomPad + navPad + 8,
          left: 12, right: 12,
          child: Transform.translate(
            offset: _inputSlide.value,
            child: Opacity(
              opacity: _inputFade.value,
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Reply preview strip (input box ke upar) ───────
              if (_replyingTo != null)
                _ReplyPreview(
                  dark: widget.dark,
                  text: _replyingTo!.text,
                  height: replyH,
                  onCancel: () => setState(() => _replyingTo = null),
                ),

              // ── Text input ────────────────────────────────────
              SizedBox(
                height: inputH,
                child: GlassSurface(
                  dark: widget.dark,
                  radius: 999,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  blurSigma: 28,
                  shadow: BoxShadow(
                    color: widget.dark
                        ? Colors.black.withValues(alpha: 0.6)
                        : const Color(0xFF14161E).withValues(alpha: 0.20),
                    blurRadius: 30, offset: const Offset(0, -10), spreadRadius: -16,
                  ),
                  child: Row(children: [
                    const SizedBox(width: 2),
                    GlassCircleButton(
                      dark: widget.dark, icon: Icons.add_rounded,
                      size: 38, iconSize: 22,
                      bg: widget.dark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                      onTap: _showAttachmentOptions,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onChanged: _onTyping,
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                        style: manrope(size: 14, weight: FontWeight.w500,
                            color: GlassTokens.fg(widget.dark), letterSpacing: -0.07),
                        decoration: InputDecoration(
                          hintText: _replyingTo != null ? 'Write a reply…' : 'Message…',
                          hintStyle: manrope(size: 14, weight: FontWeight.w500,
                              color: GlassTokens.sub(widget.dark), letterSpacing: -0.07),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: GlassCircleButton(
                        dark: widget.dark, icon: Icons.send_rounded,
                        size: 38, iconSize: 18,
                        bg: widget.dark ? Colors.white : const Color(0xFF0A0A0A),
                        fg: widget.dark ? const Color(0xFF0A0A0A) : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                  ]),
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ]),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reply preview strip — above the input bar
// Fully opaque, clearly visible on any background (dark or light)
// ─────────────────────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final bool dark;
  final String text;
  final double height;
  final VoidCallback onCancel;

  const _ReplyPreview({
    required this.dark, required this.text,
    required this.height, required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final accentBar  = dark ? Colors.white        : const Color(0xFF0A0A0A);
    final labelColor = dark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);
    final textColor  = dark ? Colors.white        : Colors.black87;
    final closeColor = dark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.35);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: height,
          margin: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
          decoration: BoxDecoration(
            // 0.95 opacity → fully readable on glass backdrop
            color: dark
                ? const Color(0xFF2A2A2E).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.40 : 0.10),
                blurRadius: 16, offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Container(
              width: 3.5, height: 28,
              decoration: BoxDecoration(color: accentBar, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Icon(Icons.reply_rounded, size: 15, color: accentBar.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Replying to'.tr(context),
                      style: manrope(size: 10.5, weight: FontWeight.w700, color: labelColor)),
                  const SizedBox(height: 2),
                  Text(text,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: manrope(size: 13, weight: FontWeight.w600, color: textColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onCancel,
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.07),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.close_rounded, size: 14, color: closeColor),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bubble
// ─────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage m;
  final bool isMe;
  final bool dark;
  final bool last;
  final bool isPending;
  final String myUserId;
  final void Function(String emoji) onReact;
  final Color? customSenderColor;
  final Color? customReceiverColor;
  final VoidCallback? onViewOnceOpened;

  const _Bubble({
    required this.m, required this.isMe, required this.dark,
    required this.last, required this.myUserId, required this.onReact,
    this.isPending = false,
    this.customSenderColor,
    this.customReceiverColor,
    this.onViewOnceOpened,
  });

  @override
  Widget build(BuildContext context) {
    final fg  = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20), bottomRight: Radius.circular(6))
        : const BorderRadius.only(
            topLeft: Radius.circular(20), topRight: Radius.circular(20),
            bottomLeft: Radius.circular(6), bottomRight: Radius.circular(20));

    final localTime = m.createdAt.toLocal();
    final hour12 = localTime.hour == 0 ? 12 : (localTime.hour > 12 ? localTime.hour - 12 : localTime.hour);
    final amPm = localTime.hour < 12 ? 'AM' : 'PM';
    final timeStr = '${hour12.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')} $amPm';
    final read = m.readBy.length > 1;

    final visibleReactions =
        m.reactions.entries.where((e) => e.value.isNotEmpty).toList();

    return Opacity(
      opacity: isPending ? 0.65 : 1.0,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Reply quote (renders above bubble, needs own solid bg) ──
              if (m.replyToId != null && m.replyToText != null && m.replyToText!.isNotEmpty)
                _ReplyQuote(text: m.replyToText!, isMe: isMe, dark: dark),

              // ── Main bubble ────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _bubbleBox(context, dark, radius, sub, fg),

                  // ── Instagram-style reaction chips ─────────
                  if (visibleReactions.isNotEmpty)
                    Positioned(
                      bottom: -13,
                      right: isMe ? 6 : null,
                      left: isMe ? null : 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: visibleReactions.map((entry) {
                          final emoji         = entry.key;
                          final count         = entry.value.length;
                          final hasMyReaction = entry.value.contains(myUserId);

                          return GestureDetector(
                            onTap: () => onReact(emoji),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: dark
                                    ? (hasMyReaction
                                        ? Colors.white.withValues(alpha: 0.22)
                                        : const Color(0xFF2C2C2E))
                                    : (hasMyReaction
                                        ? const Color(0xFFE8F4FD)
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: dark
                                      ? (hasMyReaction
                                          ? Colors.white.withValues(alpha: 0.40)
                                          : Colors.white.withValues(alpha: 0.12))
                                      : (hasMyReaction
                                          ? const Color(0xFF0095F6).withValues(alpha: 0.40)
                                          : Colors.black.withValues(alpha: 0.08)),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
                                    blurRadius: 8, offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(emoji,
                                      style: const TextStyle(
                                        fontSize: 15, height: 1.0,
                                        fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
                                      )),
                                  if (count > 1) ...[
                                    const SizedBox(width: 4),
                                    Text('$count',
                                        style: manrope(
                                          size: 11.5, weight: FontWeight.w700,
                                          color: dark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                                        )),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),

              if (visibleReactions.isNotEmpty) const SizedBox(height: 8),

              // ── Timestamp + status ─────────────────────────
              if (last)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(timeStr,
                        style: manrope(size: 10.5, weight: FontWeight.w500,
                            color: sub, letterSpacing: -0.05)),
                    if (m.encryptedAesKeys.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_rounded, size: 9, color: sub.withValues(alpha: 0.6)),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 5),
                      Icon(
                        isPending ? Icons.access_time_rounded : Icons.done_all_rounded,
                        size: 13,
                        color: (read && !isPending) ? fg : sub,
                      ),
                    ],
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubbleBox(BuildContext context, bool dark, BorderRadius radius, Color sub, Color fg) {
    if (m.isViewOnce) {
      return _buildViewOnceBubble(context, dark, radius, sub, fg);
    }

    if (m.mediaUrl != null) {
      return _buildNormalMediaBubble(context, dark, radius, sub, fg);
    }

    // Shared post/reel → render as an Instagram-style card (no DB hit; the
    // payload carries everything the card needs).
    final shared = SharedPost.tryParse(m.text);
    if (shared != null) {
      return SharedPostCard(post: shared, isMe: isMe, dark: dark);
    }

    if (isMe) {
      final bgColor = customSenderColor ?? (dark ? Colors.white : const Color(0xFF0A0A0A));
      final textCol = bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0xFF14161E).withValues(alpha: 0.25),
              blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -8,
            ),
          ],
        ),
        child: Text(m.text,
            style: manrope(size: 14.5, weight: FontWeight.w500,
                color: textCol,
                letterSpacing: -0.07, height: 1.4)),
      );
    }
    final bgColor = customReceiverColor ?? (dark ? const Color(0xFF242424).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95));
    final textCol = customReceiverColor != null
        ? (bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
        : GlassTokens.fg(dark);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
            color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black.withValues(alpha: 0.4) : const Color(0xFF14161E).withValues(alpha: 0.08),
            blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -4,
          ),
        ],
      ),
      child: Text(m.text,
          style: manrope(size: 14.5, weight: FontWeight.w500,
              color: textCol, letterSpacing: -0.07, height: 1.4)),
    );
  }

  Widget _buildNormalMediaBubble(BuildContext context, bool dark, BorderRadius radius, Color sub, Color fg) {
    final isVideo = m.mediaType == 'video';
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
            blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Media thumbnail
            GestureDetector(
              onTap: () {
                _showFullscreenMedia(context, dark);
              },
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                child: isVideo
                    ? _buildVideoThumbnail(m.mediaUrl!)
                    : CachedNetworkImage(
                        imageUrl: m.mediaUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 200,
                          width: 200,
                          color: dark ? Colors.white12 : Colors.black12,
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 150,
                          width: 150,
                          color: dark ? Colors.white12 : Colors.black12,
                          child: const Center(child: Icon(Icons.broken_image, size: 40)),
                        ),
                      ),
              ),
            ),
            
            // Video Play Button
            if (isVideo)
              Positioned(
                child: GestureDetector(
                  onTap: () => _showFullscreenMedia(context, dark),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ),

            // Archive Overlay Icon (Top Right)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final success = await UserService.archiveMedia(m.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Saved to Archive!' : 'Already archived or error'),
                        backgroundColor: success ? Colors.green : Colors.redAccent,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  child: const Icon(Icons.archive_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(String url) {
    return Container(
      width: 200,
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1E24), Color(0xFF0F0F12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_rounded, color: Colors.white60, size: 38),
            SizedBox(height: 8),
            Text('Play Video', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _showFullscreenMedia(BuildContext context, bool dark) {
    if (m.mediaUrl == null) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      builder: (ctx) => _FullscreenMediaViewer(
        mediaUrl: m.mediaUrl!,
        mediaType: m.mediaType ?? 'image',
        dark: dark,
      ),
    );
  }


  Widget _buildViewOnceBubble(BuildContext context, bool dark, BorderRadius radius, Color sub, Color fg) {
    final isVideo = m.mediaType == 'video';
    final hasViewed = m.viewOnceViewedBy.contains(myUserId) || m.mediaUrl == null;

    final bgColor = isMe
        ? (customSenderColor ?? (dark ? Colors.white : const Color(0xFF0A0A0A)))
        : (customReceiverColor ?? (dark ? const Color(0xFF242424).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95)));

    final textCol = isMe
        ? (bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
        : (customReceiverColor != null
            ? (bgColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
            : GlassTokens.fg(dark));

    final displayIcon = isVideo ? Icons.videocam_rounded : Icons.image_rounded;
    final label = hasViewed
        ? (isVideo ? 'Opened Video' : 'Opened Photo')
        : (isVideo ? 'View Once Video' : 'View Once Photo');

    final contentColor = hasViewed ? textCol.withValues(alpha: 0.5) : textCol;

    return GestureDetector(
      onTap: () {
        if (hasViewed) return;
        _showViewOnceMedia(context, dark);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: radius,
          border: isMe
              ? null
              : Border.all(
                  color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: dark
                  ? Colors.black.withValues(alpha: 0.4)
                  : const Color(0xFF14161E).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasViewed ? Icons.lock_open_rounded : displayIcon,
              color: contentColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: manrope(
                size: 14,
                weight: FontWeight.w600,
                color: contentColor,
                letterSpacing: -0.07,
              ),
            ),
            const SizedBox(width: 8),
            if (!hasViewed)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: textCol.withValues(alpha: 0.15),
                ),
                child: Text(
                  '1',
                  style: manrope(
                    size: 10,
                    weight: FontWeight.w800,
                    color: textCol,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showViewOnceMedia(BuildContext context, bool dark) {
    if (m.mediaUrl == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      barrierDismissible: true,
      builder: (ctx) => _ViewOnceViewerDialog(
        mediaUrl: m.mediaUrl!,
        mediaType: m.mediaType ?? 'image',
        dark: dark,
      ),
    ).then((_) {
      // Notify server on exit
      ChatService().markViewOnceViewed(m.conversationId, m.id);
      // Trigger callback to update local state instantly
      if (onViewOnceOpened != null) {
        onViewOnceOpened!();
      }
    });
  }

}

// ─────────────────────────────────────────────────────────────
// View Once Viewer Dialog & Player
// ─────────────────────────────────────────────────────────────

class _ViewOnceViewerDialog extends StatelessWidget {
  final String mediaUrl;
  final String mediaType;
  final bool dark;

  const _ViewOnceViewerDialog({
    required this.mediaUrl,
    required this.mediaType,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? Colors.black.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVideo ? 'View Once Video' : 'View Once Photo',
                      style: manrope(
                        size: 15,
                        weight: FontWeight.w700,
                        color: GlassTokens.fg(dark),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: GlassTokens.fg(dark)),
                      ),
                    ),
                  ],
                ),
              ),
              // Media Content
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isVideo
                        ? _ViewOnceVideoPlayer(url: mediaUrl)
                        : CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Text('Could not load image'),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewOnceVideoPlayer extends StatefulWidget {
  final String url;
  const _ViewOnceVideoPlayer({required this.url});

  @override
  State<_ViewOnceVideoPlayer> createState() => _ViewOnceVideoPlayerState();
}

class _ViewOnceVideoPlayerState extends State<_ViewOnceVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play();
          _controller.setLooping(true);
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(child: Text("Could not play video", style: TextStyle(color: Colors.white)));
    }
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.white)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reply quote — shown ABOVE the bubble (not inside it).
// Renders directly on the glass backdrop → needs fully opaque bg.
//
// FIX: replaced near-invisible withOpacity(0.07–0.22) values with
// solid Color values that are clearly readable in both dark & light.
// ─────────────────────────────────────────────────────────────

class _ReplyQuote extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool dark;

  const _ReplyQuote({
    required this.text, required this.isMe, required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    // ── Solid opaque backgrounds ──────────────────────────────
    // Dark mode glass backdrop ≈ #000000 → use a clearly lighter solid
    // Light mode glass backdrop ≈ #FAFAFA → use a clearly darker solid
    final bgColor = dark
        ? const Color(0xFF2B2B2F)  // dark: clearly visible on near-black bg
        : const Color(0xFFE8E8EC); // light: clearly visible on near-white bg

    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.09);

    final accentBar = dark
        ? Colors.white.withValues(alpha: 0.60)
        : Colors.black.withValues(alpha: 0.40);

    final labelColor = dark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.42);

    final textColor = dark
        ? Colors.white.withValues(alpha: 0.92)   // bright white on dark card
        : Colors.black.withValues(alpha: 0.82);  // near-black on light card

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.28 : 0.07),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left accent bar
          Container(
            width: 2.5, height: 32,
            decoration: BoxDecoration(
              color: accentBar, borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Replying to'.tr(context),
                    style: manrope(size: 10, weight: FontWeight.w700, color: labelColor)),
                const SizedBox(height: 2),
                Text(text,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: manrope(size: 12.5, weight: FontWeight.w500,
                        color: textColor, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom-sheet tile
// ─────────────────────────────────────────────────────────────

class _SheetTile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final Color fg;
  final VoidCallback onTap;

  const _SheetTile({
    required this.dark, required this.icon,
    required this.label, required this.fg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 16),
          Text(label.tr(context),
              style: manrope(size: 15, weight: FontWeight.w600, color: fg, letterSpacing: -0.2)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Typing bubble
// ─────────────────────────────────────────────────────────────

class _BubbleTyping extends StatelessWidget {
  final bool dark;
  final Color sub;
  const _BubbleTyping({required this.dark, required this.sub});

  @override
  Widget build(BuildContext context) {
    const br = BorderRadius.only(
      topLeft: Radius.circular(18), topRight: Radius.circular(18),
      bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF242424).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95),
          border: Border.all(
              color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: br,
          boxShadow: [
            BoxShadow(
              color: dark ? Colors.black.withValues(alpha: 0.4) : const Color(0xFF14161E).withValues(alpha: 0.08),
              blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -4,
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _TypingDot(delay: 0),
          const SizedBox(width: 5),
          _TypingDot(delay: 150),
          const SizedBox(width: 5),
          _TypingDot(delay: 300),
        ]),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = ((_c.value * 1200) - widget.delay) % 1200 / 1200;
        final v = (t >= 0 && t <= 0.8) ? (t < 0.4 ? t / 0.4 : (0.8 - t) / 0.4) : 0.0;
        final scale   = 0.7 + 0.3 * v.clamp(0.0, 1.0);
        final opacity = 0.4 + 0.6 * v.clamp(0.0, 1.0);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (dark ? Colors.white : Colors.black).withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// E2E Encryption Banner — chat ke TOP pe dikhta hai (first message se pehle)
// ─────────────────────────────────────────────────────────────

class _E2EBanner extends StatelessWidget {
  final bool dark;
  const _E2EBanner({required this.dark});

  @override
  Widget build(BuildContext context) {
    final sub = GlassTokens.sub(dark);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Icon(Icons.lock_rounded, size: 18, color: sub),
          ),
          const SizedBox(height: 8),
          Text(
            'End-to-end encrypted'.tr(context),
            style: manrope(
                size: 12.5,
                weight: FontWeight.w700,
                color: sub,
                letterSpacing: -0.1),
          ),
          const SizedBox(height: 4),
          Text(
            'Messages are secured with end-to-end encryption.\nOnly you and the recipient can read them.'.tr(context),
            textAlign: TextAlign.center,
            style: manrope(
                size: 11,
                weight: FontWeight.w500,
                color: sub.withValues(alpha: 0.7),
                height: 1.45),
          ),
          const SizedBox(height: 16),
          Divider(
              height: 1,
              color: dark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.07)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Swipe to Reply
// ─────────────────────────────────────────────────────────────

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;
  final bool dark;

  const SwipeToReply({
    super.key, required this.child, required this.onReply,
    required this.dark, this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOffset = 0.0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 70.0);
      if (_dragOffset >= 70.0 && !_triggered) {
        _triggered = true;
        HapticFeedback.lightImpact();
      } else if (_dragOffset < 70.0) {
        _triggered = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    if (_dragOffset >= 50.0) widget.onReply();
    _controller.value = _dragOffset / 70.0;
    _controller.animateTo(0.0, curve: Curves.easeOut).then((_) {
      if (mounted) setState(() { _dragOffset = 0.0; _triggered = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset   = _controller.isAnimating ? _controller.value * 70.0 : _dragOffset;
          final progress = (offset / 50.0).clamp(0.0, 1.0);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Positioned(
                left: -35 + (progress * 45),
                child: Opacity(
                  opacity: progress,
                  child: Transform.scale(
                    scale: 0.6 + (0.4 * progress),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.dark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                      child: Icon(Icons.reply_rounded,
                          color: widget.dark ? Colors.white : Colors.black87, size: 16),
                    ),
                  ),
                ),
              ),
              Transform.translate(offset: Offset(offset, 0), child: widget.child),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Fullscreen Media Viewer
// ─────────────────────────────────────────────────────────────

class _FullscreenMediaViewer extends StatelessWidget {
  final String mediaUrl;
  final String mediaType;
  final bool dark;

  const _FullscreenMediaViewer({
    required this.mediaUrl,
    required this.mediaType,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = mediaType == 'video';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? Colors.black.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVideo ? 'Video Preview' : 'Photo Preview',
                      style: manrope(
                        size: 15,
                        weight: FontWeight.w700,
                        color: GlassTokens.fg(dark),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                        ),
                        child: Icon(Icons.close_rounded, size: 18, color: GlassTokens.fg(dark)),
                      ),
                    ),
                  ],
                ),
              ),
              // Media Content
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isVideo
                        ? _ViewOnceVideoPlayer(url: mediaUrl) // Reuse the same video player
                        : CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Text('Could not load image'),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

