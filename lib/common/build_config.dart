const showProfilesTab = bool.fromEnvironment(
  'SHOW_PROFILES_TAB',
  defaultValue: false,
);

const showFullTools = bool.fromEnvironment(
  'SHOW_FULL_TOOLS',
  defaultValue: false,
);

const dashboardModule = String.fromEnvironment(
  'DASHBOARD_MODULE',
  defaultValue: 'myproxy',
);

const useMyProxyDashboard = dashboardModule != 'legacy';

const appChannel = String.fromEnvironment(
  'APP_CHANNEL',
  defaultValue: 'official',
);

const showToponAds = bool.fromEnvironment(
  'SHOW_TOPON_ADS',
  defaultValue: false,
);

const _defaultToponAppId = 'h6a4b0451496a4';
const _defaultToponAppKey = 'aa9d6d33e888f3d8b951bda5f4cd5875b';
const _defaultToponBannerPlacementId = 'n6a4b046c1874b';
const _defaultToponRewardedPlacementId = 'n6a4b046acb85d';

const configuredToponAppId = String.fromEnvironment('TOPON_APP_ID');
const configuredToponAppKey = String.fromEnvironment('TOPON_APP_KEY');
const toponSdkDebugKey = String.fromEnvironment(
  'TOPON_SDK_DEBUG_KEY',
  defaultValue: 'dfa750a1dcd6771580b64070c71f9897328491c9',
);
const toponBannerPlacementId = String.fromEnvironment(
  'TOPON_BANNER_PLACEMENT_ID',
  defaultValue: _defaultToponBannerPlacementId,
);
const toponRewardedPlacementId = String.fromEnvironment(
  'TOPON_REWARDED_PLACEMENT_ID',
  defaultValue: _defaultToponRewardedPlacementId,
);

final toponAppId = configuredToponAppId.isNotEmpty
    ? configuredToponAppId
    : _defaultToponAppId;
final toponAppKey = configuredToponAppKey.isNotEmpty
    ? configuredToponAppKey
    : _defaultToponAppKey;
