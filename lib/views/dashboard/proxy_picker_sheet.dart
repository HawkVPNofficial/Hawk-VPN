import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:flutter/material.dart';

class DashboardProxyPickerSheet extends StatelessWidget {
  const DashboardProxyPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return ProxiesListView(
      cardType: ProxyCardType.min,
      iconStyle: ProxiesIconStyle.icon,
      onSelected: (groupName, _) {
        updateCurrentGroupName(groupName);
        Navigator.of(context).pop();
      },
      storageKey: const PageStorageKey<String>('dashboard_proxies_list'),
    );
  }
}
