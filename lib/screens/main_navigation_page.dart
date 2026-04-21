import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    final paginas = [
      HomePage(userId: widget.userId),
      PerfilPage(userId: widget.userId),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: paginas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF1E3A8A).withOpacity(0.12),
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