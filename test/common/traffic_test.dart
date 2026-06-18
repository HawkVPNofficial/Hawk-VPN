import 'package:fl_clash/common/common.dart';
import 'package:test/test.dart';

void main() {
  test('formatTrafficBytes formats MB GB and TB', () {
    expect(formatTrafficBytes(30 * 1024 * 1024), '30.000 MB');
    expect(formatTrafficBytes(5 * 1024 * 1024 * 1024), '5.000 GB');
    expect(formatTrafficBytes(2 * 1024 * 1024 * 1024 * 1024), '2.000 TB');
  });
}
