import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

class ServerConfig {
  String url;
  String username;
  String password;

  ServerConfig({required this.url, required this.username, required this.password});
}

class QBitApi {
  late Dio _dio;
  late CookieJar _cookieJar;
  ServerConfig? currentServer;

  // 单例模式，确保全局只有一个 API 实例
  static final QBitApi _instance = QBitApi._internal();
  factory QBitApi() => _instance;

  QBitApi._internal() {
    _cookieJar = CookieJar();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ));
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  void setServer(ServerConfig config) {
    currentServer = config;
    _dio.options.baseUrl = config.url;
  }

  // 1. 登录并获取 Cookie
  Future<bool> login() async {
    if (currentServer == null) return false;
    try {
      final response = await _dio.post(
        '/api/v2/auth/login',
        data: {
          'username': currentServer!.username,
          'password': currentServer!.password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return response.data.toString().contains('Ok');
    } catch (e) {
      print("登录失败: $e");
      return false;
    }
  }

  // 2. 获取主数据 (增量同步)
  Future<Map<String, dynamic>?> syncMainData(int rid) async {
    try {
      final response = await _dio.get('/api/v2/sync/maindata', queryParameters: {'rid': rid});
      return response.data;
    } catch (e) {
      print("同步数据失败: $e");
      return null;
    }
  }
}