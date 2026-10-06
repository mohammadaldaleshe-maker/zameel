import 'package:flutter/material.dart';
import 'chat_voice_widgets.dart';
import 'video_player_widget.dart';
import '../services/chat_media_save_service.dart';

class ChatMediaViewer extends StatefulWidget {
  final String url, type;
  final bool liked;
  final int likes;
  final Future<void> Function() onLike;
  const ChatMediaViewer(
      {super.key,
      required this.url,
      required this.type,
      required this.onLike,
      this.liked = false,
      this.likes = 0});
  @override
  State<ChatMediaViewer> createState() => _ChatMediaViewerState();
}

class _ChatMediaViewerState extends State<ChatMediaViewer> {
  late bool _liked = widget.liked;
  late int _likes = widget.likes;
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title:
                Text(widget.type == 'audio' ? 'رسالة صوتية' : 'وسائط الدردشة')),
        body: Center(
            child: widget.type == 'image'
                ? InteractiveViewer(
                    child: Image.network(widget.url, fit: BoxFit.contain))
                : widget.type == 'audio'
                    ? ChatVoicePlayer(url: widget.url)
                    : VideoPlayerWidget(videoUrl: widget.url)),
        bottomNavigationBar: SafeArea(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
              TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await widget.onLike();
                            if (mounted)
                              setState(() {
                                _liked = !_liked;
                                _likes += _liked ? 1 : -1;
                              });
                          } catch (_) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('تعذر حفظ الإعجاب')));
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
                  label: Text('أعجبني ($_likes)')),
              TextButton.icon(
                  onPressed: () => ChatMediaSaveService.save(
                      context, widget.url, widget.type),
                  icon: const Icon(Icons.download),
                  label: const Text('حفظ على الهاتف')),
            ])),
      );
}
