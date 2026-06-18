import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/views.dart';
import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'build_config.dart';

class Navigation {
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) {
    return [
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.space_dashboard),
        label: PageLabel.dashboard,
        builder: (_) =>
            const DashboardView(key: GlobalObjectKey(PageLabel.dashboard)),
      ),
      NavigationItem(
        icon: const Icon(Icons.account_balance_wallet),
        label: PageLabel.free,
        builder: (_) =>
            const FreeTrafficView(key: GlobalObjectKey(PageLabel.free)),
        modes: const [NavigationItemMode.mobile],
      ),
      NavigationItem(
        icon: const Icon(Icons.person_add),
        label: PageLabel.invite,
        builder: (_) =>
            const InviteView(key: GlobalObjectKey(PageLabel.invite)),
        modes: const [NavigationItemMode.mobile],
      ),
      NavigationItem(
        icon: const Icon(Icons.article),
        label: PageLabel.proxies,
        builder: (_) =>
            const ProxiesView(key: GlobalObjectKey(PageLabel.proxies)),
        modes: hasProxies
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.folder),
        label: PageLabel.profiles,
        builder: (_) =>
            const ProfilesView(key: GlobalObjectKey(PageLabel.profiles)),
        modes: showProfilesTab
            ? const [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : const [],
      ),
      NavigationItem(
        icon: const Icon(Icons.view_timeline),
        label: PageLabel.requests,
        builder: (_) =>
            const RequestsView(key: GlobalObjectKey(PageLabel.requests)),
        description: 'requestsDesc',
        modes: [NavigationItemMode.desktop, NavigationItemMode.more],
      ),
      NavigationItem(
        icon: const Icon(Icons.ballot),
        label: PageLabel.connections,
        builder: (_) =>
            const ConnectionsView(key: GlobalObjectKey(PageLabel.connections)),
        description: 'connectionsDesc',
        modes: [NavigationItemMode.desktop, NavigationItemMode.more],
      ),
      NavigationItem(
        icon: const Icon(Icons.storage),
        label: PageLabel.resources,
        description: 'resourcesDesc',
        builder: (_) =>
            const ResourcesView(key: GlobalObjectKey(PageLabel.resources)),
        modes: [NavigationItemMode.more],
      ),
      NavigationItem(
        icon: const Icon(Icons.adb),
        label: PageLabel.logs,
        builder: (_) => const LogsView(key: GlobalObjectKey(PageLabel.logs)),
        description: 'logsDesc',
        modes: openLogs
            ? [NavigationItemMode.desktop, NavigationItemMode.more]
            : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.construction),
        label: PageLabel.tools,
        builder: (_) => const ToolsView(key: GlobalObjectKey(PageLabel.tools)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();

String getPageLabelText(PageLabel label) {
  final appLocalizations = currentAppLocalizations;
  return switch (label) {
    PageLabel.dashboard => appLocalizations.dashboard,
    PageLabel.free => appLocalizations.free,
    PageLabel.invite => appLocalizations.invite,
    PageLabel.proxies => appLocalizations.proxies,
    PageLabel.profiles => appLocalizations.profiles,
    PageLabel.tools => appLocalizations.tools,
    PageLabel.logs => appLocalizations.logs,
    PageLabel.requests => appLocalizations.requests,
    PageLabel.resources => appLocalizations.resources,
    PageLabel.connections => appLocalizations.connections,
  };
}
