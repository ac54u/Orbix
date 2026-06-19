import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../services/qbit_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/connecting_dialog.dart';
import 'main_screen.dart';
import 'server_selection_screen.dart';
import 'welcome_screen.dart';

/// 启动决策页：
///  - 本地无服务器 → 欢迎页（首次引导）
///  - 有活跃服务器   → 自动连接，成功直接进主界面
///  - 自动连接失败   → 退回服务器选择页
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decideStart();
  }

  Future<void> _decideStart() async {
    final servers = await QBitApi.loadServers();
    if (!mounted) return;

    // 无服务器：首次使用 → 欢迎引导
    if (servers.isEmpty) {
      Get.offAll(() => const WelcomeScreen());
      return;
    }

    // 尝试自动连接上次活跃服务器
    final active = await QBitApi.loadSavedConfig();
    if (active != null) {
      final api = QBitApi();
      api.setServer(active);
      // 弹出轻量连接遮罩（与选择页手动连接同款）
      if (mounted) showConnectingDialog(context);
      final result = await api.connect();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (result.success) {
        Get.offAll(() => const MainScreen());
        return;
      }
      // 连接失败：静默退回选择页，用户可编辑/切换
    }

    // 兜底：服务器选择页
    if (!mounted) return;
    Get.offAll(() => const ServerSelectionPage());
  }

  @override
  Widget build(BuildContext context) {
    AppColors.watch(context);
    final accent = AppColors.accent.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.of(AppColors.plainBg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 品牌 logo：渐变 + 柔光，跨欢迎/启动/登录三页一致。
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF366EF6), Color(0xFF0E52BA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.cloud_download_fill,
                color: CupertinoColors.white,
                size: 42,
              ),
            ),
            const SizedBox(height: 28),
            Text('Orbix', style: AppTypography.cardTitle()),
            const SizedBox(height: 32),
            const CupertinoActivityIndicator(radius: 12),
          ],
        ),
      ),
    );
  }
}
