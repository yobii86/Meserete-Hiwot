import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/providers.dart';
import '../models/library.dart';
import '../repositories/providers.dart';
import 'audio_player_service.dart';

class NarrationPlayerState {
  const NarrationPlayerState({
    this.book,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.hasError = false,
  });

  final Book? book;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool hasError;

  bool get hasNarration => book != null;

  NarrationPlayerState copyWith({
    Book? Function()? book,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? hasError,
  }) =>
      NarrationPlayerState(
        book: book != null ? book() : this.book,
        isPlaying: isPlaying ?? this.isPlaying,
        isBuffering: isBuffering ?? this.isBuffering,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        hasError: hasError ?? this.hasError,
      );
}

class NarrationController extends Notifier<NarrationPlayerState> {
  final player = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _progressDebounce;

  @override
  NarrationPlayerState build() {
    unawaited(_configureSession());
    _subs
      ..add(player.playerStateStream.listen((s) {
        state = state.copyWith(
          isPlaying: s.playing,
          isBuffering: s.processingState == ProcessingState.loading ||
              s.processingState == ProcessingState.buffering,
        );
        if (s.processingState == ProcessingState.completed) {
          _saveCurrentProgress();
        }
      }))
      ..add(player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
        _scheduleProgressSave();
      }))
      ..add(player.durationStream.listen((dur) {
        if (dur != null) state = state.copyWith(duration: dur);
      }))
      ..add(player.errorStream.listen((_) {
        state = state.copyWith(hasError: true);
      }));

    ref.onDispose(() {
      _progressDebounce?.cancel();
      for (final s in _subs) {
        s.cancel();
      }
      player.dispose();
    });

    return const NarrationPlayerState();
  }

  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }

  void _scheduleProgressSave() {
    if (_progressDebounce?.isActive ?? false) return;
    _progressDebounce = Timer(const Duration(seconds: 8), () {
      _saveCurrentProgress();
    });
  }

  void _saveCurrentProgress() {
    final b = state.book;
    if (b == null) return;
    final ms = state.position.inMilliseconds;
    if (ms <= 0) return;
    ref.read(libraryRepositoryProvider).saveProgress(
          b.id,
          audioPositionMs: ms,
        );
  }

  Future<void> playBook(Book book, {Duration? initialPosition}) async {
    // 1. Pause Mezmur audio player if it is currently playing
    try {
      final mezmurPlayer = ref.read(audioProvider.notifier).player;
      if (mezmurPlayer.playing) {
        await mezmurPlayer.pause();
      }
    } catch (_) {}

    final narrationUrl = book.narrationUrl;
    if (narrationUrl == null || narrationUrl.isEmpty) return;

    final baseUrl = ref.read(apiClientProvider).dio.options.baseUrl;
    final fullUrl = narrationUrl.startsWith('http')
        ? narrationUrl
        : '$baseUrl${narrationUrl.startsWith('/') ? '' : '/'}$narrationUrl';

    state = state.copyWith(
      book: () => book,
      hasError: false,
      position: initialPosition ?? Duration(milliseconds: book.progress?.audioPositionMs ?? 0),
    );

    final mediaItem = MediaItem(
      id: 'book-narration-${book.id}',
      title: '${book.title} (ትረካ)',
      artist: book.author ?? 'መሠረተ ሕይወት',
      album: book.categoryName ?? 'ትምህርት',
      displayTitle: '${book.title} (ትረካ)',
      displaySubtitle: book.author ?? 'መሠረተ ሕይወት',
      artUri: book.coverUrl != null ? Uri.parse(book.coverUrl!) : AudioArtwork.fallback,
      duration: book.narrationDuration != null ? Duration(seconds: book.narrationDuration!) : null,
    );

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

    try {
      final source = AudioSource.uri(Uri.parse(fullUrl), headers: headers.isEmpty ? null : headers, tag: mediaItem);
      await player.setAudioSource(source);

      final start = initialPosition ?? Duration(milliseconds: book.progress?.audioPositionMs ?? 0);
      if (start > Duration.zero) {
        await player.seek(start);
      }
      await player.play();
    } catch (e) {
      try {
        await ref.read(apiClientProvider).ensureImunifyResolved();
        final refreshedHeaders = Map<String, String>.from(headers);
        final freshCookie = ref.read(secureStoreProvider).imunifyCookie;
        if (freshCookie != null && freshCookie.isNotEmpty) {
          refreshedHeaders['Cookie'] = freshCookie;
        }
        final source = AudioSource.uri(Uri.parse(fullUrl),
            headers: refreshedHeaders.isEmpty ? null : refreshedHeaders, tag: mediaItem);
        await player.setAudioSource(source);
        final start = initialPosition ?? Duration(milliseconds: book.progress?.audioPositionMs ?? 0);
        if (start > Duration.zero) {
          await player.seek(start);
        }
        await player.play();
      } catch (_) {
        debugPrint('Narration player error: $e');
        state = state.copyWith(hasError: true);
      }
    }
  }

  Future<void> play() => player.play();

  Future<void> pause() async {
    _saveCurrentProgress();
    await player.pause();
  }

  Future<void> seek(Duration position) async {
    await player.seek(position);
    _saveCurrentProgress();
  }

  Future<void> skip(Duration offset) async {
    final target = state.position + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (state.duration > Duration.zero && target > state.duration ? state.duration : target);
    await seek(clamped);
  }

  Future<void> setSpeed(double speed) async {
    await player.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  Future<void> stop() async {
    _saveCurrentProgress();
    await player.stop();
    state = state.copyWith(book: () => null, isPlaying: false, position: Duration.zero);
  }
}

final narrationControllerProvider =
    NotifierProvider<NarrationController, NarrationPlayerState>(NarrationController.new);
