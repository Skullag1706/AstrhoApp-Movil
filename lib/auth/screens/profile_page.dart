import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../agenda/models/agenda.dart';
import 'package:astrhoapp/core/utils/colors.dart';

class ProfilePage extends StatefulWidget {
  final Map<dynamic, dynamic> user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  bool isEditing = false;

  // Datos del usuario
  Map<String, dynamic>? usuarioData;
  Cliente? clienteData;
  Empleado? empleadoData;
  
  // Token de autenticación
  String? get _authToken => widget.user['token']?.toString();
  
  // Headers con autenticación
  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Controladores para edición
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _documentoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      isLoading = true;
    });

    print('=== INICIO CARGA DE DATOS DEL PERFIL ===');
    print('Widget user recibido: ${widget.user}');
    print('Keys del widget user: ${widget.user.keys}');
    
    // Obtener el ID del usuario de diferentes posibles nombres de clave y convertir a int
    int? parseUserId(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        return int.tryParse(value);
      }
      return null;
    }
    
    // Función para obtener TODOS los registros de una API con paginación
    Future<List<dynamic>> fetchAllPaginated(String endpoint) async {
      final List<dynamic> allItems = [];
      int page = 1;
      bool hasMore = true;
      
      while (hasMore) {
        // Usar solo el parámetro 'pagina' sin pageSize, ya que la API maneja su propia paginación
        final url = Uri.parse('http://www.astrhoapp.somee.com$endpoint?pagina=$page');
        print('Fetching: $url');
        
        final response = await http.get(url, headers: _headers);
        
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          List<dynamic> items = [];
          int totalPaginas = 1;
          
          if (decoded is List) {
            items = decoded;
            // Si es una lista directa, asumir que es la última página
            hasMore = false;
          } else if (decoded is Map) {
            // Imprimir todas las claves del mapa para depurar
            print('Response keys: ${decoded.keys}');
            
            // Obtener información de paginación
            totalPaginas = decoded['totalPaginas'] ?? decoded['total_paginas'] ?? 1;
            final paginaActual = decoded['paginaActual'] ?? decoded['pagina_actual'] ?? page;
            
            print('Paginación: página $paginaActual de $totalPaginas');
            
            // Buscar la lista en cualquier propiedad que contenga una lista
            bool foundList = false;
            for (var entry in decoded.entries) {
              if (entry.value is List) {
                items = entry.value as List<dynamic>;
                print('Found list in key: ${entry.key}, items: ${items.length}');
                foundList = true;
                break;
              }
            }
            
            // Si no encontramos una lista, tratar de buscar datos de paginación
            if (!foundList) {
              print('No list found in response, treating as single item');
              items = [decoded];
            }
          }
          
          print('Página $page: ${items.length} items');
          
          if (items.isEmpty) {
            print('No more items, stopping');
            hasMore = false;
          } else {
            allItems.addAll(items);
            
            // Verificar si hay más páginas basándose en la información de paginación
            if (page >= totalPaginas) {
              print('Reached last page ($page >= $totalPaginas), stopping');
              hasMore = false;
            } else {
              print('Continuing to next page...');
              page++;
            }
          }
        } else {
          print('Error fetching page $page: ${response.statusCode}');
          hasMore = false;
        }
      }
      
      print('Total items fetched from $endpoint: ${allItems.length}');
      return allItems;
    }
    
    final usuarioId = parseUserId(widget.user['usuarioId']) ?? 
                     parseUserId(widget.user['idUsuario']) ?? 
                     parseUserId(widget.user['id']);
    print('ID del usuario identificado: $usuarioId');

    try {
      print('Token de autenticación: $_authToken');
      
      // Obtener email desde widget.user si está disponible
      final widgetEmail = widget.user['email']?.toString();
      print('Email desde widget.user: $widgetEmail');
      
      // 1. Primero cargar datos de Cliente o Empleado (todos los registros)
      final rol = widget.user['rol']?.toString().toLowerCase();
      print('Rol del usuario: $rol');
      
      int? usuarioIdDesdePerfil;
      
      if (rol == 'cliente') {
        print('Cargando datos de Clientes (todas las páginas)...');
        final clientesJson = await fetchAllPaginated('/api/Clientes');
        print('Total clientes: ${clientesJson.length}');
        
        // Convertir JSON a objetos Cliente
        final clientes = clientesJson.map((json) => Cliente.fromJson(json)).toList();
        
        clienteData = clientes.firstWhere(
          (c) {
            print('Cliente: usuarioId=${c.usuarioId}, documento=${c.documentoCliente}, email=${c.email}');
            // Coincidir por email primero, ya que es más seguro
            final matchByEmail = widgetEmail != null && c.email?.toLowerCase() == widgetEmail.toLowerCase();
            final matchById = usuarioId != null && c.usuarioId == usuarioId;
            return matchByEmail || matchById;
          },
          orElse: () => Cliente(documentoCliente: '', nombre: ''),
        );
        
        print('clienteData: $clienteData');
        
        if (clienteData != null && clienteData!.documentoCliente.isNotEmpty) {
          usuarioIdDesdePerfil = clienteData!.usuarioId;
          print('usuarioId desde Cliente: $usuarioIdDesdePerfil');
          
          _nombreController.text = clienteData!.nombre;
          _telefonoController.text = clienteData!.telefono ?? '';
          _direccionController.text = clienteData!.direccion ?? '';
          _documentoController.text = clienteData!.documentoCliente;
        }
      } else if (rol == 'empleado' ||
          rol == 'administrador' ||
          rol == 'super admin' ||
          rol == 'superadmin' ||
          rol == 'super administrador') {
        print('Cargando datos de Empleados (todas las páginas)...');
        final empleadosJson = await fetchAllPaginated('/api/Empleados');
        print('Total empleados: ${empleadosJson.length}');
        
        // Convertir JSON a objetos Empleado
        final empleados = empleadosJson.map((json) => Empleado.fromJson(json)).toList();
        
        empleadoData = empleados.firstWhere(
          (e) {
            print('Empleado: usuarioId=${e.usuarioId}, documento=${e.documentoEmpleado}, email=${e.email}');
            // Coincidir por email primero
            final matchByEmail = widgetEmail != null && e.email?.toLowerCase() == widgetEmail.toLowerCase();
            final matchById = usuarioId != null && e.usuarioId == usuarioId;
            return matchByEmail || matchById;
          },
          orElse: () => Empleado(documentoEmpleado: '', nombre: ''),
        );
        
        print('empleadoData: $empleadoData');
        
        if (empleadoData != null && empleadoData!.documentoEmpleado.isNotEmpty) {
          usuarioIdDesdePerfil = empleadoData!.usuarioId;
          print('usuarioId desde Empleado: $usuarioIdDesdePerfil');
          
          _nombreController.text = empleadoData!.nombre;
          _telefonoController.text = empleadoData!.telefono ?? '';
          _direccionController.text = empleadoData!.direccion ?? '';
          _documentoController.text = empleadoData!.documentoEmpleado;
        }
      }
      
      // 2. Ahora cargar datos del Usuario usando el usuarioId obtenido (todos los registros)
      if (usuarioIdDesdePerfil != null) {
        print('Cargando datos de Usuarios (todas las páginas) con usuarioId: $usuarioIdDesdePerfil...');
        final usuarios = await fetchAllPaginated('/api/Usuarios');
        print('Total usuarios: ${usuarios.length}');
        
        // Buscar usuario por el usuarioId desde el perfil
        usuarioData = usuarios.firstWhere(
          (u) {
            if (u is Map) {
              final uId1 = parseUserId(u['idUsuario']);
              final uId2 = parseUserId(u['usuarioId']);
              final uId3 = parseUserId(u['id']);
              print('Comparando con usuario: idUsuario=$uId1, usuarioId=$uId2, id=$uId3');
              
              return uId1 == usuarioIdDesdePerfil || 
                     uId2 == usuarioIdDesdePerfil || 
                     uId3 == usuarioIdDesdePerfil;
            }
            return false;
          },
          orElse: () => null,
        );
        
        print('usuarioData encontrado: $usuarioData');
        
        if (usuarioData != null) {
          _emailController.text = usuarioData!['email']?.toString() ?? '';
        }
      }
      
      print('=== DATOS FINALES ===');
      print('Email: ${_emailController.text}');
      print('Documento: ${_documentoController.text}');
      print('Nombre: ${_nombreController.text}');
      print('Teléfono: ${_telefonoController.text}');
      print('Dirección: ${_direccionController.text}');
      
    } catch (e, stackTrace) {
      print('Error al cargar datos del perfil: $e');
      print('Stack trace: $stackTrace');
    } finally {
      print('=== FIN CARGA DE DATOS ===');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nombreController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El nombre es obligatorio'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final rol = widget.user['rol']?.toString().toLowerCase();
      bool success = true;

      // 1. Actualizar datos de Cliente o Empleado
      print('=== DATOS A GUARDAR ===');
      print('Dirección (controller): ${_direccionController.text}');
      
      if (rol == 'cliente' && clienteData != null) {
        final updateClienteData = {
          'documentoCliente': _documentoController.text,
          'nombre': _nombreController.text,
          'telefono': _telefonoController.text,
          'direccion': _direccionController.text,
          'dirección': _direccionController.text,
          'usuarioId': clienteData!.usuarioId,
          'tipoDocumento': clienteData!.tipoDocumento,
          'estado': clienteData!.estado,
        };
        print('Payload Cliente: $updateClienteData');

        final response = await http.put(
          Uri.parse('http://www.astrhoapp.somee.com/api/Clientes/${clienteData!.documentoCliente}'),
          headers: _headers,
          body: jsonEncode(updateClienteData),
        );

        if (response.statusCode != 200 && response.statusCode != 204) {
          success = false;
          throw Exception('Error al actualizar cliente: ${response.body}');
        }
      } else if (empleadoData != null) {
        final updateEmpleadoData = {
          'documentoEmpleado': _documentoController.text,
          'nombre': _nombreController.text,
          'telefono': _telefonoController.text,
          'direccion': _direccionController.text,
          'dirección': _direccionController.text,
          'usuarioId': empleadoData!.usuarioId,
          'tipoDocumento': empleadoData!.tipoDocumento,
          'estado': empleadoData!.estado,
        };
        print('Payload Empleado: $updateEmpleadoData');

        final response = await http.put(
          Uri.parse('http://www.astrhoapp.somee.com/api/Empleados/${empleadoData!.documentoEmpleado}'),
          headers: _headers,
          body: jsonEncode(updateEmpleadoData),
        );

        if (response.statusCode != 200 && response.statusCode != 204) {
          success = false;
          throw Exception('Error al actualizar empleado: ${response.body}');
        }
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadProfileData();
        setState(() {
          isEditing = false;
        });
      }
    } catch (e) {
      print('Error al guardar perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.white, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Mi Perfil',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Icon(isEditing ? Icons.check : Icons.edit),
              color: AppColors.white,
              onPressed: () {
                setState(() {
                  if (isEditing) {
                    _saveProfile();
                  } else {
                    isEditing = true;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.lightPurpleBackground,
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 64,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildProfileField(
                            label: 'Correo Electrónico',
                            controller: _emailController,
                            icon: Icons.email,
                            enabled: false,
                          ),
                          const SizedBox(height: 16),
                          _buildProfileField(
                            label: 'Documento',
                            controller: _documentoController,
                            icon: Icons.credit_card,
                            enabled: false,
                          ),
                          const SizedBox(height: 16),
                          _buildProfileField(
                            label: 'Nombre Completo',
                            controller: _nombreController,
                            icon: Icons.person_outline,
                            enabled: isEditing,
                          ),
                          const SizedBox(height: 16),
                          _buildProfileField(
                            label: 'Teléfono',
                            controller: _telefonoController,
                            icon: Icons.phone,
                            enabled: isEditing,
                          ),
                          const SizedBox(height: 16),
                          _buildProfileField(
                            label: 'Dirección',
                            controller: _direccionController,
                            icon: Icons.location_on,
                            enabled: isEditing,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoCard(
                            'Rol',
                            widget.user['rolNombre'] ?? widget.user['rol'] ?? 'N/A',
                            Icons.security,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.pushNamed(context, '/forgot-password');
                              },
                              icon: const Icon(Icons.lock_outline, color: AppColors.white),
                              label: const Text(
                                'Cambiar Contraseña',
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (isEditing) ...[
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.scaffoldBackground,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isEditing = false;
                                        _loadProfileData();
                                      });
                                    },
                                    child: const Text(
                                      'Cancelar',
                                      style: TextStyle(
                                        color: AppColors.textDark,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _saveProfile,
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: AppColors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Guardar',
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.primaryPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? AppColors.borderLight : AppColors.borderLight,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(16),
            color: enabled ? AppColors.scaffoldBackground : AppColors.scaffoldBackground,
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, color: AppColors.textGray),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: enabled,
                  obscureText: obscureText,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '',
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightPurpleBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
