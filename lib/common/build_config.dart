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
