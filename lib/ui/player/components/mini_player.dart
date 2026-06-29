import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:velqi/ui/screens/Settings/settings_screen_controller.dart';
import 'package:ionicons/ionicons.dart';

import '/ui/widgets/lyrics_dialog.dart';
import '/ui/widgets/song_info_dialog.dart';
import '/ui/player/player_controller.dart';
import '../../widgets/add_to_playlist.dart';
import '../../widgets/sleep_timer_bottom_sheet.dart';
import '../../widgets/song_download_btn.dart';
import '../../widgets/image_widget.dart';
import '../../widgets/mini_player_progress_bar.dart';
import 'animated_play_button.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    final size = MediaQuery.of(context).size;
    final wide = size.width > 800;
    final bottomNav =
        Get.find<SettingsScreenController>().isBottomNavBarEnabled.isTrue;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Obx(() {
      return Visibility(
        visible: pc.isPlayerpanelTopVisible.value,
        child: AnimatedOpacity(
          opacity: pc.playerPaneOpacity.value,
          duration: Duration.zero,
          child: Container(
            height: pc.playerPanelMinHeight.value,
            width: size.width,
            decoration: BoxDecoration(
              color: Theme.of(context).bottomSheetTheme.backgroundColor,
              border: Border(
                top: BorderSide(
                  color: cs.outline.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Progress bar ──
                if (!wide || bottomNav)
                  GetX<PlayerController>(
                    builder: (c) => MiniPlayerProgressBar(
                      progressBarStatus: c.progressBarStatus.value,
                      progressBarColor:
                          Theme.of(context).progressIndicatorTheme.color ??
                              cs.onSurface,
                    ),
                  ),
                if (wide && !bottomNav)
                  GetX<PlayerController>(
                    builder: (c) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ProgressBar(
                        timeLabelLocation: TimeLabelLocation.sides,
                        thumbRadius: 5,
                        barHeight: 3,
                        thumbGlowRadius: 0,
                        baseBarColor: cs.outline.withValues(alpha: 0.15),
                        bufferedBarColor: cs.outline.withValues(alpha: 0.25),
                        progressBarColor: cs.onSurface,
                        thumbColor: cs.onSurface,
                        timeLabelTextStyle:
                            tt.titleMedium?.copyWith(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                        progress: c.progressBarStatus.value.current,
                        total: c.progressBarStatus.value.total,
                        buffered: c.progressBarStatus.value.buffered,
                        onSeek: c.seek,
                      ),
                    ),
                  ),

                // ── Content row ──
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: wide ? 16 : 8, vertical: 0),
                    child: Row(
                      children: [
                        // Album art with rounded corners
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _art(pc),
                        ),
                        const SizedBox(width: 12),

                        // Song info
                        Expanded(
                          child: GestureDetector(
                            onTap: () => pc.playerPanelController.open(),
                            onHorizontalDragEnd: (d) {
                              if (d.primaryVelocity! < 0) pc.next();
                              if (d.primaryVelocity! > 0) pc.prev();
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pc.currentSong.value?.title ?? "",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  pc.currentSong.value?.artist ?? "",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Controls
                        if (wide && !bottomNav)
                          _desktop(pc, size, cs, context)
                        else
                          _mobile(pc, cs),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Widget _art(PlayerController pc) {
    return pc.currentSong.value != null
        ? ImageWidget(size: 46, song: pc.currentSong.value!)
        : const SizedBox(width: 46, height: 46);
  }

  /// Consistent icon button for the mini-player.
  Widget _iconBtn({
    required IconData icon,
    required double iconSize,
    required VoidCallback? onPressed,
    required ColorScheme cs,
    bool disabled = false,
    bool faded = false,
  }) {
    return IconButton(
      iconSize: iconSize,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 18,
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: disabled || faded
            ? cs.onSurface.withValues(alpha: disabled ? 0.2 : 0.35)
            : cs.onSurface,
      ),
    );
  }

  // ── MOBILE ──────────────────────────────────────────────────────────────

  Widget _mobile(PlayerController pc, ColorScheme cs) {
    final isFirst = pc.currentQueue.isEmpty ||
        pc.currentQueue.first.id == pc.currentSong.value?.id;
    final isLast = pc.currentQueue.isEmpty ||
        (!(pc.isShuffleModeEnabled.isTrue || pc.isQueueLoopModeEnabled.isTrue) &&
            pc.currentQueue.last.id == pc.currentSong.value?.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(
          icon: Icons.skip_previous_rounded,
          iconSize: 24,
          onPressed: isFirst ? null : pc.prev,
          disabled: isFirst,
          cs: cs,
        ),
        const SizedBox(width: 2),
        SizedBox(
          width: 40,
          height: 40,
          child: AnimatedPlayButton(iconSize: 28, color: cs.onSurface),
        ),
        const SizedBox(width: 2),
        _iconBtn(
          icon: Icons.skip_next_rounded,
          iconSize: 24,
          onPressed: isLast ? null : pc.next,
          disabled: isLast,
          cs: cs,
        ),
        const SizedBox(width: 6),
        _iconBtn(
          icon: Icons.close_rounded,
          iconSize: 20,
          onPressed: pc.stopPlayback,
          faded: true,
          cs: cs,
        ),
      ],
    );
  }

  // ── DESKTOP ─────────────────────────────────────────────────────────────

  Widget _desktop(PlayerController pc, Size size, ColorScheme cs, BuildContext context) {
    final isFirst = pc.currentQueue.isEmpty ||
        pc.currentQueue.first.id == pc.currentSong.value?.id;
    final isLast = pc.currentQueue.isEmpty ||
        (!(pc.isShuffleModeEnabled.isTrue || pc.isQueueLoopModeEnabled.isTrue) &&
            pc.currentQueue.last.id == pc.currentSong.value?.id);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(icon: Icons.favorite_border_rounded, iconSize: 20,
          onPressed: pc.toggleFavourite, cs: cs,
        ),
        const SizedBox(width: 4),
        _iconBtn(icon: Ionicons.shuffle, iconSize: 20,
          onPressed: pc.toggleShuffleMode, cs: cs,
          faded: !pc.isShuffleModeEnabled.value,
        ),
        const SizedBox(width: 8),
        _iconBtn(icon: Icons.skip_previous_rounded, iconSize: 24,
          onPressed: isFirst ? null : pc.prev, disabled: isFirst, cs: cs,
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 42,
          height: 42,
          child: AnimatedPlayButton(iconSize: 30, color: cs.onSurface),
        ),
        const SizedBox(width: 6),
        _iconBtn(icon: Icons.skip_next_rounded, iconSize: 24,
          onPressed: isLast ? null : pc.next, disabled: isLast, cs: cs,
        ),
        const SizedBox(width: 8),
        _iconBtn(icon: Icons.all_inclusive_rounded, iconSize: 20,
          onPressed: pc.toggleLoopMode, cs: cs,
          faded: !pc.isLoopModeEnabled.value,
        ),
        _iconBtn(icon: Icons.lyrics_outlined, iconSize: 20,
          onPressed: () {
            pc.showLyrics();
            showDialog(context: context, builder: (_) => const LyricsDialog())
                .whenComplete(() { pc.isDesktopLyricsDialogOpen = false; pc.showLyricsflag.value = false; });
            pc.isDesktopLyricsDialogOpen = true;
          },
          cs: cs, faded: true,
        ),
        const SizedBox(width: 8),
        _vol(pc, size, cs, context),
        const SizedBox(width: 6),
        _iconBtn(icon: Icons.queue_music_rounded, iconSize: 20,
          onPressed: () => pc.homeScaffoldkey.currentState!.openEndDrawer(),
          cs: cs, faded: true,
        ),
        if (size.width > 860)
          _iconBtn(icon: Icons.timer_outlined, iconSize: 20,
            onPressed: () {
              showModalBottomSheet(
                constraints: const BoxConstraints(maxWidth: 500),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                isScrollControlled: true,
                context: pc.homeScaffoldkey.currentState!.context,
                barrierColor: Colors.black87,
                builder: (_) => const SleepTimerBottomSheet(),
              );
            },
            cs: cs, faded: true,
          ),
        const SongDownloadButton(calledFromPlayer: true),
        _iconBtn(icon: Icons.playlist_add_rounded, iconSize: 20,            onPressed: () {
              final s = pc.currentSong.value;
              if (s != null) {
                showDialog(context: context, builder: (_) => AddToPlaylist([s]))
                    .whenComplete(() => Get.delete<AddToPlaylistController>());
              }
            },
            cs: cs, faded: true,
          ),
        if (size.width > 965)
          _iconBtn(icon: Icons.info_outline_rounded, iconSize: 20,
            onPressed: () {
              final s = pc.currentSong.value;
              if (s != null) {
                showDialog(context: context, builder: (_) => SongInfoDialog(song: s));
              }
            },
            cs: cs, faded: true,
          ),
        _iconBtn(icon: Icons.close_rounded, iconSize: 20,
          onPressed: pc.stopPlayback, cs: cs, faded: true,
        ),
      ],
    );
  }

  Widget _vol(PlayerController pc, Size size, ColorScheme cs, BuildContext context) {
    return SizedBox(
      width: size.width > 860 ? 140 : 100,
      child: Obx(() {
        final v = pc.volume.value;
        return Row(
          children: [
            GestureDetector(
              onTap: pc.mute,
              child: Icon(
                v == 0 ? Icons.volume_off_rounded : v < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded,
                size: 18, color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                ),
                child: Slider(value: v / 100, onChanged: (val) => pc.setVolume((val * 100).toInt())),
              ),
            ),
          ],
        );
      }),
    );
  }
}
