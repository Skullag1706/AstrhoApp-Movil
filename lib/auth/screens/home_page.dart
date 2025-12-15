import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:astrhoapp/core/services/auth_service.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<dynamic, dynamic>? user;
  bool loading = false;
  bool hasClientData = false;
  bool modalShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    user = ModalRoute.of(context)!.settings.arguments as Map?;
    _checkClientData();
  }

  Future<void> _checkClientData() async {
    if (user != null && user!["rol"].toString().toLowerCase() == "cliente") {
      bool hasData = await AuthService.hasClientData(user!["usuarioId"]);
      if (mounted) {
        setState(() {
          hasClientData = hasData;
        });
        if (!hasData && !modalShown) {
          _showClientFormDialog();
          modalShown = true;
        }
      }
    }
  }

  void _showClientFormDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ClientFormDialog(user: user);
      },
    );
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
                    Icons.auto_awesome,
                    color: Color(0xFF7926F7),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "¡Bienvenido a AstrhoApp!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7926F7),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Tu aplicación para gestionar tu perfil y citas",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                if (!hasClientData) ...[
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _showClientFormDialog,
                    child: Text('Completar Datos de Cliente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF7926F7),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
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
                      "AstrhoApp\nMenú principal",
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
            icon: Icons.auto_awesome,
            text: "Inicio",
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          _drawerItem(
            icon: Icons.calendar_month,
            text: "Mis citas",
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

class ClientFormDialog extends StatefulWidget {
  final Map<dynamic, dynamic>? user;

  ClientFormDialog({this.user});

  @override
  _ClientFormDialogState createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends State<ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController documentoCtrl = TextEditingController();
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();
  String? tipoDocumento;
  bool loading = false;

  final List<String> tipoDocumentoOptions = ['CC', 'CE', 'TI', 'TE'];

  Future<void> submitClientData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final data = {
      "documentoCliente": documentoCtrl.text,
      "usuarioId": widget.user?["usuarioId"],
      "tipoDocumento": tipoDocumento,
      "nombre": nombreCtrl.text,
      "telefono": telefonoCtrl.text,
      "estado": true,
    };

    try {
      final response = await http.post(
        Uri.parse("http://astrhoapp.somee.com/api/Clientes"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (mounted) {
        setState(() => loading = false);

        if (response.statusCode == 200 || response.statusCode == 201) {
          Navigator.of(context).pop(); // Close the dialog
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Datos de cliente guardados")));
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error al guardar datos")));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Completar Datos de Cliente",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  "Es importante completar estos datos para poder agendar tus citas.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 20),
                Text("Documento Cliente"),
                SizedBox(height: 5),
                inputBox(
                  controller: documentoCtrl,
                  icon: Icons.credit_card,
                  hint: "Ingresa tu documento",
                  validator: (v) => v!.isEmpty ? "Requerido" : null,
                ),
                SizedBox(height: 15),
                Text("Tipo Documento"),
                SizedBox(height: 5),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 10),
                      Icon(Icons.assignment_ind, color: Colors.grey),
                      SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tipoDocumento,
                          hint: Text("Selecciona tipo"),
                          items: tipoDocumentoOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              tipoDocumento = newValue;
                            });
                          },
                          validator: (v) => v == null ? "Requerido" : null,
                          decoration: InputDecoration(border: InputBorder.none),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                Text("Nombre"),
                SizedBox(height: 5),
                inputBox(
                  controller: nombreCtrl,
                  icon: Icons.person,
                  hint: "Ingresa tu nombre",
                  validator: (v) => v!.isEmpty ? "Requerido" : null,
                ),
                SizedBox(height: 15),
                Text("Teléfono"),
                SizedBox(height: 5),
                inputBox(
                  controller: telefonoCtrl,
                  icon: Icons.phone,
                  hint: "Ingresa tu teléfono",
                  validator: (v) => v!.isEmpty ? "Requerido" : null,
                ),
                SizedBox(height: 25),
                GestureDetector(
                  onTap: loading ? null : submitClientData,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7926F7), Color(0xFFF63D77)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: loading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              "Guardar",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget inputBox({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
              ),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }
}
