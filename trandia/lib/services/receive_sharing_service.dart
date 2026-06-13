import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../utils/navigator_key.dart';
import '../screens/create_post_screens.dart';
import '../screens/chat_screen.dart';
import '../screens/glass_common.dart';
import 'chat_service.dart';
import 'auth_service.dart';
import '../models/chat_model.dart';
import '../utils/error_dialog.dart';

class ReceiveSharingService {
  ReceiveSharingService._();
  static final ReceiveSharingService instance = ReceiveSharingService._();

  StreamSubscription? _intentDataStreamSubscription;

  void init() {
    // 1. Listen for media sharing when the app is running in memory/background
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _handleSharedMedia(value);
        }
      },
      onError: (err) {
        debugPrint("[ReceiveSharing] getMediaStream error: $err");
      },
    );

    // 2. Get initial media if the app was opened from a closed state via sharing
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
        ReceiveSharingIntent.instance.reset();
      }
    }).catchError((err) {
      debugPrint("[ReceiveSharing] getInitialMedia error: $err");
    });
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> media) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      // Context not ready yet, retry in a second
      Future.delayed(const Duration(seconds: 1), () => _handleSharedMedia(media));
      return;
    }

    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn) {
      // User must be logged in to share
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    _showShareDestinationSheet(context, media, isDark);
  }

  void _showShareDestinationSheet(BuildContext context, List<SharedMediaFile> media, bool dark) {
    final fg = GlassTokens.fg(dark);

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
                    color: dark ? const Color(0xFF1C1C1E).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Share to Trandia',
                          style: manrope(size: 16, weight: FontWeight.w800, color: fg),
                        ),
                      ),
                      _SheetTile(
                        dark: dark,
                        icon: Icons.post_add_rounded,
                        label: 'Add to Post',
                        fg: fg,
                        onTap: () {
                          Navigator.pop(ctx);
                          _shareToPost(media.first, dark);
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                      ),
                      _SheetTile(
                        dark: dark,
                        icon: Icons.send_rounded,
                        label: 'Send to Chat',
                        fg: fg,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showChatSelectionSheet(context, media.first, dark);
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

  void _shareToPost(SharedMediaFile sharedFile, bool dark) {
    final file = File(sharedFile.path);
    final isVideo = sharedFile.type == SharedMediaType.video;
    final xFile = XFile(file.path);

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => CreatePostEditScreen(
          dark: dark,
          file: xFile,
          isVideo: isVideo,
        ),
      ),
    );
  }

  Future<void> _showChatSelectionSheet(BuildContext context, SharedMediaFile sharedFile, bool dark) async {
    final fg = GlassTokens.fg(dark);
    final sub = GlassTokens.sub(dark);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<ChatConversation> conversations = [];
    try {
      conversations = await ChatService().getConversations();
    } catch (e) {
      debugPrint('[ReceiveSharing] getConversations error: $e');
    }

    // Dismiss loading indicator
    if (navigatorKey.currentContext != null) {
      Navigator.pop(navigatorKey.currentContext!);
    }

    if (conversations.isEmpty) {
      showErrorDialog(context, message: "No active chats found on Trandia.");
      return;
    }

    final myUserId = await AuthService.getCurrentUserId();
    if (myUserId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1C1C1E).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.96),
                    border: Border.all(
                      color: dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Select Chat to Send',
                          style: manrope(size: 16, weight: FontWeight.w800, color: fg),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conv = conversations[index];
                            final otherUser = conv.getOtherParticipant(myUserId);
                            
                            return ListTile(
                              leading: UserAvatar(
                                pictureUrl: otherUser.picture,
                                name: otherUser.name.isNotEmpty ? otherUser.name : otherUser.username,
                                size: 40,
                                dark: dark,
                                index: index,
                              ),
                              title: Text(
                                otherUser.username,
                                style: manrope(size: 15, weight: FontWeight.w700, color: fg),
                              ),
                              subtitle: Text(
                                otherUser.name,
                                style: manrope(size: 12, weight: FontWeight.w500, color: sub),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                _sendMediaToChat(context, conv, sharedFile, myUserId, dark);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendMediaToChat(
    BuildContext context,
    ChatConversation conversation,
    SharedMediaFile sharedFile,
    String myUserId,
    bool dark,
  ) async {
    // Show sending indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = File(sharedFile.path);
      final uploadResult = await ChatService().uploadChatMedia(file);
      final mediaUrl = uploadResult['url'] as String;
      final mediaPublicId = uploadResult['public_id'] as String;
      final mediaType = uploadResult['media_type'] as String;

      // Close loading dialog
      if (navigatorKey.currentContext != null) {
        Navigator.pop(navigatorKey.currentContext!);
      }

      // Send the view-once message
      await ChatService().sendMessage(
        conversation.id,
        '[MEDIA]',
        conversation.participants,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        mediaPublicId: mediaPublicId,
        isViewOnce: true,
      );

      // Successfully sent! Navigate to the ChatScreen to see it.
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            dark: dark,
            conversation: conversation,
            myUserId: myUserId,
          ),
        ),
      );
    } catch (e) {
      if (navigatorKey.currentContext != null) {
        Navigator.pop(navigatorKey.currentContext!); // close loading dialog
      }
      showErrorDialog(context, message: 'Could not send shared media: $e');
    }
  }
}

// ── Private tile widget helper ──
class _SheetTile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final Color fg;
  final VoidCallback onTap;

  const _SheetTile({
    required this.dark,
    required this.icon,
    required this.label,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: manrope(size: 15, weight: FontWeight.w600, color: fg, letterSpacing: -0.2),
            ),
          ],
        ),
      ),
    );
  }
}
