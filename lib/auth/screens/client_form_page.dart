import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ClientFormPage extends StatefulWidget {
  @override
  _ClientFormPageState createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController documentoCtrl = TextEditingController();
  final TextEditingController tipoDocumentoCtrl = TextEditingController();
  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();
  bool estado = true;

  Map<dynamic, dynamic>? user;
  bool loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    user = ModalRoute.of(context)!.settings.arguments as Map?;
  }

  Future<void> submitClientData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final data = {
      "documentoCliente": documentoCtrl.text,
      "usuarioId": user?["idUsuario"],
      "tipoDocumento": tipoDocumentoCtrl.text,
      "nombre": nombreCtrl.text,
      "telefono": telefonoCtrl.text,
      "estado": estado,
    };

    try {
      final response = await http.post(
        Uri.parse("http://astrhoapp.somee.com/api/Clientes"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      setState(() => loading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Datos de cliente guardados")));
        Navigator.pushReplacementNamed(context, '/home', arguments: user);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al guardar datos")));
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Datos de Cliente"),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: documentoCtrl,
                decoration: InputDecoration(labelText: "Documento Cliente"),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              TextFormField(
                controller: tipoDocumentoCtrl,
                decoration: InputDecoration(labelText: "Tipo Documento"),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              TextFormField(
                controller: nombreCtrl,
                decoration: InputDecoration(labelText: "Nombre"),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              TextFormField(
                controller: telefonoCtrl,
                decoration: InputDecoration(labelText: "Teléfono"),
                validator: (v) => v!.isEmpty ? "Requerido" : null,
              ),
              SwitchListTile(
                title: Text("Estado"),
                value: estado,
                onChanged: (value) {
                  setState(() {
                    estado = value;
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : submitClientData,
                child: loading ? CircularProgressIndicator() : Text("Guardar"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
