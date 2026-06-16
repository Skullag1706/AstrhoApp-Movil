import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../agenda/models/agenda.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';
import 'package:astrhoapp/core/services/api_service.dart';

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
  String? userEmail; // Email del usuario actual
  
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
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  
  // Tipo de documento
  String? _selectedDocumentType;
  final List<String> _documentTypes = ['CC', 'CE', 'TI', 'NIT'];

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
      userEmail = widgetEmail; // Guardar en variable de clase
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
          _selectedDocumentType = (clienteData!.tipoDocumento?.isNotEmpty == true 
              && _documentTypes.contains(clienteData!.tipoDocumento)) 
              ? clienteData!.tipoDocumento 
              : 'CC';
          print('Tipo de documento cargado: $_selectedDocumentType');
        }
      } else if (rol == 'empleado' ||
          rol == 'asistente' ||
          rol == 'administrador' ||
          rol == 'super admin' ||
          rol == 'superadmin' ||
          rol == 'super administrador') {
        print('Cargando datos de Empleado (endpoint específico)...');
        
        // Primero cargar todos los empleados para obtener el documento
        final empleadosJson = await fetchAllPaginated('/api/Empleados');
        print('Total empleados en lista: ${empleadosJson.length}');
        
        // Convertir JSON a objetos Empleado
        final empleados = empleadosJson.map((json) => Empleado.fromJson(json)).toList();
        print('Empleados convertidos: ${empleados.length}');
        
        Empleado? foundEmpleado;
        
        // Primero intentar por email
        if (widgetEmail != null && widgetEmail.isNotEmpty) {
          print('Buscando por email: $widgetEmail');
          try {
            foundEmpleado = empleados.firstWhere(
              (e) => e.email?.toLowerCase() == widgetEmail.toLowerCase(),
            );
            print('✅ Empleado encontrado por email: ${foundEmpleado.documentoEmpleado}');
          } catch (_) {
            print('❌ No encontrado por email');
          }
        }
        
        // Si no encontró por email, intentar por usuarioId
        if (foundEmpleado == null && usuarioId != null) {
          print('Buscando por usuarioId: $usuarioId');
          try {
            foundEmpleado = empleados.firstWhere(
              (e) => e.usuarioId == usuarioId,
            );
            print('✅ Empleado encontrado por usuarioId: ${foundEmpleado.documentoEmpleado}');
          } catch (_) {
            print('❌ No encontrado por usuarioId');
          }
        }
        
        // Si encontró el empleado, usar el endpoint específico
        if (foundEmpleado != null) {
          print('Usando endpoint específico: /api/Empleados/${foundEmpleado.documentoEmpleado}');
          
          final specificUrl = Uri.parse('http://www.astrhoapp.somee.com/api/Empleados/${foundEmpleado.documentoEmpleado}');
          final specificResponse = await http.get(specificUrl, headers: _headers);
          
          print('Response status: ${specificResponse.statusCode}');
          print('Response body: ${specificResponse.body}');
          
          if (specificResponse.statusCode == 200) {
            final specificData = jsonDecode(specificResponse.body);
            
            // El endpoint podría devolver el objeto directamente o dentro de una propiedad
            final empleadoJson = specificData is List ? specificData.first : specificData;
            empleadoData = Empleado.fromJson(empleadoJson);
            
            print('✅ Datos del empleado cargados desde endpoint específico');
          } else {
            // Fallback: usar el empleado encontrado en la lista
            empleadoData = foundEmpleado;
            print('⚠️ Usando datos del empleado de la lista (endpoint específico falló)');
          }
          
          usuarioIdDesdePerfil = empleadoData!.usuarioId;
          print('usuarioId desde Empleado: $usuarioIdDesdePerfil');
          
          _nombreController.text = empleadoData!.nombre;
          _telefonoController.text = empleadoData!.telefono ?? '';
          _direccionController.text = empleadoData!.direccion ?? '';
          _documentoController.text = empleadoData!.documentoEmpleado;
          _selectedDocumentType = (empleadoData!.tipoDocumento?.isNotEmpty == true 
              && _documentTypes.contains(empleadoData!.tipoDocumento)) 
              ? empleadoData!.tipoDocumento 
              : 'CC';
          print('Tipo de documento cargado: $_selectedDocumentType');
          
          print('Valores cargados:');
          print('  - Nombre: ${_nombreController.text}');
          print('  - Teléfono: ${_telefonoController.text}');
          print('  - Dirección: ${_direccionController.text}');
          print('  - Documento: ${_documentoController.text}');
        } else {
          print('⚠️ No se encontró empleado con los criterios disponibles');
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
          _documentoController.text = usuarioData!['documento']?.toString() ?? '';
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
        CustomAlert.showError(context, 'El nombre es obligatorio');
      }
      return;
    }

    // Validar contraseñas si se proporcionaron
    if (_passwordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty) {
      if (_passwordController.text.isEmpty) {
        if (mounted) {
          CustomAlert.showError(context, 'Debes ingresar la nueva contraseña');
        }
        return;
      }
      if (_confirmPasswordController.text.isEmpty) {
        if (mounted) {
          CustomAlert.showError(context, 'Debes confirmar la contraseña');
        }
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        if (mounted) {
          CustomAlert.showError(context, 'Las contraseñas no coinciden');
        }
        return;
      }
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
          'documentoCliente': clienteData!.documentoCliente, // Mantener PK sin cambios
          'nombre': _nombreController.text,
          'telefono': _telefonoController.text,
          'direccion': _direccionController.text,
          'dirección': _direccionController.text,
          'usuarioId': clienteData!.usuarioId,
          'tipoDocumento': _selectedDocumentType ?? 'CC',
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
          'documentoEmpleado': empleadoData!.documentoEmpleado, // Mantener PK sin cambios
          'nombre': _nombreController.text,
          'telefono': _telefonoController.text,
          'direccion': _direccionController.text,
          'dirección': _direccionController.text,
          'usuarioId': empleadoData!.usuarioId,
          'tipoDocumento': _selectedDocumentType ?? 'CC',
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

      // 2. Actualizar documento en Usuario si cambió
      int? usuarioId;
      if (usuarioData != null) {
        usuarioId = int.tryParse(usuarioData!['idUsuario']?.toString() ?? '') ??
                    int.tryParse(usuarioData!['usuarioId']?.toString() ?? '') ??
                    int.tryParse(usuarioData!['id']?.toString() ?? '');
      }

      if (success && usuarioId != null && _documentoController.text.isNotEmpty) {
        print('=== ACTUALIZANDO DOCUMENTO DE USUARIO ===');
        print('usuarioId: $usuarioId');
        print('Nuevo documento: ${_documentoController.text}');
        
        try {
          // Obtener datos necesarios de usuarioData
          print('usuarioData: $usuarioData');
          final email = usuarioData!['email']?.toString() ?? '';
          final rolId = usuarioData!['rolId'] ?? usuarioData!['rol_id'] ?? 2;
          final estado = usuarioData!['estado'] ?? true;
          
          print('Email extraído: $email');
          print('RolId extraído: $rolId');
          print('Estado extraído: $estado');
          
          if (email.isNotEmpty) {
            print('Creando ApiService con token...');
            final apiService = ApiService(token: _authToken);
            print('Token para API: $_authToken');
            print('Llamando a updateUserDocument...');
            
            final documentoActualizado = await apiService.updateUserDocument(
              usuarioId,
              _documentoController.text,
              email,
              rolId is int ? rolId : (int.tryParse(rolId.toString()) ?? 2),
              estado is bool ? estado : true,
            );
            
            print('Resultado de updateUserDocument: $documentoActualizado');
            
            if (documentoActualizado) {
              print('✅ Documento de usuario actualizado correctamente');
            } else {
              print('⚠️ No se pudo actualizar el documento de usuario');
            }
          } else {
            print('⚠️ Email del usuario no disponible, no se actualiza documento');
          }
        } catch (e) {
          print('⚠️ Error al actualizar documento: $e');
          print('StackTrace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ No se actualizó documento - success: $success, usuarioId: $usuarioId, documentoText: ${_documentoController.text}');
      }
      if (success && _passwordController.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty) {
        print('=== CAMBIANDO CONTRASEÑA ===');
        
        // Obtener el usuario ID desde los datos cargados
        int? usuarioId;
        if (usuarioData != null) {
          usuarioId = int.tryParse(usuarioData!['idUsuario']?.toString() ?? '') ??
                      int.tryParse(usuarioData!['usuarioId']?.toString() ?? '') ??
                      int.tryParse(usuarioData!['id']?.toString() ?? '');
        }
        
        if (usuarioId != null) {
          print('Usuario ID para cambio de contraseña: $usuarioId');
          
          final jsonData = {
            'nuevaContrasena': _passwordController.text,
            'confirmarContrasena': _confirmPasswordController.text,
          };
          print('Enviando cambio de contraseña: ${jsonEncode(jsonData)}');
          
          final response = await http.put(
            Uri.parse('http://www.astrhoapp.somee.com/api/Usuarios/$usuarioId/contrasena'),
            headers: _headers,
            body: jsonEncode(jsonData),
          );

          print('Status cambio de contraseña: ${response.statusCode}');
          print('Response cambio de contraseña: ${response.body}');

          if (response.statusCode != 200 && response.statusCode != 204) {
            success = false;
            throw Exception('Error al cambiar contraseña: ${response.body}');
          }
        } else {
          print('⚠️ No se pudo obtener el usuario ID para cambiar contraseña');
        }
      }

      if (success && mounted) {
        CustomAlert.showSuccess(context, 'Perfil actualizado correctamente');
        _passwordController.clear();
        _confirmPasswordController.clear();
        await _loadProfileData();
        setState(() {
          isEditing = false;
        });
      }
    } catch (e) {
      print('Error al guardar perfil: $e');
      if (mounted) {
        CustomAlert.showError(context, 'Error al guardar: $e');
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
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.white),
              onPressed: _showLogoutDialog,
            ),
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

  void _showLogoutDialog() {
    CustomAlert.showConfirmDialog(
      context,
      title: 'Cerrar Sesión',
      message: '¿Estás seguro de que deseas cerrar sesión?',
      confirmText: 'Cerrar Sesión',
      cancelText: 'Cancelar',
      isDangerous: true,
    ).then((confirmed) {
      if (confirmed == true) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        );
      }
    });
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
                            maxLength: 100,
                          ),
                          const SizedBox(height: 16),
                          if (isEditing) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tipo de Documento',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primaryPurple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.borderLight),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButton<String>(
                                    value: _selectedDocumentType?.isNotEmpty == true 
                                        ? (_documentTypes.contains(_selectedDocumentType) 
                                            ? _selectedDocumentType 
                                            : 'CC')
                                        : 'CC',
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    items: _documentTypes.map((type) {
                                      return DropdownMenuItem(
                                        value: type,
                                        child: Text(type),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedDocumentType = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildProfileField(
                            label: 'Documento',
                            controller: _documentoController,
                            icon: Icons.credit_card,
                            enabled: isEditing,
                            maxLength: 15,
                            prefix: isEditing ? null : (_selectedDocumentType ?? 'CC'),
                          ),
                          const SizedBox(height: 16),
                          _buildProfileField(
                            label: 'Nombre Completo',
                            controller: _nombreController,
                            icon: Icons.person_outline,
                            enabled: isEditing,
                            maxLength: 100,
                          ),
                          const SizedBox(height: 16),
                          _buildProfileField(
                            label: 'Teléfono',
                            controller: _telefonoController,
                            icon: Icons.phone,
                            enabled: isEditing,
                            maxLength: 10,
                          ),
                          const SizedBox(height: 16),
                          _buildProfileField(
                            label: 'Dirección',
                            controller: _direccionController,
                            icon: Icons.location_on,
                            enabled: isEditing,
                            maxLength: 100,
                          ),
                          const SizedBox(height: 16),
                          if (isEditing) ...[
                            _buildProfileField(
                              label: 'Nueva Contraseña',
                              controller: _passwordController,
                              icon: Icons.lock_outline,
                              enabled: true,
                              obscureText: !_showPassword,
                              maxLength: 50,
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                child: Text(
                                  _showPassword ? 'Ocultar' : 'Mostrar',
                                  style: const TextStyle(
                                    color: AppColors.primaryPurple,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildProfileField(
                              label: 'Confirmar Contraseña',
                              controller: _confirmPasswordController,
                              icon: Icons.lock_outline,
                              enabled: true,
                              obscureText: !_showConfirmPassword,
                              maxLength: 50,
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showConfirmPassword = !_showConfirmPassword;
                                  });
                                },
                                child: Text(
                                  _showConfirmPassword ? 'Ocultar' : 'Mostrar',
                                  style: const TextStyle(
                                    color: AppColors.primaryPurple,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _buildInfoCard(
                            'Rol',
                            widget.user['rolNombre'] ?? widget.user['rol'] ?? 'N/A',
                            Icons.security,
                          ),
                          const SizedBox(height: 24),
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
    int maxLength = 100,
    String? prefix,
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
              if (prefix != null && prefix.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    prefix,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              if (prefix != null && prefix.isNotEmpty)
                Container(
                  width: 1,
                  height: 20,
                  color: AppColors.borderLight,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: enabled,
                  obscureText: obscureText,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(maxLength),
                  ],
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
