import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/qbit_api.dart';
import '../main.dart'; // 用于跳转到首页

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  // 尝试读取本地保存的账号密码
  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('qbit_url') ?? 'http://';
      _usernameController.text = prefs.getString('qbit_username') ?? 'admin';
      _passwordController.text = prefs.getString('qbit_password') ?? '';
    });
  }

  Future<void> _handleLogin() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (url.isEmpty || username.isEmpty) {
      _showErrorDialog("提示", "服务器地址和用户名不能为空");
      return;
    }

    setState(() => _isLoading = true);

    // 1. 设置 API 实例
    final api = QBitApi();
    api.setServer(ServerConfig(url: url, username: username, password: password));

    // 2. 发起登录请求
    bool success = await api.login();

    setState(() => _isLoading = false);

    if (success) {
      // 3. 登录成功，保存凭据到本地
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('qbit_url', url);
      await prefs.setString('qbit_username', username);
      await prefs.setString('qbit_password', password);

      // 4. 跳转到首页，并销毁登录页防止返回
      Get.offAll(() => const MainScreen());
    } else {
      _showErrorDialog("连接失败", "请检查网络地址或账号密码是否正确。");
    }
  }

  void _showErrorDialog(String title, String content) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(content),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("确定"),
            onPressed: () => Get.back(),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // iOS 默认灰色底
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 顶部 Logo / 标题区域
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(CupertinoIcons.cloud_download, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                const Text("连接到 Orbix", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 8),
                const Text("输入您的 qBittorrent 服务器节点信息", style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
                const SizedBox(height: 40),

                // 表单区域
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      CupertinoTextField(
                        controller: _urlController,
                        placeholder: "服务器地址 (例: http://192.168.1.2:8080)",
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey6))),
                        prefix: const Padding(padding: EdgeInsets.only(left: 16), child: Icon(CupertinoIcons.link, color: CupertinoColors.systemGrey)),
                      ),
                      CupertinoTextField(
                        controller: _usernameController,
                        placeholder: "用户名",
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey6))),
                        prefix: const Padding(padding: EdgeInsets.only(left: 16), child: Icon(CupertinoIcons.person, color: CupertinoColors.systemGrey)),
                      ),
                      CupertinoTextField(
                        controller: _passwordController,
                        placeholder: "密码",
                        obscureText: true,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(border: Border.none),
                        prefix: const Padding(padding: EdgeInsets.only(left: 16), child: Icon(CupertinoIcons.lock, color: CupertinoColors.systemGrey)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text("连接服务器", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}