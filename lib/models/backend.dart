import 'profile.dart';

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
  });

  factory BackendUser.fromJson(Map<String, dynamic> json) {
    return BackendUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      appSetId: json['appSetId']?.toString() ?? '',
      clientEmail: json['clientEmail']?.toString() ?? '',
      clientUuid: json['clientUuid']?.toString() ?? '',
      subId: json['subId']?.toString() ?? '',
      totalGb: (json['totalGb'] as num?)?.toInt() ?? 0,
      expiryTime: (json['expiryTime'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] == true,
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
}

class BackendSubscription {
  const BackendSubscription({required this.content, this.subscriptionInfo});

  final String content;
  final SubscriptionInfo? subscriptionInfo;
}
