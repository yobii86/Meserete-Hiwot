import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/providers.dart';
import '../models/content.dart';
import 'download_service.dart';
import 'narration_player_service.dart';
import 'sync_service.dart';

/// The branded artwork (church emblem) for the lock screen when a Mezmur has no cover. The media
/// session needs a file:// or http(s) URI, so the bundled asset is copied once to app storage.
abstract final class AudioArtwork {
  static Uri? fallback;

  static Future<void> prepare() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}media_artwork.jpg');
      if (!f.existsSync()) {
        final data = await rootBundle.load('assets/images/logo.jpg');
        await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      fallback = f.uri;
    } catch (_) {
      fallback = null; // the notification still works, just without artwork
    }
  }
}

/// The first non-empty lines of the lyrics, for the media notification.
String lyricsPreview(String? lyrics, {int lines = 2}) {
  if (lyrics == null) return '';
  return lyrics.split(RegExp(r'\r?\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).take(lines).join(' / ');
}

class PlayerTrack {
  const PlayerTrack({required this.id, required this.title, this.subtitle, required this.source, this.artUrl, this.durationSec, this.lyrics});
  final int id;
  final String title;
  final String? subtitle;

  /// A short lyrics excerpt (shown under the title in the notification).
  final String? lyrics;

  /// http(s) URL, or a local file path for downloaded audio.
  final String source;
  final String? artUrl;
  final int? durationSec;

  bool get isLocal => File(source).existsSync();

  /// A list item (related / category Mezmur) with streaming audio, for the queue.
  static PlayerTrack? fromSummary(MezmurSummary m, {OfflineEntry? offline}) {
    final local = offline?.audioPath;
    final src = (local != null && File(local).existsSync()) ? local : m.audioUrl;
    if (src == null) return null;
    return PlayerTrack(id: m.id, title: m.title, subtitle: m.categoryName, source: src, artUrl: m.coverUrl, durationSec: m.audioDurationSec, lyrics: m.excerpt);
  }

  /// Build a track from a full Mezmur, preferring the offline audio file when present.
  static PlayerTrack? fromMezmur(Mezmur m, {OfflineEntry? offline}) {
    final local = m.localAudioPath ?? offline?.audioPath;
    final src = (local != null && File(local).existsSync()) ? local : m.audio?.url;
    if (src == null) return null;
    return PlayerTrack(
      id: m.id,
      title: m.title,
      subtitle: m.summary.categoryName,
      source: src,
      artUrl: m.summary.coverUrl,
      durationSec: m.audio?.durationSec ?? m.summary.audioDurationSec,
      lyrics: lyricsPreview(m.lyrics),
    );
  }
}

class PlayerUiState {
  const PlayerUiState({
    this.queue = const [],
    this.index,
    this.playing = false,
    this.loop = LoopMode.off,
    this.shuffle = false,
    this.buffering = false,
    this.error = false,
    this.speed = 1.0,
    this.sleepAt,
    this.sleepAfterTrack = false,
  });
  final List<PlayerTrack> queue;
  final int? index;
  final bool playing;
  final LoopMode loop;
  final bool shuffle;
  final bool buffering;
  final bool error;

  /// Playback speed (0.75 – 1.5).
  final double speed;

  /// Sleep timer: pause at this time, or when the current Mezmur ends.
  final DateTime? sleepAt;
  final bool sleepAfterTrack;

  PlayerTrack? get current => index != null && index! < queue.length ? queue[index!] : null;
  bool get hasTrack => current != null;
  bool get hasNext => index != null && (index! < queue.length - 1 || loop == LoopMode.all || shuffle);
  bool get hasPrevious => index != null && (index! > 0 || loop == LoopMode.all || shuffle);

  PlayerUiState copyWith({
    List<PlayerTrack>? queue,
    int? index,
    bool? playing,
    LoopMode? loop,
    bool? shuffle,
    bool? buffering,
    bool? error,
    double? speed,
    DateTime? Function()? sleepAt,
    bool? sleepAfterTrack,
  }) =>
      PlayerUiState(
        queue: queue ?? this.queue,
        index: index ?? this.index,
        playing: playing ?? this.playing,
        loop: loop ?? this.loop,
        shuffle: shuffle ?? this.shuffle,
        buffering: buffering ?? this.buffering,
        error: error ?? this.error,
        speed: speed ?? this.speed,
        sleepAt: sleepAt != null ? sleepAt() : this.sleepAt,
        sleepAfterTrack: sleepAfterTrack ?? this.sleepAfterTrack,
      );
}

/// App-wide audio player (background playback + lock-screen controls via just_audio_background).
class AudioController extends Notifier<PlayerUiState> {
  final player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  PlayerUiState build() {
    unawaited(_configureSession());
    _subs
      ..add(player.playerStateStream.listen((s) {
        state = state.copyWith(
          playing: s.playing,
          buffering: s.processingState == ProcessingState.loading || s.processingState == ProcessingState.buffering,
        );
        if (s.processingState == ProcessingState.completed) {
          _trackComplete(state.index);
          if (state.sleepAfterTrack) state = state.copyWith(sleepAfterTrack: false);
        }
      }))
      ..add(player.currentIndexStream.listen((i) {
        if (i == null || i == state.index) return;
        // "Stop after this Mezmur": the next one is not started.
        if (state.sleepAfterTrack) {
          unawaited(player.pause());
          state = state.copyWith(sleepAfterTrack: false);
        }
        state = state.copyWith(index: i, error: false);
        _trackPlay(i);
      }))
      ..add(player.positionDiscontinuityStream.listen((d) {
        if (d.reason == PositionDiscontinuityReason.autoAdvance) _trackComplete(d.previousEvent.currentIndex);
      }))
      ..add(player.errorStream.listen((_) => state = state.copyWith(error: true)));
    ref.onDispose(() {
      _sleepTimer?.cancel();
      for (final s in _subs) {
        s.cancel();
      }
      player.dispose();
    });
    return const PlayerUiState();
  }

  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void _trackPlay(int? i) {
    final t = (i != null && i < state.queue.length) ? state.queue[i] : null;
    if (t == null) return;
    unawaited(ref.read(syncServiceProvider).trackActivity('audio_play', entityType: 'mezmur', entityId: t.id, metadata: {'offline': t.isLocal}));
  }

  void _trackComplete(int? i) {
    final t = (i != null && i < state.queue.length) ? state.queue[i] : null;
    if (t == null) return;
    unawaited(ref.read(syncServiceProvider).trackActivity('audio_complete', entityType: 'mezmur', entityId: t.id));
  }

  static Uri? resolveArtUri(String? artUrl, [String? baseUrl]) {
    if (artUrl == null || artUrl.isEmpty) return AudioArtwork.fallback;
    if (artUrl.startsWith('http://') || artUrl.startsWith('https://')) {
      return Uri.tryParse(artUrl) ?? AudioArtwork.fallback;
    }
    if (File(artUrl).existsSync()) {
      return Uri.file(artUrl);
    }
    if (baseUrl != null && baseUrl.isNotEmpty) {
      try {
        final baseUri = Uri.parse(baseUrl);
        final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
        final path = artUrl.startsWith('/') ? artUrl : '/$artUrl';
        return Uri.tryParse('$origin$path') ?? AudioArtwork.fallback;
      } catch (_) {}
    }
    return AudioArtwork.fallback;
  }

  /// The media-session item: Mezmur title, the app name as artist (branding), category as album,
  /// a lyrics excerpt as description; the cover, or the church emblem, as lock-screen artwork.
  static MediaItem mediaItemOf(PlayerTrack t, [String? baseUrl]) => MediaItem(
        id: '${t.id}',
        title: t.title,
        artist: 'መሠረተ ሕይወት',
        album: t.subtitle,
        displayTitle: t.title,
        displaySubtitle: (t.lyrics?.isNotEmpty ?? false) ? t.lyrics : (t.subtitle ?? 'መሠረተ ሕይወት'),
        displayDescription: t.subtitle,
        artUri: resolveArtUri(t.artUrl, baseUrl),
        duration: t.durationSec != null ? Duration(seconds: t.durationSec!) : null,
      );

  String _resolveTrackUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    try {
      final baseUrl = ref.read(apiClientProvider).dio.options.baseUrl;
      final baseUri = Uri.parse(baseUrl);
      final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
      final path = url.startsWith('/') ? url : '/$url';
      return '$origin$path';
    } catch (_) {
      return url;
    }
  }

  Map<String, String>? _audioHeaders() {
    final headers = <String, String>{};
    try {
      final store = ref.read(secureStoreProvider);
      final cookie = store.imunifyCookie;
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      final token = store.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}
    return headers.isEmpty ? null : headers;
  }

  AudioSource _source(PlayerTrack t) {
    String? baseUrl;
    try {
      baseUrl = ref.read(apiClientProvider).dio.options.baseUrl;
    } catch (_) {}
    final tag = mediaItemOf(t, baseUrl);
    if (t.isLocal) {
      return AudioSource.file(t.source, tag: tag);
    }
    final resolved = _resolveTrackUrl(t.source);
    return AudioSource.uri(Uri.parse(resolved), headers: _audioHeaders(), tag: tag);
  }

  Future<void> playQueue(List<PlayerTrack> tracks, {int start = 0, bool shuffle = false}) async {
    if (tracks.isEmpty) return;
    try {
      final narrationState = ref.read(narrationControllerProvider);
      if (narrationState.isPlaying) {
        unawaited(ref.read(narrationControllerProvider.notifier).pause());
      }
    } catch (_) {}
    state = PlayerUiState(queue: tracks, index: start, loop: state.loop, shuffle: shuffle, speed: state.speed, sleepAt: state.sleepAt, sleepAfterTrack: state.sleepAfterTrack);
    try {
      await player.setShuffleModeEnabled(shuffle);
      await player.setAudioSources(tracks.map(_source).toList(), initialIndex: start);
      _trackPlay(start);
      unawaited(player.play());
    } catch (_) {
      // If playback fails, try resolving Imunify challenge and retry once
      try {
        await ref.read(apiClientProvider).ensureImunifyResolved();
        await player.setAudioSources(tracks.map(_source).toList(), initialIndex: start);
        _trackPlay(start);
        unawaited(player.play());
      } catch (_) {
        state = state.copyWith(error: true);
      }
    }
  }

  Future<void> playSingle(PlayerTrack t) async {
    if (state.current?.id == t.id && !state.error) {
      if (!player.playing) {
        try {
          final narrationState = ref.read(narrationControllerProvider);
          if (narrationState.isPlaying) {
            unawaited(ref.read(narrationControllerProvider.notifier).pause());
          }
        } catch (_) {}
        unawaited(player.play());
      }
      return;
    }
    await playQueue([t]);
  }

  Future<void> toggle() async {
    if (state.error && state.current != null) {
      await retry();
      return;
    }
    if (player.playing) {
      await player.pause();
    } else {
      try {
        final narrationState = ref.read(narrationControllerProvider);
        if (narrationState.isPlaying) {
          unawaited(ref.read(narrationControllerProvider.notifier).pause());
        }
      } catch (_) {}
      state = state.copyWith(error: false);
      await player.play();
    }
  }

  Future<void> retry() async {
    if (state.current != null && state.queue.isNotEmpty) {
      state = state.copyWith(error: false);
      await playQueue(state.queue, start: state.index ?? 0, shuffle: state.shuffle);
    }
  }
  Future<void> seek(Duration d) => player.seek(d);
  Future<void> next() => player.seekToNext();
  Future<void> previous() async {
    if (player.position > const Duration(seconds: 3)) return player.seek(Duration.zero);
    return player.seekToPrevious();
  }

  Future<void> toggleShuffle() async {
    final v = !state.shuffle;
    await player.setShuffleModeEnabled(v);
    state = state.copyWith(shuffle: v);
  }

  Future<void> cycleLoop() async {
    final next = switch (state.loop) { LoopMode.off => LoopMode.all, LoopMode.all => LoopMode.one, LoopMode.one => LoopMode.off };
    await player.setLoopMode(next);
    state = state.copyWith(loop: next);
  }

  /// Play [t] with [upNext] queued after it, so next / previous move through them.
  Future<void> playWithQueue(PlayerTrack t, List<PlayerTrack> upNext) async {
    if (state.current?.id == t.id) {
      if (!player.playing) unawaited(player.play());
      return;
    }
    final seen = <int>{t.id};
    await playQueue([t, ...upNext.where((x) => seen.add(x.id))]);
  }

  /// Play [queue] from [start] (a category in folder order): previous / next move through it.
  Future<void> playInQueue(List<PlayerTrack> queue, int start) async {
    final t = queue[start];
    if (state.current?.id == t.id && state.queue.length == queue.length) {
      if (!player.playing) unawaited(player.play());
      return;
    }
    await playQueue(queue, start: start);
  }

  /// Jump to a Mezmur of the queue.
  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    await player.seek(Duration.zero, index: index);
    if (!player.playing) unawaited(player.play());
  }

  Future<void> setSpeed(double v) async {
    await player.setSpeed(v);
    state = state.copyWith(speed: v);
  }

  Timer? _sleepTimer;

  /// Pause after [after] (null = off); [endOfTrack] pauses when the current Mezmur ends.
  void setSleepTimer(Duration? after, {bool endOfTrack = false}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (after != null) {
      _sleepTimer = Timer(after, () {
        unawaited(player.pause());
        state = state.copyWith(sleepAt: () => null);
      });
    }
    state = state.copyWith(sleepAt: () => after == null ? null : DateTime.now().add(after), sleepAfterTrack: endOfTrack);
  }

  /// Close the player (the X): stop, clear the queue and the sleep timer.
  Future<void> stop() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    await player.stop();
    state = PlayerUiState(speed: state.speed);
  }
}

final audioProvider = NotifierProvider<AudioController, PlayerUiState>(AudioController.new);

final positionProvider = StreamProvider<Duration>((ref) => ref.watch(audioProvider.notifier).player.positionStream);
final durationProvider = StreamProvider<Duration?>((ref) => ref.watch(audioProvider.notifier).player.durationStream);
