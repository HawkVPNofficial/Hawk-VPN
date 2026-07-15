import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

const _allTargets = <String, String>{
  'android': 'apk',
  'linux': 'deb', // appimage + rpm added for amd64 only
  'macos': 'dmg',
  'windows': 'exe,zip',
};

const _androidChannels = [
  'official',
  'cashcat',
  'oppo',
  'xiaomi',
  'googleplay',
  'vivo',
  'apkpure',
];

const _androidFlutterTarget = {
  'arm': 'android-arm',
  'arm64': 'android-arm64',
  'amd64': 'android-x64',
};

const _defaultBannerAdUnitId = 'ca-app-pub-2702996863596684/2280126085';
const _defaultRewardedAdUnitId = 'ca-app-pub-2702996863596684/1238507158';
const _defaultInterstitialAdUnitId = '';

const _hostPlatform = {
  'linux': 'linux',
  'macos': 'macos',
  'windows': 'windows',
};

Future<void> main(List<String> args) async {
  final parser = createSetupArgParser();

  if (args.contains('--help') || args.contains('-h')) {
    _showHelp(parser);
    exit(0);
  }

  final results = parser.parse(args);
  final rest = results.rest;

  final hostOs = Platform.operatingSystem;
  final host = _hostPlatform[hostOs];
  if (host == null) {
    stderr.writeln('Unsupported host platform: $hostOs');
    exit(1);
  }

  final platform = rest.isNotEmpty ? rest.first : host;

  if (platform != host && platform != 'android') {
    stderr.writeln(
      'Cannot build "$platform" on $hostOs. Allowed: $host, android',
    );
    _showHelp(parser);
    exit(1);
  }

  final env = results['env'] as String;
  final rootDir = Directory.current.path;
  final arch = _detectArch();
  final customTargets = results['targets'] as String?;
  final targets = _getTargets(platform, arch, customTargets);
  final androidArch = results['arch'] as String?;
  final verbose = results['verbose'] as bool;
  final channels = _getChannels(platform, results['channels'] as String?);

  final exitCode = await _package(
    platform,
    env,
    targets,
    rootDir,
    arch,
    channels: channels,
    androidArch: androidArch,
    customTargets: customTargets,
    verbose: verbose,
  );
  exit(exitCode);
}

ArgParser createSetupArgParser() {
  return ArgParser()
    ..addOption(
      'env',
      defaultsTo: 'pre',
      allowed: ['pre', 'stable'],
      help: 'Application environment',
    )
    ..addOption(
      'targets',
      valueHelp: 'exe,zip,dmg,apk,...',
      help: 'Package targets (default: all for platform)',
    )
    ..addOption(
      'arch',
      valueHelp: 'arm,arm64,amd64',
      allowed: ['arm', 'arm64', 'amd64'],
      help: 'Target architecture (Android only)',
    )
    ..addOption(
      'channels',
      valueHelp: _androidChannels.join(','),
      help: 'Comma separated channels to build (Android only)',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Enable verbose Flutter build output',
    );
}

List<String> createFlutterBuildArgs({
  required String platform,
  String target = 'apk',
  required bool verbose,
}) {
  final flutterBuildArgs = <String>[
    if (verbose) 'verbose',
    'dart-define-from-file=env.json',
  ];
  if (platform == 'android' && target == 'apk') {
    flutterBuildArgs.add('split-per-abi');
  }
  return flutterBuildArgs;
}

List<String> createTargetList(String targets) {
  return targets
      .split(',')
      .map((target) => target.trim())
      .where((target) => target.isNotEmpty)
      .toList();
}

List<String> createAndroidBuildTargets({
  required String channel,
  String? customTargets,
}) {
  if (channel == 'googleplay') {
    final requestedTargets = customTargets == null
        ? const <String>[]
        : createTargetList(customTargets);
    if (requestedTargets.isNotEmpty &&
        (requestedTargets.length != 1 || requestedTargets.single != 'aab')) {
      throw FormatException(
        'The googleplay channel only supports the universal aab target.',
      );
    }
    return const ['aab'];
  }
  if (customTargets == null) return const ['apk'];
  return createTargetList(customTargets);
}

String? resolveAndroidBuildArch({
  required String channel,
  required String target,
  String? requestedArch,
}) {
  if (channel == 'googleplay') return null;
  if (target == 'apk') return requestedArch ?? 'arm64';
  return requestedArch;
}

String _getTargets(String platform, String arch, String? customTargets) {
  if (customTargets != null) return customTargets;
  if (platform == 'linux' && arch == 'amd64') return 'deb,appimage,rpm';
  return _allTargets[platform]!;
}

List<String> _getChannels(String platform, String? channels) {
  if (platform != 'android') return const [];
  if (channels == null || channels.trim().isEmpty) return _androidChannels;
  final values = channels
      .split(',')
      .map((channel) => channel.trim())
      .where((channel) => channel.isNotEmpty)
      .toList();
  final unsupported = values
      .where((channel) => !_androidChannels.contains(channel))
      .toList();
  if (unsupported.isNotEmpty) {
    throw FormatException(
      'Unsupported Android channels: ${unsupported.join(', ')}',
    );
  }
  return values;
}

void _showHelp(ArgParser parser) {
  stderr.writeln('Usage: dart setup.dart [platform] [options]');
  stderr.writeln('Platform: current host platform (default) or android');
  stderr.writeln();
  stderr.writeln('Default package targets:');
  _allTargets.forEach((platform, targets) {
    final defaultTargets = platform == 'android'
        ? 'googleplay: universal aab; other channels: arm64 apk'
        : targets;
    stderr.writeln('  $platform: $defaultTargets');
  });
  stderr.writeln('Android channels: ${_androidChannels.join(', ')}');
  stderr.writeln();
  stderr.writeln(parser.usage);
}

Future<int> _package(
  String platform,
  String env,
  String targets,
  String rootDir,
  String arch, {
  required List<String> channels,
  String? androidArch,
  String? customTargets,
  required bool verbose,
}) async {
  final distributorDir = p.join(
    rootDir,
    'plugins',
    'flutter_distributor',
    'packages',
    'flutter_distributor',
  );
  final activateResult = await Process.run('dart', [
    'pub',
    'global',
    'activate',
    '-s',
    'path',
    distributorDir,
  ]);
  if (activateResult.exitCode != 0) {
    stderr.write(activateResult.stderr);
    return activateResult.exitCode;
  }

  final coreSha256 = platform == 'windows' ? await _buildGoCore(rootDir) : null;

  final file = File(p.join(rootDir, 'env.json'));
  final previousEnv = file.existsSync()
      ? jsonDecode(file.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};

  final depExit = await _ensureDependencies(platform, arch);
  if (depExit != 0) return depExit;

  final buildChannels = platform == 'android' ? channels : const <String>[''];
  for (final channel in buildChannels) {
    final appChannel = channel.isEmpty ? 'official' : channel;
    final buildTargets = platform == 'android'
        ? createAndroidBuildTargets(
            channel: appChannel,
            customTargets: customTargets,
          )
        : <String>[targets];
    await file.writeAsString(
      jsonEncode({
        'APP_ENV': env,
        'BACKEND_BASE_URL': env == 'stable'
            ? 'https://api.tooran.link/'
            : 'https://myproxyapi.aigateway.cn/',
        'APP_CHANNEL': appChannel,
        'SHOW_PROFILES_TAB': previousEnv['SHOW_PROFILES_TAB'] == true,
        'SHOW_FULL_TOOLS': previousEnv['SHOW_FULL_TOOLS'] == true,
        'DASHBOARD_MODULE': previousEnv['DASHBOARD_MODULE'] == 'legacy'
            ? 'legacy'
            : 'hawk',
        'SHOW_GOOGLE_ADS': previousEnv['SHOW_GOOGLE_ADS'] == true,
        'ADMOB_BANNER_AD_UNIT_ID': _readStringEnv(
          previousEnv,
          'ADMOB_BANNER_AD_UNIT_ID',
          _defaultBannerAdUnitId,
        ),
        'ADMOB_REWARDED_AD_UNIT_ID': _readStringEnv(
          previousEnv,
          'ADMOB_REWARDED_AD_UNIT_ID',
          _defaultRewardedAdUnitId,
        ),
        'ADMOB_INTERSTITIAL_AD_UNIT_ID': _readStringEnv(
          previousEnv,
          'ADMOB_INTERSTITIAL_AD_UNIT_ID',
          _defaultInterstitialAdUnitId,
        ),
        'CORE_SHA256': ?coreSha256,
      }),
    );

    final description = platform == 'android' ? appChannel : arch;
    for (final target in buildTargets) {
      final buildArch = platform == 'android'
          ? resolveAndroidBuildArch(
              channel: appChannel,
              target: target,
              requestedArch: androidArch,
            )
          : null;
      final flutterBuildArgs = createFlutterBuildArgs(
        platform: platform,
        target: target,
        verbose: verbose,
      );
      if (platform == 'android') {
        await _clearAndroidOutputs(rootDir, target);
      }
      stdout.writeln('Packaging $platform channel=$appChannel targets=$target');
      final process = await Process.start(
        'flutter_distributor',
        [
          'package',
          '--skip-clean',
          '--artifact-name=HawkVPN-{{build_name}}-{{platform}}{{#description}}-{{description}}{{/description}}-{{build_mode}}{{#is_installer}}-setup{{/is_installer}}{{#ext}}.{{ext}}{{/ext}}',
          '--platform',
          platform,
          '--targets',
          target,
          if (buildArch != null)
            '--build-target-platform=${_androidFlutterTarget[buildArch]!}',
          if (flutterBuildArgs.isNotEmpty)
            '--flutter-build-args=${flutterBuildArgs.join(',')}',
          '--description',
          description,
        ],
        includeParentEnvironment: true,
        environment: {'ANDROID_ARCH': ?buildArch},
        runInShell: Platform.isWindows,
      );

      process.stdout.listen((data) {
        stdout.write(utf8.decode(data));
      });
      process.stderr.listen((data) {
        stderr.write(utf8.decode(data));
      });
      final exitCode = await process.exitCode;
      if (exitCode != 0) return exitCode;
    }
  }
  return 0;
}

Future<void> _clearAndroidOutputs(String rootDir, String target) async {
  final outputDir = switch (target) {
    'apk' => Directory(
      p.join(rootDir, 'build', 'app', 'outputs', 'flutter-apk'),
    ),
    'aab' => Directory(
      p.join(rootDir, 'build', 'app', 'outputs', 'bundle', 'release'),
    ),
    _ => null,
  };
  if (outputDir == null) return;
  if (!outputDir.existsSync()) return;
  await for (final entity in outputDir.list()) {
    if (entity is File && entity.path.endsWith('.$target')) {
      await entity.delete();
    }
  }
}

String _readStringEnv(Map<String, dynamic> env, String key, String fallback) {
  final value = env[key];
  if (value is String) return value;
  return fallback;
}

Future<String?> _buildGoCore(String rootDir) async {
  final buildToolDir = p.join(
    rootDir,
    'plugins',
    'setup',
    'buildkit',
    'build_tool',
  );
  final result = await Process.run('dart', [
    'run',
    'build_tool',
    'windows',
    '--root-dir',
    rootDir,
  ], workingDirectory: buildToolDir);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    return null;
  }
  final shaFile = File(p.join(rootDir, 'core_sha256.json'));
  if (!shaFile.existsSync()) return null;
  final content =
      jsonDecode(shaFile.readAsStringSync()) as Map<String, dynamic>;
  return content['CORE_SHA256'] as String?;
}

String _detectArch() {
  if (Platform.isWindows) {
    final pa = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'AMD64';
    return pa.toUpperCase() == 'ARM64' ? 'arm64' : 'amd64';
  }
  final result = Process.runSync('uname', ['-m']);
  final machine = (result.stdout as String).trim();
  if (machine == 'aarch64') return 'arm64';
  if (machine == 'x86_64') return 'amd64';
  return machine;
}

Future<bool> _hasCommand(String cmd) async {
  final which = Platform.isWindows ? 'where' : 'command';
  final args = Platform.isWindows ? [cmd] : ['-v', cmd];
  final result = await Process.run(which, args);
  return result.exitCode == 0;
}

Future<int> _ensureDependencies(String platform, String arch) async {
  switch (platform) {
    case 'macos':
      return _ensureMacosDependencies();
    case 'linux':
      return _ensureLinuxDependencies(arch);
    default:
      return 0;
  }
}

Future<int> _ensureMacosDependencies() async {
  if (await _hasCommand('appdmg')) {
    stdout.writeln('appdmg already installed, skipping.');
    return 0;
  }
  stdout.writeln('Installing appdmg (DMG creator)...');
  final result = await Process.run('npm', ['install', '-g', 'appdmg']);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
  }
  return result.exitCode;
}

Future<int> _ensureLinuxDependencies(String arch) async {
  final pkgGroups = <List<String>>[
    ['ninja-build', 'libgtk-3-dev'],
    ['libayatana-appindicator3-dev'],
    ['libkeybinder-3.0-dev'],
    ['locate'],
  ];
  if (arch == 'amd64') {
    pkgGroups.addAll([
      ['rpm', 'patchelf'],
      ['libfuse2'],
    ]);
  }

  final missingGroups = <List<String>>[];
  for (final group in pkgGroups) {
    final missingPkgs = <String>[];
    for (final pkg in group) {
      if (!await _isDebianPackageInstalled(pkg)) {
        missingPkgs.add(pkg);
      }
    }
    if (missingPkgs.isNotEmpty) {
      missingGroups.add(missingPkgs);
    }
  }

  if (missingGroups.isEmpty) {
    stdout.writeln('All Linux build dependencies already installed, skipping.');
  } else {
    stdout.writeln('Updating apt package lists...');
    final updateExit = await _runLinuxDependencyCommand([
      'apt-get',
      'update',
      '-y',
    ]);
    if (updateExit != 0) {
      stderr.writeln(
        'apt-get update exited with $updateExit; continuing and verifying '
        'dependency installation directly.',
      );
    }

    for (final missingPkgs in missingGroups) {
      stdout.writeln(
        'Installing Linux build dependencies: ${missingPkgs.join(', ')}...',
      );
      final installExit = await _installLinuxPackages(missingPkgs);
      if (installExit != 0) return installExit;
    }
  }

  if (arch == 'amd64') {
    const appimagetool = '/usr/local/bin/appimagetool';
    if (File(appimagetool).existsSync()) {
      stdout.writeln('appimagetool already installed, skipping.');
      return 0;
    }
    stdout.writeln('Downloading appimagetool...');
    final downloadName = arch == 'amd64' ? 'x86_64' : 'aarch64';
    final dlResult = await Process.run('wget', [
      '-O',
      appimagetool,
      'https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$downloadName.AppImage',
    ]);
    if (dlResult.exitCode != 0) {
      stderr.write(dlResult.stderr);
      return dlResult.exitCode;
    }
    await Process.run('chmod', ['+x', appimagetool]);
  }

  return 0;
}

Future<bool> _isDebianPackageInstalled(String pkg) async {
  final result = await Process.run('dpkg', ['-s', pkg]);
  return result.exitCode == 0 &&
      (result.stdout as String).contains('Status: install ok installed');
}

Future<bool> _areDebianPackagesInstalled(List<String> pkgs) async {
  for (final pkg in pkgs) {
    if (!await _isDebianPackageInstalled(pkg)) {
      return false;
    }
  }
  return true;
}

Future<int> _installLinuxPackages(List<String> pkgs) async {
  final exitCode = await _runLinuxDependencyCommand([
    'apt-get',
    'install',
    '-y',
    ...pkgs,
  ]);
  if (exitCode == 0) return 0;

  if (await _areDebianPackagesInstalled(pkgs)) {
    stderr.writeln(
      'apt-get install exited with $exitCode, but all requested packages are '
      'installed; continuing.',
    );
    return 0;
  }

  return exitCode;
}

Future<int> _runLinuxDependencyCommand(List<String> command) async {
  final sudoCommand = [
    'env',
    'DEBIAN_FRONTEND=noninteractive',
    'NEEDRESTART_MODE=a',
    ...command,
  ];
  stdout.writeln('exec: sudo ${sudoCommand.join(' ')}');
  final result = await Process.start('sudo', sudoCommand);
  result.stdout.listen((data) {
    stdout.write(utf8.decode(data));
  });
  result.stderr.listen((data) {
    stderr.write(utf8.decode(data));
  });
  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    stderr.writeln('Linux dependency command failed with exit code $exitCode.');
  }
  return exitCode;
}
