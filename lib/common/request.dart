import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class Request {
  late final Dio dio;
  late final Dio _clashDio;
  late final Dio _backendDio;
  String? userAgent;

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _backendDio = Dio(
      BaseOptions(
        headers: {
          'User-Agent': browserUa,
          Headers.contentTypeHeader: Headers.jsonContentType,
        },
        connectTimeout: httpConnectTimeoutDuration,
        receiveTimeout: httpReadTimeoutDuration,
        sendTimeout: httpSendTimeoutDuration,
      ),
    );
    _backendDio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          final statusCode = error.response?.statusCode;
          if (statusCode == HttpStatus.unauthorized) {
            handler.next(error);
            return;
          }
          final message = _getBackendErrorMessage(error);
          if (message != null) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: error.type,
                error: BackendRequestException(message),
              ),
            );
            return;
          }
          handler.next(error);
        },
      ),
    );
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          return FlClashHttpOverrides.handleFindProxy(uri);
        };
        return client;
      },
    );
  }

  void _updateBackendBaseUrl() {
    const backendBaseUrl = String.fromEnvironment('BACKEND_BASE_URL');
    _backendDio.options.baseUrl = backendBaseUrl.takeFirstValid([
      globalState.isPre ? backendDevBaseUrl : backendProdBaseUrl,
    ]);
  }

  String? _getBackendErrorMessage(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == null || statusCode < 400) return null;
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message']?.toString() ?? '';
      if (message.trim().isNotEmpty) return message.trim();
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        final json = jsonDecode(data);
        if (json is Map) {
          final message = json['message']?.toString() ?? '';
          if (message.trim().isNotEmpty) return message.trim();
        }
      } catch (_) {}
    }
    return null;
  }

  Object unwrapBackendError(Object error) {
    if (error is DioException && error.error is BackendRequestException) {
      return error.error!;
    }
    return error;
  }

  Future<(BackendAuth, BackendUser)> login(String appSetId) async {
    _updateBackendBaseUrl();
    final response = await _backendDio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'appSetId': appSetId},
      options: Options(responseType: ResponseType.json),
    );
    final result = BackendResponse.fromJson(response.data ?? {});
    result.throwIfFailed();
    final data = result.data;
    final auth = BackendAuth.fromJson(data);
    final userData = data['user'];
    final user = BackendUser.fromJson(
      userData is Map ? Map<String, dynamic>.from(userData) : {},
    );
    if (!auth.isValid) {
      throw 'backend login failed';
    }
    _setBackendAuth(auth);
    await preferences.saveBackendAuth(auth);
    return (auth, user);
  }

  Future<BackendUser> currentUser({BackendAuth? auth}) async {
    _updateBackendBaseUrl();
    if (auth != null) {
      _setBackendAuth(auth);
    }
    final response = await _backendDio.get<Map<String, dynamic>>(
      '/api/auth/me',
      options: Options(responseType: ResponseType.json),
    );
    final result = BackendResponse.fromJson(response.data ?? {});
    result.throwIfFailed();
    return BackendUser.fromJson(result.data);
  }

  Future<BackendAppConfig> getBackendAppConfig() async {
    _updateBackendBaseUrl();
    final response = await _backendDio.get<Map<String, dynamic>>(
      '/api/app/config',
      options: Options(responseType: ResponseType.json),
    );
    final result = BackendResponse.fromJson(response.data ?? {});
    result.throwIfFailed();
    return BackendAppConfig.fromJson(result.data);
  }

  Future<BackendTrafficReward> checkIn({BackendAuth? auth}) async {
    await _prepareBackendRequest(auth: auth);
    final response = await _backendDio.post<Map<String, dynamic>>(
      '/api/traffic/check-in',
      options: Options(responseType: ResponseType.json),
    );
    final result = BackendResponse.fromJson(response.data ?? {});
    result.throwIfFailed();
    return BackendTrafficReward.fromJson(result.data);
  }

  Future<BackendTrafficReward> submitInviteCode({
    required String inviteCode,
    BackendAuth? auth,
  }) async {
    await _prepareBackendRequest(auth: auth);
    final response = await _backendDio.post<Map<String, dynamic>>(
      '/api/traffic/invite-code',
      data: {'inviteCode': inviteCode},
      options: Options(responseType: ResponseType.json),
    );
    final result = BackendResponse.fromJson(response.data ?? {});
    result.throwIfFailed();
    return BackendTrafficReward.fromJson(result.data);
  }

  Future<BackendAdRewardSession> createAdRewardSession({
    BackendAuth? auth,
  }) async {
    await _prepareBackendRequest(auth: auth);
    final response = await _backendDio.post<Map<String, dynamic>>(
      '/api/traffic/ad-reward/session',
      options: Options(responseType: ResponseType.json),
    );
    final result = BackendResponse.fromJson(response.data ?? {});
    result.throwIfFailed();
    final session = BackendAdRewardSession.fromJson(result.data);
    if (session.sessionId.isEmpty || session.customData.isEmpty) {
      throw 'ad reward session is empty';
    }
    return session;
  }

  Future<BackendSubscription> getBackendSubscription({
    BackendAuth? auth,
  }) async {
    _updateBackendBaseUrl();
    if (auth != null) {
      _setBackendAuth(auth);
    }
    final response = await _backendDio.get<String>(
      '/api/subscription/clash',
      options: Options(responseType: ResponseType.plain),
    );
    return BackendSubscription(
      content: response.data ?? '',
      subscriptionInfo: SubscriptionInfo.formHString(
        response.headers.value('subscription-userinfo'),
      ),
    );
  }

  Future<BackendUploadedFile> uploadFeedbackImage(File file) async {
    await _prepareBackendRequest();
    final response = await _backendDio.post<Map<String, dynamic>>(
      '/api/files/upload',
      data: FormData.fromMap({'file': await MultipartFile.fromFile(file.path)}),
      options: Options(
        contentType: 'multipart/form-data',
        responseType: ResponseType.json,
      ),
    );
    final result = BackendResponse.fromJson(response.data ?? {});
    result.throwIfFailed();
    final uploadedFile = BackendUploadedFile.fromJson(result.data);
    if (uploadedFile.url.isEmpty) {
      throw 'upload file failed';
    }
    return uploadedFile;
  }

  Future<int> submitFeedback({
    required String type,
    required String description,
    required String contact,
    required List<String> imageUrls,
  }) async {
    await _prepareBackendRequest();
    final response = await _backendDio.post<Map<String, dynamic>>(
      '/api/feedback/submit',
      data: {
        'type': type,
        'description': description,
        'imageUrls': imageUrls,
        'contact': contact,
      },
      options: Options(responseType: ResponseType.json),
    );
    final result = BackendResponse.fromJson(response.data ?? {});
    result.throwIfFailed();
    return (result.data['id'] as num?)?.toInt() ?? 0;
  }

  bool isUnauthorized(Object error) {
    return error is DioException &&
        error.response?.statusCode == HttpStatus.unauthorized;
  }

  void _setBackendAuth(BackendAuth auth) {
    if (!auth.isValid) return;
    final tokenValue = auth.tokenValue.startsWith('Bearer ')
        ? auth.tokenValue
        : 'Bearer ${auth.tokenValue}';
    _backendDio.options.headers[auth.tokenName] = tokenValue;
  }

  Future<void> _prepareBackendRequest({BackendAuth? auth}) async {
    _updateBackendBaseUrl();
    final nextAuth =
        auth ?? globalState.backendAuth ?? await preferences.getBackendAuth();
    if (nextAuth != null) {
      _setBackendAuth(nextAuth);
    }
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _clashDio.get<Uint8List>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (e) {
      commonPrint.log('getFileResponseForUrl error ${e.toString()}');
      if (e is DioException) {
        if (e.type == DioExceptionType.unknown) {
          throw currentAppLocalizations.unknownNetworkError;
        } else if (e.type == DioExceptionType.badResponse) {
          throw currentAppLocalizations.networkException;
        }
        rethrow;
      }
      throw currentAppLocalizations.unknownNetworkError;
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    final response = await _clashDio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return response;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      _updateBackendBaseUrl();
      final response = await _backendDio.get(
        '/api/app/update',
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode != 200) return null;
      final data = response.data as Map<String, dynamic>;
      final remoteVersion = data['tag_name'];
      final version = globalState.packageInfo.version;
      final hasUpdate =
          utils.compareVersions(remoteVersion.replaceAll('v', ''), version) > 0;
      if (!hasUpdate) return null;
      return data;
    } catch (e) {
      commonPrint.log('checkForUpdate failed', logLevel: LogLevel.warning);
      return null;
    }
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    'https://api.myip.com': IpInfo.fromMyIpJson,
    'https://ipapi.co/json': IpInfo.fromIpApiCoJson,
    'https://ident.me/json': IpInfo.fromIdentMeJson,
    'http://ip-api.com/json': IpInfo.fromIpAPIJson,
    'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
    'https://ipinfo.io/json': IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    var failureCount = 0;
    final token = cancelToken ?? CancelToken();
    final futures = _ipInfoSources.entries.map((source) async {
      final Completer<Result<IpInfo?>> completer = Completer();
      void handleFailRes() {
        if (!completer.isCompleted && failureCount == _ipInfoSources.length) {
          completer.complete(Result.success(null));
        }
      }

      final future = dio
          .get<Map<String, dynamic>>(
            source.key,
            cancelToken: token,
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 10));
      future
          .then((res) {
            if (res.statusCode == HttpStatus.ok && res.data != null) {
              completer.complete(Result.success(source.value(res.data!)));
              return;
            }
            commonPrint.log('checkIp data empty', logLevel: LogLevel.info);
            failureCount++;
            handleFailRes();
          })
          .catchError((e) {
            failureCount++;
            if (e is DioException && e.type == DioExceptionType.cancel) {
              completer.complete(Result.error('cancelled'));
              return;
            }
            commonPrint.log('checkIp error $e', logLevel: LogLevel.warning);
            handleFailRes();
          });
      return completer.future;
    });
    final res = await Future.any(futures);
    token.cancel();
    return res;
  }

  Future<bool> pingHelper() async {
    if (kDebugMode) return true;
    try {
      final response = await dio
          .get(
            'http://$localhost:$helperPort/ping',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      return (response.data as String) == globalState.coreSHA256;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startCoreByHelper(String arg) async {
    try {
      final response = await dio
          .post(
            'http://$localhost:$helperPort/start',
            data: json.encode({'path': appPath.corePath, 'arg': arg}),
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopCoreByHelper() async {
    try {
      final response = await dio
          .post(
            'http://$localhost:$helperPort/stop',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }
}

final request = Request();
