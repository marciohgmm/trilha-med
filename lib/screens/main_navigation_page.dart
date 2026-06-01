import 'package:flutter/material.dart';

import 'package:flutter_application_1/services/auth/admin_auth_service.dart';
import 'package:flutter_application_1/services/analytics/app_analytics_service.dart';
import 'package:flutter_application_1/services/push/fcm_service.dart';
import 'package:flutter_application_1/services/push/push_preferences_service.dart';
import 'package:flutter_application_1/core/push/push_notification_types.dart';
import 'package:flutter_application_1/services/global_message_service.dart';
import 'package:flutter_application_1/utils/image_helper.dart';

import 'home_page.dart';
import 'perfil_page.dart';

class MainNavigationPage extends StatefulWidget {
  final String userId;

  const MainNavigationPage({
    super.key,
    required this.userId,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await AppAnalyticsService.instance.logSessionStart(userId: widget.userId);
      if (!mounted) return;
      await FcmService.instance.bindUser(widget.userId);
      final prefs = await PushPreferencesService().getPrefs(widget.userId);
      await FcmService.instance.syncPromotionalTopic(
        prefs[PushPreferenceKeys.promotional] ?? true,
      );
      if (!mounted) return;
      await AdminAuthService().syncCurrentUser();
      if (!mounted) return;
      await precacheAllBundledFlashcardImages(context);
      if (!mounted) return;
      await GlobalMessageService.instance.maybeShowGlobalMessageDialog(
        context,
        widget.userId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      HomePage(userId: widget.userId),
      PerfilPage(userId: widget.userId),
    ];

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: paginas,
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            )
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              height: 72,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
              ],
            ),
    );
  }
}
