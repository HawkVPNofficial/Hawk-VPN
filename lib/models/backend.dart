import 'profile.dart';

int _intFromJson(dynamic value, {int defaultValue = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int _timestampFromJson(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) {
    final timestamp = int.tryParse(value);
    if (timestamp != null) return timestamp;
    return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
  }
  return 0;
}

bool _boolFromJson(dynamic value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

class BackendResponse {
  const BackendResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory BackendResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return BackendResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: data is Map ? Map<String, dynamic>.from(data) : {},
    );
  }

  final bool success;
  final String message;
  final Map<String, dynamic> data;

  void throwIfFailed() {
    if (success) return;
    throw message.isNotEmpty ? message : 'backend request failed';
  }
}

class BackendRequestException implements Exception {
  const BackendRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendAuth {
  const BackendAuth({required this.tokenName, required this.tokenValue});

  factory BackendAuth.fromJson(Map<String, dynamic> json) {
    return BackendAuth(
      tokenName: json['tokenName']?.toString() ?? '',
      tokenValue: json['tokenValue']?.toString() ?? '',
    );
  }

  final String tokenName;
  final String tokenValue;

  bool get isValid => tokenName.isNotEmpty && tokenValue.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {'tokenName': tokenName, 'tokenValue': tokenValue};
  }
}

class BackendUser {
  const BackendUser({
    required this.id,
    required this.appSetId,
    required this.clientEmail,
    required this.clientUuid,
    required this.subId,
    required this.totalGb,
    required this.expiryTime,
    required this.enabled,
    required this.inviteCode,
    required this.inviteCodeSubmitted,
    required this.todayRewardBytes,
    required this.checkedInToday,
    required this.rewardedAdEnabled,
    required this.rewardedAdWatchedToday,
    required this.rewardedAdDailyLimit,
    required this.invitationSummary,
    required this.createdAt,
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: _intFromJson(json['id']),
      appSetId: json['appSetId']?.toString() ?? '',
      clientEmail: json['clientEmail']?.toString() ?? '',
      clientUuid: json['clientUuid']?.toString() ?? '',
      subId: json['subId']?.toString() ?? '',
      totalGb: _intFromJson(json['totalGb']),
      expiryTime: _intFromJson(json['expiryTime']),
      enabled: _boolFromJson(json['enabled']),
      inviteCode: json['inviteCode']?.toString() ?? '',
      inviteCodeSubmitted: _boolFromJson(json['inviteCodeSubmitted']),
      todayRewardBytes: _intFromJson(json['todayRewardBytes']),
      checkedInToday: _boolFromJson(json['checkedInToday']),
      rewardedAdEnabled: _boolFromJson(json['rewardedAdEnabled']),
      rewardedAdWatchedToday: _intFromJson(json['rewardedAdWatchedToday']),
      rewardedAdDailyLimit: _intFromJson(
        json['rewardedAdDailyLimit'],
        defaultValue: 3,
      ),
      invitationSummary: BackendInvitationSummary.fromJson(
        json['invitationSummary'] is Map
            ? Map<String, dynamic>.from(json['invitationSummary'] as Map)
            : const {},
      ),
      createdAt: _timestampFromJson(json['createdAt']),
    );
  }

  final int id;
  final String appSetId;
  final String clientEmail;
  final String clientUuid;
  final String subId;
  final int totalGb;
  final int expiryTime;
  final bool enabled;
  final String inviteCode;
  final bool inviteCodeSubmitted;
  final int todayRewardBytes;
  final bool checkedInToday;
  final bool rewardedAdEnabled;
  final int rewardedAdWatchedToday;
  final int rewardedAdDailyLimit;
  final BackendInvitationSummary invitationSummary;
  final int createdAt;
}

class BackendInvitationSummary {
  const BackendInvitationSummary({
    required this.successCount,
    required this.rewardTotalBytes,
  });

  factory BackendInvitationSummary.fromJson(Map<String, dynamic> json) {
    return BackendInvitationSummary(
      successCount: _intFromJson(json['successCount']),
      rewardTotalBytes: _intFromJson(json['rewardTotalBytes']),
    );
  }

  final int successCount;
  final int rewardTotalBytes;
}

class BackendAppConfig {
  const BackendAppConfig({
    required this.checkInRewardMb,
    required this.inviteRewardMb,
    required this.invitedRewardMb,
    required this.adRewardMb,
  });

  factory BackendAppConfig.defaults() {
    return const BackendAppConfig(
      checkInRewardMb: 30,
      inviteRewardMb: 500,
      invitedRewardMb: 500,
      adRewardMb: 50,
    );
  }

  factory BackendAppConfig.fromJson(Map<String, dynamic> json) {
    final defaults = BackendAppConfig.defaults();
    return BackendAppConfig(
      checkInRewardMb: _intFromJson(
        json['checkInRewardMb'],
        defaultValue: defaults.checkInRewardMb,
      ),
      inviteRewardMb: _intFromJson(
        json['inviteRewardMb'],
        defaultValue: defaults.inviteRewardMb,
      ),
      invitedRewardMb: _intFromJson(
        json['invitedRewardMb'],
        defaultValue: defaults.invitedRewardMb,
      ),
      adRewardMb: _intFromJson(
        json['adRewardMb'],
        defaultValue: defaults.adRewardMb,
      ),
    );
  }

  final int checkInRewardMb;
  final int inviteRewardMb;
  final int invitedRewardMb;
  final int adRewardMb;
}

class BackendTrafficReward {
  const BackendTrafficReward({
    required this.rewardType,
    required this.rewardBytes,
    required this.totalGb,
  });

  factory BackendTrafficReward.fromJson(Map<String, dynamic> json) {
    return BackendTrafficReward(
      rewardType: json['rewardType']?.toString() ?? '',
      rewardBytes: _intFromJson(json['rewardBytes']),
      totalGb: _intFromJson(json['totalGb']),
    );
  }

  final String rewardType;
  final int rewardBytes;
  final int totalGb;
}

class BackendAdRewardSession {
  const BackendAdRewardSession({
    required this.sessionId,
    required this.customData,
  });

  factory BackendAdRewardSession.fromJson(Map<String, dynamic> json) {
    return BackendAdRewardSession(
      sessionId: json['sessionId']?.toString() ?? '',
      customData: json['customData']?.toString() ?? '',
    );
  }

  final String sessionId;
  final String customData;
}

class BackendSubscription {
  const BackendSubscription({required this.content, this.subscriptionInfo});

  final String content;
  final SubscriptionInfo? subscriptionInfo;
}

class BackendUploadedFile {
  const BackendUploadedFile({
    required this.url,
    required this.originalFilename,
    required this.contentType,
    required this.size,
  });

  factory BackendUploadedFile.fromJson(Map<String, dynamic> json) {
    return BackendUploadedFile(
      url: json['url']?.toString() ?? '',
      originalFilename: json['originalFilename']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      size: _intFromJson(json['size']),
    );
  }

  final String url;
  final String originalFilename;
  final String contentType;
  final int size;
}
