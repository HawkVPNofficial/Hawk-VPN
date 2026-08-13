import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/topon_banner.dart';
import 'package:fl_clash/views/dashboard/proxy_picker_sheet.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _ConnectionDisplayState {
  noProfile,
  disconnected,
  connecting,
  connected,
  suspended,
}

class MyProxyDashboardView extends ConsumerWidget {
  const MyProxyDashboardView({super.key});

  static const _chartSampleCount = 30;

  void _toggleConnection(WidgetRef ref) {
    final isStart = ref.read(isStartProvider);
    debouncer.call(FunctionTag.updateStatus, () {
      globalState.container
          .read(setupActionProvider.notifier)
          .updateStatus(!isStart, isInit: !ref.read(initProvider));
    }, duration: commonDuration);
  }

  Future<void> _handleCoreConnection(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      return;
    }
    final tip = coreStatus == CoreStatus.connected
        ? context.appLocalizations.forceRestartCoreTip
        : context.appLocalizations.restartCoreTip;
    final res = await globalState.showMessage(message: TextSpan(text: tip));
    if (res != true) {
      return;
    }
    globalState.container.read(coreActionProvider.notifier).restartCore();
  }

  String _speedText(num bytesPerSecond, bool isStart) {
    if (!isStart) return '--';
    final mbps = bytesPerSecond * 8 / 1000 / 1000;
    return mbps.toStringAsFixed(1);
  }

  int? _bestDelay(DelayMap delayMap) {
    int? bestDelay;
    for (final urlDelayMap in delayMap.values) {
      for (final delay in urlDelayMap.values) {
        if (delay == null || delay <= 0) continue;
        bestDelay = bestDelay == null ? delay : min(bestDelay, delay);
      }
    }
    return bestDelay;
  }

  Widget _panel({required Widget child}) {
    return SizedBox(
      width: double.infinity,
      child: CommonCard(onPressed: () {}, child: child),
    );
  }

  Widget _buildCoreStatusAction(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Consumer(
      builder: (_, ref, _) {
        final coreStatus = ref.watch(coreStatusProvider);
        final icon = SizedBox(
          height: globalState.measure.bodyMediumHeight,
          width: globalState.measure.bodyMediumHeight,
          child: switch (coreStatus) {
            CoreStatus.connecting => Padding(
              padding: const EdgeInsets.all(2),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: context.colorScheme.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
            CoreStatus.connected => const Icon(
              Icons.restart_alt_sharp,
              fontWeight: FontWeight.w900,
            ),
            CoreStatus.disconnected => const Icon(
              Icons.restart_alt_sharp,
              fontWeight: FontWeight.w900,
            ),
          },
        );
        return Tooltip(
          message: appLocalizations.coreStatus,
          child: FadeScaleBox(
            alignment: Alignment.centerRight,
            child: coreStatus == CoreStatus.connected
                ? IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    onPressed: () => _handleCoreConnection(context, ref),
                    icon: icon,
                  )
                : FilledButton.icon(
                    key: ValueKey(coreStatus),
                    onPressed: coreStatus == CoreStatus.connecting
                        ? null
                        : () => _handleCoreConnection(context, ref),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: icon,
                    label: Text(switch (coreStatus) {
                      CoreStatus.connecting => appLocalizations.connecting,
                      CoreStatus.connected => appLocalizations.connected,
                      CoreStatus.disconnected => appLocalizations.disconnected,
                    }),
                  ),
          ),
        );
      },
    );
  }

  _ConnectionDisplayState _connectionState(WidgetRef ref) {
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    if (!hasProfile) {
      return _ConnectionDisplayState.noProfile;
    }
    final coreStatus = ref.watch(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      return _ConnectionDisplayState.connecting;
    }
    final isStart = ref.watch(isStartProvider);
    if (!isStart) {
      return _ConnectionDisplayState.disconnected;
    }
    final suspend = ref.watch(suspendProvider);
    if (suspend) {
      return _ConnectionDisplayState.suspended;
    }
    return _ConnectionDisplayState.connected;
  }

  String _connectionTitle(BuildContext context, _ConnectionDisplayState state) {
    final appLocalizations = context.appLocalizations;
    return switch (state) {
      _ConnectionDisplayState.noProfile => appLocalizations.profiles,
      _ConnectionDisplayState.disconnected => appLocalizations.disconnected,
      _ConnectionDisplayState.connecting => appLocalizations.connecting,
      _ConnectionDisplayState.connected => appLocalizations.connected,
      _ConnectionDisplayState.suspended => appLocalizations.suspended,
    };
  }

  String _connectionDesc(
    BuildContext context,
    WidgetRef ref,
    _ConnectionDisplayState state,
  ) {
    final appLocalizations = context.appLocalizations;
    return switch (state) {
      _ConnectionDisplayState.noProfile => appLocalizations.nullProfileDesc,
      _ConnectionDisplayState.disconnected => appLocalizations.start,
      _ConnectionDisplayState.connecting => appLocalizations.coreStatus,
      _ConnectionDisplayState.connected => utils.getTimeText(
        ref.watch(runTimeProvider),
      ),
      _ConnectionDisplayState.suspended => appLocalizations.stop,
    };
  }

  Widget _buildConnectionCard(BuildContext context, WidgetRef ref) {
    final state = _connectionState(ref);
    final subscriptionEnabled = ref.watch(
      backendUserStateProvider.select((user) => user?.enabled ?? true),
    );
    final enabled =
        state != _ConnectionDisplayState.noProfile &&
        state != _ConnectionDisplayState.connecting &&
        subscriptionEnabled;
    final isConnected = state == _ConnectionDisplayState.connected;
    return _panel(
      child: Padding(
        padding: baseInfoEdgeInsets,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnected)
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _ConnectionButton(
                      state: state,
                      compact: true,
                      onPressed: enabled ? () => _toggleConnection(ref) : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    flex: 3,
                    child: _SelectedProxyButton(connected: true),
                  ),
                ],
              )
            else
              _ConnectionButton(
                state: state,
                onPressed: enabled ? () => _toggleConnection(ref) : null,
              ),
            const SizedBox(height: 16),
            Text(
              _connectionTitle(context, state),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium?.toSoftBold,
            ),
            const SizedBox(height: 4),
            Text(
              _connectionDesc(context, ref, state),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.toLight.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (!isConnected) ...[
              const SizedBox(height: 18),
              const _SelectedProxyButton(connected: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isStart = ref.watch(isStartProvider);
    final traffics = ref.watch(trafficsProvider).list;
    final traffic = traffics.isEmpty ? const Traffic() : traffics.last;
    final bestDelay = _bestDelay(ref.watch(delayDataSourceProvider));
    final items = [
      (
        value: _speedText(traffic.down, isStart),
        label: '${appLocalizations.download} Mb/s',
      ),
      (
        value: _speedText(traffic.up, isStart),
        label: '${appLocalizations.upload} Mb/s',
      ),
      (
        value: isStart && bestDelay != null ? '$bestDelay' : '--',
        label: '${appLocalizations.delay} ms',
      ),
    ];
    return _panel(
      child: Padding(
        padding: baseInfoEdgeInsets,
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleLarge?.toSoftBold.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.toLight,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider).list;
    final downloadColor = context.colorScheme.primary;
    final uploadColor = context.colorScheme.tertiary;
    return SizedBox(
      height: getWidgetHeight(2),
      child: _panel(
        child: Column(
          children: [
            InfoHeader(
              padding: baseInfoEdgeInsets.copyWith(bottom: 0),
              info: Info(
                label: appLocalizations.networkSpeed,
                iconData: Icons.speed_sharp,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: CustomPaint(
                  painter: _SpeedChartPainter(
                    traffics: traffics
                        .takeLast(count: _chartSampleCount)
                        .toList(),
                    downloadColor: downloadColor,
                    uploadColor: uploadColor,
                    gridColor: context.colorScheme.outlineVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Padding(
              padding: baseInfoEdgeInsets.copyWith(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendItem(
                    color: downloadColor,
                    label: appLocalizations.download,
                  ),
                  const SizedBox(width: 28),
                  _LegendItem(
                    color: uploadColor,
                    label: appLocalizations.upload,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      title: context.appLocalizations.dashboard,
      actions: [_buildCoreStatusAction(context)],
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16).copyWith(bottom: 88),
          child: Column(
            children: [
              _buildConnectionCard(context, ref),
              const SizedBox(height: 16),
              _buildStats(context, ref),
              const SizedBox(height: 16),
              _buildChart(context, ref),
              const SizedBox(height: 16),
              const DashboardToponBanner(),
              const _QuotaPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotaPanel extends ConsumerStatefulWidget {
  const _QuotaPanel();

  @override
  ConsumerState<_QuotaPanel> createState() => _QuotaPanelState();
}

class _QuotaPanelState extends ConsumerState<_QuotaPanel> {
  bool _isRefreshing = false;

  String _trafficQuotaText(int value) {
    final units = [
      (label: 'MB', divisor: pow(1024, 2)),
      (label: 'GB', divisor: pow(1024, 3)),
      (label: 'TB', divisor: pow(1024, 4)),
    ];
    var selected = units.first;
    for (final unit in units) {
      if (value >= unit.divisor) {
        selected = unit;
      }
    }
    return '${(value / selected.divisor).toStringAsFixed(3)} ${selected.label}';
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    try {
      await ref
          .read(profilesActionProvider.notifier)
          .syncBackendProfile(retryOnFailure: false);
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final subscriptionInfo = ref.watch(
      currentProfileProvider.select((profile) => profile?.subscriptionInfo),
    );
    final total = ref.watch(
      backendUserStateProvider.select((user) => user?.totalGb ?? 0),
    );
    final downloaded = subscriptionInfo?.download ?? 0;
    final remaining = max(total - downloaded, 0);
    final progress = total > 0
        ? (downloaded / total).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return SizedBox(
      width: double.infinity,
      child: CommonCard(
        onPressed: () {},
        child: Padding(
          padding: baseInfoEdgeInsets,
          child: Column(
            children: [
              InfoHeader(
                padding: baseInfoEdgeInsets.copyWith(
                  left: 0,
                  top: 8.mAp,
                  right: 0,
                  bottom: 8.mAp,
                ),
                info: Info(
                  label: appLocalizations.trafficUsage,
                  iconData: Icons.data_saver_off,
                ),
                actions: [
                  IconButton(
                    tooltip: appLocalizations.update,
                    visualDensity: VisualDensity.compact,
                    onPressed: _isRefreshing ? null : _refresh,
                    icon: _isRefreshing
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _QuotaRow(
                label: appLocalizations.totalTraffic,
                value: total > 0 ? _trafficQuotaText(total) : '--',
              ),
              const SizedBox(height: 10),
              _QuotaRow(
                label: appLocalizations.remainingTraffic,
                value: total > 0 ? _trafficQuotaText(remaining) : '--',
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress,
                  backgroundColor: context.colorScheme.primary.opacity15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.state,
    this.onPressed,
    this.compact = false,
  });

  final _ConnectionDisplayState state;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final loading = state == _ConnectionDisplayState.connecting;
    final icon = switch (state) {
      _ConnectionDisplayState.noProfile => Icons.play_disabled_sharp,
      _ConnectionDisplayState.disconnected => Icons.play_arrow_rounded,
      _ConnectionDisplayState.connecting => null,
      _ConnectionDisplayState.connected => Icons.pause_rounded,
      _ConnectionDisplayState.suspended => Icons.pause_circle_filled_rounded,
    };
    final backgroundColor = switch (state) {
      _ConnectionDisplayState.noProfile => colorScheme.surfaceContainerHighest,
      _ConnectionDisplayState.disconnected => colorScheme.primaryContainer,
      _ConnectionDisplayState.connecting => colorScheme.primaryContainer,
      _ConnectionDisplayState.connected => colorScheme.primary,
      _ConnectionDisplayState.suspended => colorScheme.secondaryContainer,
    };
    final foregroundColor = switch (state) {
      _ConnectionDisplayState.noProfile => colorScheme.onSurfaceVariant,
      _ConnectionDisplayState.disconnected => colorScheme.onPrimaryContainer,
      _ConnectionDisplayState.connecting => colorScheme.onPrimaryContainer,
      _ConnectionDisplayState.connected => colorScheme.onPrimary,
      _ConnectionDisplayState.suspended => colorScheme.onSecondaryContainer,
    };
    return SizedBox.square(
      dimension: compact ? 64 : 112,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: backgroundColor,
          disabledForegroundColor: foregroundColor.opacity60,
        ),
        child: AnimatedSwitcher(
          duration: midDuration,
          child: loading
              ? SizedBox.square(
                  key: const ValueKey('loading'),
                  dimension: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: foregroundColor,
                  ),
                )
              : Icon(key: ValueKey(icon), icon, size: compact ? 30 : 44),
        ),
      ),
    );
  }
}

class _SelectedProxyButton extends ConsumerWidget {
  const _SelectedProxyButton({required this.connected});

  final bool connected;

  void _showPicker(BuildContext context) {
    showSheet(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.62,
          child: AdaptiveSheetScaffold(
            title: context.appLocalizations.proxies,
            body: const DashboardProxyPickerSheet(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupName = ref.watch(
      currentProfileProvider.select((profile) => profile?.currentGroupName),
    );
    final group = ref.watch(
      groupsProvider.select((groups) {
        if (groupName == null) return null;
        return groups.getGroup(groupName);
      }),
    );
    final effectiveGroupName = groupName ?? '';
    final proxyName = effectiveGroupName.isEmpty
        ? ''
        : ref.watch(selectedProxyNameProvider(effectiveGroupName)) ?? '';
    final label = proxyName.takeFirstValid([
      effectiveGroupName,
      context.appLocalizations.proxies,
    ]);
    final colorScheme = context.colorScheme;
    return SizedBox(
      height: connected ? 64 : 48,
      child: FilledButton.tonal(
        onPressed: () => _showPicker(context),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: connected ? 14 : 16),
          foregroundColor: connected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
          backgroundColor: connected
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(connected ? 28 : 24),
          ),
        ),
        child: Row(
          mainAxisSize: connected ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (group?.icon.isNotEmpty == true) ...[
              SizedBox.square(
                dimension: connected ? 34 : 24,
                child: CommonTargetIcon(src: group!.icon),
              ),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: EmojiText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (connected
                            ? context.textTheme.titleMedium
                            : context.textTheme.labelLarge)
                        ?.toSoftBold,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.toLight,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: context.textTheme.bodyMedium?.toSoftBold.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _SpeedChartPainter extends CustomPainter {
  const _SpeedChartPainter({
    required this.traffics,
    required this.downloadColor,
    required this.uploadColor,
    required this.gridColor,
  });

  final List<Traffic> traffics;
  final Color downloadColor;
  final Color uploadColor;
  final Color gridColor;

  List<Offset> _points(List<num> values, Size size, double maxValue) {
    if (values.isEmpty) {
      return const [];
    }
    if (values.length == 1) {
      return [Offset(size.width, size.height)];
    }
    final step = size.width / (values.length - 1);
    return values.asMap().entries.map((entry) {
      final x = entry.key * step;
      final y = size.height - (entry.value / maxValue) * (size.height - 12);
      return Offset(x, y.clamp(0, size.height).toDouble());
    }).toList();
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    return path;
  }

  void _drawLine({
    required Canvas canvas,
    required Size size,
    required List<Offset> points,
    required Color color,
  }) {
    if (points.isEmpty) return;
    final path = _smoothPath(points);
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.opacity30, color.opacity0],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.opacity60
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final paddedTraffics = traffics.isEmpty
        ? List<Traffic>.filled(
            MyProxyDashboardView._chartSampleCount,
            const Traffic(),
          )
        : [
            ...List<Traffic>.filled(
              max(MyProxyDashboardView._chartSampleCount - traffics.length, 0),
              const Traffic(),
            ),
            ...traffics,
          ];
    final downValues = paddedTraffics.map((traffic) => traffic.down).toList();
    final upValues = paddedTraffics.map((traffic) => traffic.up).toList();
    final maxValue = max<num>(
      1,
      [...downValues, ...upValues].fold<num>(0, max),
    ).toDouble();

    _drawLine(
      canvas: canvas,
      size: size,
      points: _points(downValues, size, maxValue),
      color: downloadColor,
    );
    _drawLine(
      canvas: canvas,
      size: size,
      points: _points(upValues, size, maxValue),
      color: uploadColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeedChartPainter oldDelegate) {
    return oldDelegate.traffics != traffics ||
        oldDelegate.downloadColor != downloadColor ||
        oldDelegate.uploadColor != uploadColor ||
        oldDelegate.gridColor != gridColor;
  }
}
