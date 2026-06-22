import 'package:fl_clash/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('BackendUser', () {
    test('parses 0.0.2 fields', () {
      final user = BackendUser.fromJson({
        'id': 1,
        'appSetId': 'device-id',
        'clientEmail': 'client@example.com',
        'clientUuid': 'uuid',
        'subId': 'sub',
        'totalGb': 1024,
        'expiryTime': 123,
        'enabled': true,
        'inviteCode': 'ABC-123',
        'inviteCodeSubmitted': true,
        'todayRewardBytes': 104857600,
        'checkedInToday': true,
        'rewardedAdEnabled': true,
        'rewardedAdWatchedToday': 2,
        'rewardedAdDailyLimit': 3,
        'createdAt': 1710000000000,
        'invitationSummary': {
          'successCount': 2,
          'rewardTotalBytes': 1048576000,
        },
      });

      expect(user.inviteCode, 'ABC-123');
      expect(user.inviteCodeSubmitted, isTrue);
      expect(user.todayRewardBytes, 104857600);
      expect(user.checkedInToday, isTrue);
      expect(user.rewardedAdEnabled, isTrue);
      expect(user.rewardedAdWatchedToday, 2);
      expect(user.rewardedAdDailyLimit, 3);
      expect(user.createdAt, 1710000000000);
      expect(user.invitationSummary.successCount, 2);
      expect(user.invitationSummary.rewardTotalBytes, 1048576000);
    });

    test('keeps backward compatibility with old response', () {
      final user = BackendUser.fromJson(const {});

      expect(user.inviteCode, isEmpty);
      expect(user.inviteCodeSubmitted, isFalse);
      expect(user.todayRewardBytes, 0);
      expect(user.checkedInToday, isFalse);
      expect(user.rewardedAdEnabled, isFalse);
      expect(user.rewardedAdWatchedToday, 0);
      expect(user.rewardedAdDailyLimit, 3);
      expect(user.createdAt, 0);
      expect(user.invitationSummary.successCount, 0);
      expect(user.invitationSummary.rewardTotalBytes, 0);
    });

    test('parses numeric strings from backend', () {
      final user = BackendUser.fromJson({
        'id': '1',
        'totalGb': '53687091200',
        'expiryTime': '1812542951658',
        'todayRewardBytes': '104857600',
        'checkedInToday': 'true',
        'rewardedAdEnabled': 'true',
        'rewardedAdWatchedToday': '2',
        'rewardedAdDailyLimit': '3',
        'createdAt': '1710000000000',
        'invitationSummary': {
          'successCount': '3',
          'rewardTotalBytes': '1572864000',
        },
      });

      expect(user.id, 1);
      expect(user.totalGb, 53687091200);
      expect(user.expiryTime, 1812542951658);
      expect(user.todayRewardBytes, 104857600);
      expect(user.checkedInToday, isTrue);
      expect(user.rewardedAdEnabled, isTrue);
      expect(user.rewardedAdWatchedToday, 2);
      expect(user.rewardedAdDailyLimit, 3);
      expect(user.createdAt, 1710000000000);
      expect(user.invitationSummary.successCount, 3);
      expect(user.invitationSummary.rewardTotalBytes, 1572864000);
    });

    test('parses actual 0.0.2 response shape', () {
      final user = BackendUser.fromJson({
        'id': 2,
        'appSetId': '311a914a017a559f',
        'clientEmail': 'app_311a914a017a559f_be2ba2a0',
        'clientUuid': '763f390c-bfac-40b9-a37f-054d8e0eed9b',
        'subId': 'bf46f2ed-328b-4a70-aee9-6e7d2eb03939',
        'totalGb': 524288000,
        'expiryTime': 1783761352383,
        'enabled': true,
        'createdAt': '2026-06-11T17:15:53',
        'inviteCode': 'XFM-FFL',
        'inviteCodeSubmitted': false,
        'checkedInToday': false,
        'rewardedAdEnabled': true,
        'rewardedAdWatchedToday': 1,
        'rewardedAdDailyLimit': 3,
        'todayRewardBytes': 0,
        'invitationSummary': {'successCount': 0, 'rewardTotalBytes': 0},
      });

      expect(user.appSetId, '311a914a017a559f');
      expect(user.totalGb, 524288000);
      expect(user.createdAt, greaterThan(0));
      expect(user.inviteCode, 'XFM-FFL');
      expect(user.inviteCodeSubmitted, isFalse);
      expect(user.checkedInToday, isFalse);
      expect(user.rewardedAdEnabled, isTrue);
      expect(user.rewardedAdWatchedToday, 1);
      expect(user.rewardedAdDailyLimit, 3);
    });
  });

  group('BackendAdRewardSession', () {
    test('parses session fields', () {
      final session = BackendAdRewardSession.fromJson(const {
        'sessionId': 'session-1',
        'customData': 'custom-data',
      });

      expect(session.sessionId, 'session-1');
      expect(session.customData, 'custom-data');
    });
  });

  group('BackendAppConfig', () {
    test('uses defaults for missing fields', () {
      final config = BackendAppConfig.fromJson(const {});

      expect(config.checkInRewardMb, 30);
      expect(config.inviteRewardMb, 500);
      expect(config.invitedRewardMb, 500);
      expect(config.adRewardMb, 50);
    });
  });

  group('BackendTrafficReward', () {
    test('parses numeric strings', () {
      final reward = BackendTrafficReward.fromJson(const {
        'rewardType': 'CHECK_IN',
        'rewardBytes': '104857600',
        'totalGb': '53687091200',
      });

      expect(reward.rewardBytes, 104857600);
      expect(reward.totalGb, 53687091200);
    });
  });

  test('BackendRequestException displays clean message', () {
    expect(const BackendRequestException('邀请码不存在').toString(), '邀请码不存在');
  });
}
