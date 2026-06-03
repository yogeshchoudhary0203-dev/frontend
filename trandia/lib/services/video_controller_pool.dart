// video_controller_pool.dart
//
// A fixed-size pool that keeps at most 3 VideoPlayerControllers alive at a
// time: the one immediately before the current page (prev), the current page
// (cur), and the one immediately after (next).
//
// Design goals
// ─────────────
//  • Zero extra controllers — never more than 3 alive simultaneously.
//  • Reuse over re-create — when the user scrolls forward the "prev" slot is
//    disposed and the old "cur" becomes "prev", old "next" becomes "cur", and
//    a fresh controller is prepared for the new "next". Scrolling backward
//    mirrors this symmetrically.
//  • Caller stays simple — just call [warmUp] on init, [onPageChanged] on
//    every scroll event, and read controllers via [controllerAt].
//  • No UI coupling — the pool knows nothing about widgets; it only manages
//    VideoPlayerController lifecycle.

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

typedef UrlResolver = String Function(int index);
typedef PoolControllerReady = void Function(int index, VideoPlayerController ctrl);

class VideoControllerPool {
  VideoControllerPool({
    required this.urlResolver,
    required this.itemCount,
    this.onReady,
    this.muted = false,
    this.looping = true,
  });

  /// Return the media URL for a given list index.
  final UrlResolver urlResolver;

  /// Total number of items in the feed (can grow — call [updateItemCount]).
  int itemCount;

  /// Called whenever a controller finishes initialising.
  final PoolControllerReady? onReady;

  bool muted;
  bool looping;

  // ── Internal slot storage ────────────────────────────────────────────────
  // Slot index → VideoPlayerController (only indices curIdx-1, curIdx,
  // curIdx+1 are ever occupied).
  final Map<int, VideoPlayerController> _pool = {};

  // Ongoing init futures so we never double-initialise the same index.
  final Map<int, Future<void>> _pending = {};

  int _curIdx = 0;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Seed the pool at the very first frame (call once after the first
  /// data load).
  Future<void> warmUp(int startIndex) async {
    _curIdx = startIndex;
    await _ensure(startIndex);          // current — awaited so first frame shows
    _ensure(startIndex + 1);            // next     — fire-and-forget preload
  }

  /// Called from onPageChanged.  Shifts the window and manages lifecycle.
  void onPageChanged(int newIndex) {
    final delta = newIndex - _curIdx;
    _curIdx = newIndex;

    if (delta == 0) return;

    // Pause the controller we are leaving.
    _pool[newIndex - delta]?.pause();

    // Play (or init) the arriving controller.
    final arriving = _pool[newIndex];
    if (arriving != null && arriving.value.isInitialized) {
      arriving.setVolume(muted ? 0.0 : 1.0);
      arriving.play();
    } else {
      _ensure(newIndex).then((_) {
        if (_curIdx == newIndex) {
          _pool[newIndex]?.setVolume(muted ? 0.0 : 1.0);
          _pool[newIndex]?.play();
        }
      });
    }

    // Preload the next slot in the direction of travel.
    final preloadIdx = newIndex + delta.sign;
    if (preloadIdx >= 0 && preloadIdx < itemCount) {
      _ensure(preloadIdx);
    }

    // Dispose anything outside the ±1 window.
    _pruneDistant(newIndex);
  }

  /// Returns the controller for [index], or null if not yet ready.
  VideoPlayerController? controllerAt(int index) => _pool[index];

  /// Whether the controller at [index] is fully initialised.
  bool isReady(int index) => _pool[index]?.value.isInitialized ?? false;

  /// Pause/resume all live controllers (used when app goes to background).
  void pauseAll() {
    for (final c in _pool.values) {
      c.pause();
    }
  }

  void resumeCurrent() {
    final c = _pool[_curIdx];
    if (c != null && c.value.isInitialized) {
      c.setVolume(muted ? 0.0 : 1.0);
      c.play();
    }
  }

  /// Set mute state on all live controllers.
  void setMuted(bool value) {
    muted = value;
    for (final c in _pool.values) {
      c.setVolume(muted ? 0.0 : 1.0);
    }
  }

  /// Call when the feed list grows (infinite scroll).
  void updateItemCount(int count) {
    itemCount = count;
  }

  /// Dispose every live controller and clear the pool.
  void disposeAll() {
    for (final c in _pool.values) {
      c.dispose();
    }
    _pool.clear();
    _pending.clear();
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  /// Ensure a controller exists and is initialised for [index].
  /// Safe to call multiple times — duplicate calls are de-duped via [_pending].
  Future<void> _ensure(int index) {
    if (index < 0 || index >= itemCount) return Future.value();
    if (_pool.containsKey(index)) return Future.value();
    if (_pending.containsKey(index)) return _pending[index]!;

    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(urlResolver(index)),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    _pool[index] = ctrl;

    final future = ctrl.initialize().then((_) {
      ctrl.setLooping(looping);
      ctrl.setVolume(muted ? 0.0 : 1.0);
      onReady?.call(index, ctrl);
    }).catchError((e) {
      debugPrint('[VideoPool] init error idx=$index: $e');
      _pool.remove(index);
    }).whenComplete(() {
      _pending.remove(index);
    });

    _pending[index] = future;
    return future;
  }

  /// Dispose controllers whose index is more than 1 away from [current].
  void _pruneDistant(int current) {
    final toRemove = _pool.keys
        .where((k) => (k - current).abs() > 1)
        .toList(growable: false);
    for (final k in toRemove) {
      _pool[k]?.dispose();
      _pool.remove(k);
      _pending.remove(k);
    }
  }
}
