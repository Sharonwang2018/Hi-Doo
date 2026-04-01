import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/screens/my_read_logs_screen.dart';
import 'package:echo_reading/screens/login_screen.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/screens/photo_read_page_screen.dart';
import 'package:echo_reading/screens/scan_book_screen.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 视觉金字塔：品牌区 > 功能卡片
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!EnvConfig.isConfigured) return;
    try {
      final userInfo = await ApiAuthService.getUserInfo();
      if (mounted) {
        setState(() => _isLoggedIn = userInfo != null && userInfo.uuid.isNotEmpty);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoggedIn = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 20;
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Scaffold(
      appBar: AppBar(
        leadingWidth: 80,
        leading: const SizedBox(),
        centerTitle: true,
        title: Text(
          'Hi-Doo 绘读',
          style: GoogleFonts.quicksand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1a1a1a),
          ),
        ),
        actions: [
          if (EnvConfig.isConfigured)
            if (_isLoggedIn)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.person_rounded),
                  onSelected: (value) async {
                    if (value == 'read_logs') {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const MyReadLogsScreen(),
                        ),
                      );
                    } else if (value == 'logout') {
                      await ApiAuthService.signOut();
                      _checkAuth();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'read_logs',
                      child: Row(
                        children: [
                          Icon(Icons.history_rounded),
                          SizedBox(width: 8),
                          Text('我的阅读记录'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded),
                          SizedBox(width: 8),
                          Text('退出登录'),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                    if (ok == true) _checkAuth();
                  },
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text('登录'),
                ),
              ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '会读，更会说 | Read it, Speak it.',
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
            children: [
              const SizedBox(height: 60),
              Expanded(
                child: ResponsiveLayout.constrainToMaxWidth(
                  context,
                  Padding(
                    padding: ResponsiveLayout.padding(context),
                    child: Center(
                      child: ResponsiveLayout.isTablet(context)
                          ? _TabletLayout(
                              scanTap: () => _push(context, const ScanBookScreen()),
                              photoTap: () => _push(context, const PhotoReadPageScreen()),
                            )
                          : _PhoneLayout(
                              scanTap: () => _push(context, const ScanBookScreen()),
                              photoTap: () => _push(context, const PhotoReadPageScreen()),
                            ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(
                  '『Hi-Doo绘读:AI陪伴,悦读成长』',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({required this.scanTap, required this.photoTap});

  final VoidCallback scanTap;
  final VoidCallback photoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 3),
        _MenuCard(
          icon: Icons.qr_code_scanner_rounded,
          title: '扫页码 / 扫码录入',
          subtitle: '扫描 ISBN 录入书籍，支持复述或共读记录',
          onTap: scanTap,
        ),
        const SizedBox(height: 12),
        _MenuCard(
          icon: Icons.camera_alt_rounded,
          title: 'AI 读书（拍照读页）',
          subtitle:
              '随拍随读本页，不存全书。读完一整本后，请用「扫码录入」选书并完成复述，保存阅读记录。',
          onTap: photoTap,
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.scanTap, required this.photoTap});

  final VoidCallback scanTap;
  final VoidCallback photoTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        Expanded(
          flex: 3,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MenuCard(
                  icon: Icons.qr_code_scanner_rounded,
                  title: '扫页码 / 扫码录入',
                  subtitle: '扫描 ISBN 录入书籍，支持复述或共读记录',
                  onTap: scanTap,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MenuCard(
                  icon: Icons.camera_alt_rounded,
                  title: 'AI 读书（拍照读页）',
                  subtitle:
                      '随拍随读本页，不存全书。读完一整本后，请用「扫码录入」选书并完成复述，保存阅读记录。',
                  onTap: photoTap,
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveLayout.isTablet(context);
    final iconSz = ResponsiveLayout.iconSize(context);
    final padding = ResponsiveLayout.cardPadding(context);
    const cardRadius = 32.0;
    const minCardHeight = 160.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: minCardHeight),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(cardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
                  child: isTablet
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconBox(context, icon, iconSz * 1.5, padding),
                    SizedBox(height: padding),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                    ),
                    SizedBox(height: padding * 0.5),
                    Icon(Icons.chevron_right_rounded, size: iconSz),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBox(context, icon, iconSz, padding),
                    SizedBox(height: padding),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.chevron_right_rounded, size: iconSz),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _iconBox(BuildContext context, IconData iconData, double iconSz, double padding) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withAlpha(200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        iconData,
        size: iconSz,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
