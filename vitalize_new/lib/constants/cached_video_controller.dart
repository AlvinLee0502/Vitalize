import 'package:video_player/video_player.dart';

class CachedVideoControllerManager {
  static final Map<String, VideoPlayerController> _cache = {};

  static Future<VideoPlayerController> getController(String url) async {
    if (!_cache.containsKey(url)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      _cache[url] = controller;
    }
    return _cache[url]!;
  }

  static void dispose() {
    for (var controller in _cache.values) {
      controller.dispose();
    }
    _cache.clear();
  }
}