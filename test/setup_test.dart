import 'package:test/test.dart';

import '../setup.dart' as setup;

void main() {
  group('setup.dart', () {
    test('parses -v as verbose mode', () {
      final results = setup.createSetupArgParser().parse(['android', '-v']);

      expect(results['verbose'], isTrue);
      expect(results.rest, ['android']);
    });

    test('omits verbose from flutter build args by default', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json', 'split-per-abi']);
    });

    test('adds verbose to flutter build args with -v', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        verbose: true,
      );

      expect(args, [
        'verbose',
        'dart-define-from-file=env.json',
        'split-per-abi',
      ]);
    });

    test('omits split-per-abi for Android app bundles', () {
      final args = setup.createFlutterBuildArgs(
        platform: 'android',
        target: 'aab',
        verbose: false,
      );

      expect(args, ['dart-define-from-file=env.json']);
    });

    test('splits comma separated package targets', () {
      expect(setup.createTargetList('apk, aab'), ['apk', 'aab']);
    });

    test('defaults Google Play to a universal app bundle', () {
      expect(setup.createAndroidBuildTargets(channel: 'googleplay'), ['aab']);
      expect(
        setup.resolveAndroidBuildArch(
          channel: 'googleplay',
          target: 'aab',
          requestedArch: 'arm64',
        ),
        isNull,
      );
    });

    test('defaults other Android channels to arm64 APKs', () {
      expect(setup.createAndroidBuildTargets(channel: 'official'), ['apk']);
      expect(setup.createAndroidBuildTargets(channel: 'samsung'), ['apk']);
      expect(setup.createAndroidBuildTargets(channel: 'transsion'), ['apk']);
      expect(
        setup.resolveAndroidBuildArch(
          channel: 'official',
          target: 'apk',
          requestedArch: null,
        ),
        'arm64',
      );
    });

    test('rejects non-AAB Google Play targets', () {
      expect(
        () => setup.createAndroidBuildTargets(
          channel: 'googleplay',
          customTargets: 'apk',
        ),
        throwsFormatException,
      );
    });

    test('adds ABI suffix to Android APK artifact names', () {
      expect(
        setup.createAndroidArtifactFileName(
          buildName: '0.0.8',
          channel: 'samsung',
          target: 'apk',
          buildArch: 'arm64',
        ),
        'HawkVPN-0.0.8-android-samsung-release-arm64-v8a.apk',
      );
    });

    test('keeps Android AAB artifact names universal', () {
      expect(
        setup.createAndroidArtifactFileName(
          buildName: '0.0.8',
          channel: 'googleplay',
          target: 'aab',
          buildArch: 'arm64',
        ),
        'HawkVPN-0.0.8-android-googleplay-release.aab',
      );
    });
  });
}
