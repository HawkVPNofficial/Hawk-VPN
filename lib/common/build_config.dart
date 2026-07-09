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

const showGoogleAds = bool.fromEnvironment(
  'SHOW_GOOGLE_ADS',
  defaultValue: false,
);

const _debugBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const _releaseBannerAdUnitId = 'ca-app-pub-2702996863596684/2280126085';
const _debugRewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
const _releaseRewardedAdUnitId = 'ca-app-pub-2702996863596684/1238507158';
const _debugInterstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const _releaseInterstitialAdUnitId = '';

const configuredBannerAdUnitId = String.fromEnvironment(
  'ADMOB_BANNER_AD_UNIT_ID',
);
const configuredRewardedAdUnitId = String.fromEnvironment(
  'ADMOB_REWARDED_AD_UNIT_ID',
);
const configuredInterstitialAdUnitId = String.fromEnvironment(
  'ADMOB_INTERSTITIAL_AD_UNIT_ID',
);

String resolveBannerAdUnitId({required bool releaseMode}) {
  if (configuredBannerAdUnitId.isNotEmpty) return configuredBannerAdUnitId;
  return releaseMode ? _releaseBannerAdUnitId : _debugBannerAdUnitId;
}

String resolveRewardedAdUnitId({required bool releaseMode}) {
  if (configuredRewardedAdUnitId.isNotEmpty) return configuredRewardedAdUnitId;
  return releaseMode ? _releaseRewardedAdUnitId : _debugRewardedAdUnitId;
}

String resolveInterstitialAdUnitId({required bool releaseMode}) {
  if (configuredInterstitialAdUnitId.isNotEmpty) {
    return configuredInterstitialAdUnitId;
  }
  return releaseMode
      ? _releaseInterstitialAdUnitId
      : _debugInterstitialAdUnitId;
}
