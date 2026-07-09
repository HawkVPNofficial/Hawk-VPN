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
  });
}
