import 'package:flutter/material.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Map<dynamic, dynamic>? user;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    user = ModalRoute.of(context)!.settings.arguments as Map?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0XFF9D26F2), Color(0XFFE9418C)],
              ),
            ),
          ),
          title: Row(
            children: const [
              Icon(Icons.auto_awesome, size: 22),
              SizedBox(width: 8),
              Text("AstrhoApp"),
            ],
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0XFF9D26F2), Color(0XFFE9418C)],
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple.shade50,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFF7926F7),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "¡Bienvenido Administrador!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7926F7),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Panel de administración de AstrhoApp",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),
                Text(
                  "Usuario: ${user?["nombreUsuario"] ?? "N/A"}",
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  "Rol: ${user?["rolNombre"] ?? "Administrador"}",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Drawer (Menú lateral)
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7926F7), Color(0xFFF63D77)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "AstrhoApp\nPanel Admin",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          _drawerItem(
            icon: Icons.admin_panel_settings,
            text: "Panel Admin",
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          _drawerItem(
            icon: Icons.calendar_month,
            text: "Gestión de Citas",
            onTap: () {
              Navigator.pushNamed(context, '/mis-citas', arguments: user);
            },
          ),
          const Spacer(),
          _drawerItem(
            icon: Icons.logout,
            text: "Cerrar sesión",
            color: Colors.red,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool selected = false,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? Colors.purple.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Color(0xFF7926F7)),
        title: Text(
          text,
          style: TextStyle(
            color: color ?? Colors.black87,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
