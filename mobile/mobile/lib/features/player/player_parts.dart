import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/lrc.dart';
import '../../services/audio_player_service.dart';
import '../../widgets/brand.dart';
import '../guidance/tour_engine.dart';

/// Full-screen backdrop of the player page: the cover art (or the maroon placeholder), faded into
/// the page colour towards the bottom so lyrics printed over it stay readable in light and dark theme.
class PlayerBackdrop extends StatelessWidget {
  const PlayerBackdrop({super.key, this.artUrl, this.localArtPath});
  final String? artUrl;
  final String? localArtPath;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(fit: StackFit.expand, children: [
      // Softened: the sharp cover is the card in the middle of the page.
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14, tileMode: TileMode.decal),
        child: CoverImage(url: artUrl, localPath: localArtPath),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, 0.28, 0.5, 1],
            colors: [bg.withValues(alpha: 0.10), bg.withValues(alpha: 0.35), bg.withValues(alpha: 0.82), bg.withValues(alpha: 0.95)],
          ),
        ),
      ),
    ]);
  }
}

/// The lyrics as printed over the backdrop (left-aligned stanzas, the app's serif font).
class LyricsText extends StatelessWidget {
  const LyricsText({super.key, required this.text, this.scale = 1, this.selectable = true});
  final String text;
  final double scale;

  /// Off on the flip card, where a tap anywhere must flip back to the image.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (text.trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(context.l10n.noLyricsYet, style: context.sans(14, color: p.muted)),
      );
    }
    final style = context.serif(19 * scale, weight: FontWeight.w500, color: p.text, height: 1.75);
    return selectable ? SelectableText(text.trim(), style: style) : Text(text.trim(), style: style);
  }
}

/// The rounded control panel at the bottom of the player page:
///   seek bar
///   repeat · position ............ duration · shuffle
///   [leading]  previous  ( play )  next  [trailing]
/// [leading] / [trailing] are the download and favorite buttons. Without a [track] (lyrics only)
/// only that row is shown, around an inactive play button.
DateTime? _lastTrackNav;
void _navTrackThrottled(VoidCallback action) {
  final now = DateTime.now();
  if (_lastTrackNav != null && now.difference(_lastTrackNav!).inMilliseconds < 400) return;
  _lastTrackNav = now;
  action();
}

class PlayerPanel extends ConsumerWidget {
  const PlayerPanel({super.key, required this.track, required this.leading, required this.trailing});
  final PlayerTrack? track;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final t = track;
    final s = ref.watch(audioProvider);
    final ctrl = ref.read(audioProvider.notifier);
    final isCurrent = t != null && s.current?.id == t.id;
    final pos = isCurrent ? (ref.watch(positionProvider).value ?? Duration.zero) : Duration.zero;
    final dur = (isCurrent ? ref.watch(durationProvider).value : null) ?? (t?.durationSec != null ? Duration(seconds: t!.durationSec!) : Duration.zero);
    final timeStyle = context.sans(12, color: p.muted);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: p.card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (isCurrent && s.error)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: ctrl.retry,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 14, color: AppColors.danger),
                    const SizedBox(width: 4),
                    Text(l.audioError, style: context.sans(12, color: AppColors.danger, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        if (t != null) ...[
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7), overlayShape: SliderComponentShape.noOverlay),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Slider(
                value: dur.inMilliseconds == 0 ? 0 : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0),
                onChanged: !isCurrent || dur.inMilliseconds == 0 ? null : (v) => ctrl.seek(dur * v),
              ),
            ),
          ),
          Row(children: [
            IconButton(
              tooltip: l.repeat,
              icon: Icon(s.loop == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: s.loop == LoopMode.off ? p.subtle : AppColors.gold),
              onPressed: ctrl.cycleLoop,
            ),
            const SizedBox(width: 6),
            Text(Formatters.duration(pos), style: timeStyle),
            const Spacer(),
            Text(Formatters.duration(dur), style: timeStyle),
            const SizedBox(width: 6),
            IconButton(tooltip: l.shuffle, icon: Icon(Icons.shuffle_rounded, color: s.shuffle ? AppColors.gold : p.subtle), onPressed: ctrl.toggleShuffle),
            IconButton(
              key: const ValueKey('player-options'),
              tooltip: l.playerOptions,
              icon: Icon(Icons.tune_rounded, color: s.speed != 1 || s.sleepAt != null || s.sleepAfterTrack ? AppColors.gold : p.subtle),
              onPressed: () => showPlayerOptions(context),
            ),
          ]),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          leading,
          IconButton(key: const ValueKey('player-previous'), tooltip: l.previousTrack, iconSize: 32, icon: Icon(Icons.skip_previous_rounded, color: p.primary), onPressed: isCurrent ? () => _navTrackThrottled(ctrl.previous) : null),
          Material(
            key: TourKeys.mezmurPlay,
            color: t == null ? p.pill : AppColors.maroon,
            shape: const CircleBorder(),
            elevation: t == null ? 0 : 4,
            shadowColor: AppColors.maroon.withValues(alpha: 0.5),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: t == null ? null : () => isCurrent ? ctrl.toggle() : ctrl.playSingle(t),
              child: SizedBox(
                width: 64,
                height: 64,
                child: isCurrent && s.buffering
                    ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Icon(
                        isCurrent && s.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: t == null ? p.subtle : Colors.white,
                        size: 34,
                        semanticLabel: isCurrent && s.playing ? l.pause : l.play,
                      ),
              ),
            ),
          ),
          IconButton(key: const ValueKey('player-next'), tooltip: l.nextTrack, iconSize: 32, icon: Icon(Icons.skip_next_rounded, color: p.primary), onPressed: isCurrent && s.hasNext ? () => _navTrackThrottled(ctrl.next) : null),
          trailing,
        ]),
      ]),
    );
  }
}

/// The cover as a square card; tap it to flip to the lyrics. The lyrics side is taller than the
/// cover: while flipping, the card grows to the full height available (down to the control panel),
/// so long lyrics have room. Tap again to flip back.
class CoverLyricsFlip extends StatefulWidget {
  const CoverLyricsFlip({super.key, this.artUrl, this.localArtPath, required this.lyrics, this.startOnLyrics = false});
  final String? artUrl;
  final String? localArtPath;
  final Widget lyrics;
  final bool startOnLyrics;

  @override
  State<CoverLyricsFlip> createState() => _CoverLyricsFlipState();
}

class _CoverLyricsFlipState extends State<CoverLyricsFlip> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500), value: widget.startOnLyrics ? 1 : 0);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _flip() => _anim.status == AnimationStatus.completed || _anim.status == AnimationStatus.forward ? _anim.reverse() : _anim.forward();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return LayoutBuilder(builder: (context, box) {
      const hint = 26.0; // room for "tap the image to see the lyrics"
      final side = math.min(box.maxWidth, box.maxHeight - hint).clamp(120.0, 360.0);
      return AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_anim.value);
          // Front: a square cover. Back: full width and the full height available.
          final width = side + (box.maxWidth - side) * t;
          final height = side + (box.maxHeight - side) * t;
          final angle = t * math.pi;
          final showBack = angle > math.pi / 2;
          final card = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // perspective
              ..rotateY(angle),
            child: GestureDetector(
              onTap: _flip,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [const BoxShadow(color: AppColors.gold, spreadRadius: 3), BoxShadow(color: AppColors.maroon.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, 18))],
                ),
                child: showBack
                    // The back is drawn mirrored — undo the flip so the text reads normally.
                    ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: widget.lyrics)
                    : CoverImage(url: widget.artUrl, localPath: widget.localArtPath, radius: 24),
              ),
            ),
          );
          return Column(children: [
            Expanded(child: Center(child: card)),
            SizedBox(
              height: hint * (1 - t),
              child: Opacity(
                opacity: (1 - t * 2).clamp(0.0, 1.0),
                child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.tapForLyrics, style: context.sans(11, color: context.palette.subtle))),
              ),
            ),
          ]);
        },
      );
    });
  }
}

/// The back of the card: the lyrics on the page's card colour, scrolling when long.
class LyricsCard extends StatelessWidget {
  const LyricsCard({super.key, required this.text, this.scale = 1, this.lrc, this.trackId});
  final String text;
  final double scale;

  /// Time-synced lyrics; shown (following the audio) instead of [text] when present.
  final String? lrc;
  final int? trackId;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Scrollbar(
          radius: const Radius.circular(8),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Builder(builder: (context) {
              final sheet = parseLrcSheet(lrc);
              return !sheet.isEmpty && trackId != null
                  ? SyncedLyrics(sheet: sheet, trackId: trackId!, scale: scale)
                  : LyricsText(text: text, scale: scale, selectable: false);
            }),
          ),
        ),
      ),
    );
  }
}

/// Player options: playback speed, sleep timer and the queue ("up next", tap to jump).
Future<void> showPlayerOptions(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PlayerOptionsSheet(),
    );

class _PlayerOptionsSheet extends ConsumerWidget {
  const _PlayerOptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final s = ref.watch(audioProvider);
    final ctrl = ref.read(audioProvider.notifier);
    final sleepLeft = s.sleepAt?.difference(DateTime.now());
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
          Text(l.playbackSpeed, style: context.sans(13, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final v in const [0.75, 1.0, 1.25, 1.5])
              ChoiceChip(key: ValueKey('speed-$v'), label: Text('${v}x'), selected: s.speed == v, onSelected: (_) => ctrl.setSpeed(v)),
          ]),
          const SizedBox(height: 14),
          Text(sleepLeft != null && !sleepLeft.isNegative ? '${l.sleepTimer} · ${Formatters.duration(sleepLeft)}' : l.sleepTimer, style: context.sans(13, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            ChoiceChip(label: Text(l.off), selected: s.sleepAt == null && !s.sleepAfterTrack, onSelected: (_) => ctrl.setSleepTimer(null)),
            for (final m in const [15, 30, 60])
              ChoiceChip(label: Text(l.minutesShort(m)), selected: false, onSelected: (_) => ctrl.setSleepTimer(Duration(minutes: m))),
            ChoiceChip(label: Text(l.sleepEndOfMezmur), selected: s.sleepAfterTrack, onSelected: (_) => ctrl.setSleepTimer(null, endOfTrack: true)),
          ]),
          if (s.queue.length > 1) ...[
            const SizedBox(height: 14),
            Text(l.upNext, style: context.sans(13, weight: FontWeight.w700)),
            // Grouped by folder: the category, then each subcategory, in the queue's order.
            for (var i = 0; i < s.queue.length; i++) ...[
              if (s.queue[i].subtitle != null && (i == 0 || s.queue[i - 1].subtitle != s.queue[i].subtitle))
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Row(children: [
                    Icon(Icons.folder_rounded, size: 16, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Expanded(child: Text(s.queue[i].subtitle!, style: context.sans(12, weight: FontWeight.w700, color: p.muted))),
                  ]),
                ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(i == s.index ? Icons.graphic_eq_rounded : Icons.music_note_rounded, color: i == s.index ? AppColors.gold : p.subtle),
                title: Text(s.queue[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.sans(14, weight: i == s.index ? FontWeight.w700 : FontWeight.w400)),
                subtitle: s.queue[i].subtitle == null ? null : Text(s.queue[i].subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: i == s.index ? null : () => ctrl.jumpTo(i),
              ),
            ],
          ],
        ]),
      ),
    );
  }
}

/// Time-synced lyrics (.lrc): the line being sung is highlighted and kept in view; tap a line to
/// jump there. Each line is listed once: when the singers repeat it, the highlight goes back to it.
/// Used while this Mezmur is the one playing.
class SyncedLyrics extends ConsumerStatefulWidget {
  const SyncedLyrics({super.key, required this.sheet, required this.trackId, this.scale = 1});
  final LrcSheet sheet;
  final int trackId;
  final double scale;
  @override
  ConsumerState<SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends ConsumerState<SyncedLyrics> {
  late final _keys = List.generate(widget.sheet.lines.length, (_) => GlobalKey());
  int _shown = -2;

  void _follow(int i) {
    if (i == _shown || i < 0 || i >= _keys.length) return;
    _shown = i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _keys[i].currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: 0.35, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final playing = ref.watch(audioProvider.select((s) => s.current?.id)) == widget.trackId;
    final pos = playing ? (ref.watch(positionProvider).value ?? Duration.zero) : Duration.zero;
    final current = playing ? widget.sheet.lineAt(pos) : -1;
    // Lines already sung at least once (repeats go back up: earlier lines are not greyed then).
    final sungBefore = <int>{for (final c in widget.sheet.cues) if (c.time <= pos) c.line};
    _follow(current);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < widget.sheet.lines.length; i++)
        InkWell(
          key: _keys[i],
          borderRadius: BorderRadius.circular(8),
          onTap: playing
              ? () {
                  final t = widget.sheet.seekFor(i, pos);
                  if (t != null) ref.read(audioProvider.notifier).seek(t);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: context.serif(
                (i == current ? 21 : 18) * widget.scale,
                weight: i == current ? FontWeight.w700 : FontWeight.w500,
                color: i == current ? AppColors.maroon : (sungBefore.contains(i) && i < current ? p.subtle : p.text),
                height: 1.5,
              ),
              child: Text(widget.sheet.lines[i].isEmpty ? '♪' : widget.sheet.lines[i]),
            ),
          ),
        ),
    ]);
  }
}
