import 'dart:convert';
import 'dart:math' show min;
import 'package:http/http.dart' as http;
import '/agenda/models/agenda.dart';

class ApiService {
  static const String baseUrl = 'http://www.astrhoapp.somee.com/api';
  static const Duration timeoutDuration = Duration(seconds: 30);

  final String? token;

  ApiService({this.token});

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Método auxiliar para parsear JSON de manera segura
  dynamic _parseJson(String body) {
    try {
      // Verificar si la respuesta es HTML (página de error)
      if (body.trim().startsWith('<!DOCTYPE') ||
          body.trim().startsWith('<html')) {
        throw Exception(
          'La respuesta es HTML, no JSON. Posible error del servidor.',
        );
      }
      return json.decode(body);
    } catch (e) {
      // Si no es JSON válido, intentar verificar si es un string simple
      if (body.trim().startsWith('[') || body.trim().startsWith('{')) {
        throw Exception(
          'Error al parsear JSON: $e. Respuesta: ${body.substring(0, body.length > 100 ? 100 : body.length)}',
        );
      }
      throw Exception(
        'La respuesta no es JSON válido: ${body.substring(0, body.length > 100 ? 100 : body.length)}',
      );
    }
  }

  // Obtener todas las citas con paginación
  Future<List<Agenda>> getAgendas() async {
    try {
      final List<Agenda> todasLasCitas = [];
      int paginaActual = 1;
      bool hayMasPaginas = true;

      while (hayMasPaginas) {
        print('Llamando a API: $baseUrl/Agenda?pagina=$paginaActual');
        
        final response = await http
            .get(Uri.parse('$baseUrl/Agenda?pagina=$paginaActual'), headers: _headers)
            .timeout(timeoutDuration);

        print('Status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final agendasEnPagina = _parseAgendaList(response.body);
          todasLasCitas.addAll(agendasEnPagina);

          final data = _parseJson(response.body);
          if (data is Map<String, dynamic>) {
            final totalPaginas = data['totalPaginas'] ?? data['total_paginas'] ?? 1;
            hayMasPaginas = paginaActual < totalPaginas;
            print('Página $paginaActual de $totalPaginas - Citas: ${agendasEnPagina.length}');
          } else {
            hayMasPaginas = false;
          }
        } else {
          print('Error en getAgendas: ${response.statusCode} - ${response.body}');
          hayMasPaginas = false;
        }

        paginaActual++;
      }

      print('Total de citas obtenidas: ${todasLasCitas.length}');
      return todasLasCitas;
    } catch (e) {
      print('Excepción al obtener todas las citas: $e');
      return [];
    }
  }

  // Obtener citas del cliente logueado con paginación
  Future<List<Agenda>> getMisCitas() async {
    try {
      final List<Agenda> todasLasCitas = [];
      int paginaActual = 1;
      bool hayMasPaginas = true;

      while (hayMasPaginas) {
        print('Llamando a API: $baseUrl/Agenda/mis-citas?pagina=$paginaActual');
        
        final response = await http
            .get(Uri.parse('$baseUrl/Agenda/mis-citas?pagina=$paginaActual'), headers: _headers)
            .timeout(timeoutDuration);

        print('Status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          final agendasEnPagina = _parseAgendaList(response.body);
          todasLasCitas.addAll(agendasEnPagina);

          final data = _parseJson(response.body);
          if (data is Map<String, dynamic>) {
            final totalPaginas = data['totalPaginas'] ?? data['total_paginas'] ?? 1;
            hayMasPaginas = paginaActual < totalPaginas;
            print('Página $paginaActual de $totalPaginas - Citas: ${agendasEnPagina.length}');
          } else {
            hayMasPaginas = false;
          }
        } else {
          print('Error en mis-citas: ${response.statusCode} - ${response.body}');
          hayMasPaginas = false;
        }

        paginaActual++;
      }

      print('Total de mis citas obtenidas: ${todasLasCitas.length}');
      return todasLasCitas;
    } catch (e) {
      print('Excepción en mis-citas: $e');
      return [];
    }
  }

  List<Agenda> _parseAgendaList(String body) {
    if (body.trim().isEmpty) return [];
    try {
      final dynamic data = _parseJson(body);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data.containsKey('data') && data['data'] is List) {
          list = data['data'];
        } else if (data.containsKey('items') && data['items'] is List) {
          list = data['items'];
        } else {
          for (var value in data.values) {
            if (value is List) {
              list = value;
              break;
            }
          }
        }
      }
      return list
          .map((item) {
            if (item is Map<String, dynamic>) {
              try {
                return Agenda.fromJson(item);
              } catch (e) {
                print('Error al parsear una cita: $e');
                return null;
              }
            }
            return null;
          })
          .where((agenda) => agenda != null)
          .cast<Agenda>()
          .toList();
    } catch (e) {
      print('Error parseando lista de agendas: $e');
      return [];
    }
  }

  // Buscar cliente por usuario ID (para autocompletar formularios)
  Future<Cliente?> getClientePorUsuarioId(int userId) async {
    try {
      final clientes = await getClientes();
      if (clientes.isNotEmpty) {
        return clientes.firstWhere(
          (c) => c.usuarioId == userId,
          orElse: () => throw Exception('Cliente no encontrado'),
        );
      }
      return null;
    } catch (e) {
      print("Error buscando cliente por ID: $e");
      return null;
    }
  }

  // Obtener una cita por ID
  Future<Agenda> getAgendaById(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Agenda/$id'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final dynamic data = _parseJson(response.body);
        if (data is Map<String, dynamic>) {
          return Agenda.fromJson(data);
        } else {
          throw Exception('Formato de respuesta inesperado');
        }
      } else {
        throw Exception('Error al cargar la cita: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Crear una nueva cita
  Future<Agenda> createAgenda(Agenda agenda) async {
    try {
      final jsonData = agenda.toJson();
      print('Enviando datos para crear cita: ${json.encode(jsonData)}');

      final response = await http
          .post(
            Uri.parse('$baseUrl/Agenda'),
            headers: _headers,
            body: json.encode(jsonData),
          )
          .timeout(timeoutDuration);

      print(
        'Respuesta del servidor: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic data = _parseJson(response.body);

        // Verificar formato { success: true, citaId: ... }
        if (data is Map<String, dynamic>) {
          if (data.containsKey('success') && data['success'] == true) {
            // Si trae el ID, devolvemos la agenda con ese ID
            if (data.containsKey('citaId')) {
              return Agenda(
                agendaId: data['citaId'],
                documentoCliente: agenda.documentoCliente,
                documentoEmpleado: agenda.documentoEmpleado,
                ventaId: agenda.ventaId,
                fechaCita: agenda.fechaCita,
                horaInicio: agenda.horaInicio,
                estadoId: agenda.estadoId,
                metodopagoId: agenda.metodopagoId,
                observaciones: agenda.observaciones,
                nombreCliente: agenda.nombreCliente,
                nombreEmpleado: agenda.nombreEmpleado,
                nombreEstado: agenda.nombreEstado,
                nombreMetodoPago: agenda.nombreMetodoPago,
                servicios: agenda.servicios,
              );
            }
            return agenda;
          } else if (data.containsKey('success') && data['success'] == false) {
            throw Exception(
              data['message'] ?? 'Error desconocido al crear la cita',
            );
          }
          // Si devolvió el objeto directamente (fallback)
          if (data.containsKey('agendaId')) {
            return Agenda.fromJson(data);
          }
        }
        return agenda;
      } else if (response.statusCode == 400) {
        // Manejar errores de validación (400 Bad Request)
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic>) {
            // Caso 1: Estructura estándar de ASP.NET Core { "errors": { ... } }
            if (errorData.containsKey('errors')) {
              final errors = errorData['errors'];
              if (errors is Map<String, dynamic>) {
                final messages = <String>[];
                errors.forEach((key, value) {
                  if (value is List) {
                    messages.addAll(value.map((e) => e.toString()));
                  } else {
                    messages.add(value.toString());
                  }
                });
                if (messages.isNotEmpty) {
                  throw Exception(
                    'Errores de validación:\n${messages.join('\n')}',
                  );
                }
              }
            }
            // Caso 2: Mensaje directo { "message": "..." }
            if (errorData.containsKey('message')) {
              throw Exception(errorData['message']);
            }
          }
        } catch (e) {
          // Si es la excepción que acabamos de lanzar (mensaje limpio), re-lanzarla
          // json.decode lanza FormatException, eso lo ignoramos para ir al fallback
          if (e.toString().contains('Exception:')) rethrow;
        }
        throw Exception('Error de validación (400): ${response.body}');
      } else {
        // Intentar parsear el mensaje de error de la API para otros códigos
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('message')) {
            throw Exception(errorData['message'] ?? 'Error al crear la cita');
          }
        } catch (e) {
          // Si no se puede parsear, usar el mensaje original
        }
        throw Exception(
          'Error al crear la cita: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  // Actualizar una cita
  Future<Agenda> updateAgenda(int id, Agenda agenda) async {
    try {
      final jsonData = agenda.toJson();
      print('Enviando datos para actualizar cita: ${json.encode(jsonData)}');

      final response = await http
          .put(
            Uri.parse('$baseUrl/Agenda/$id'),
            headers: _headers,
            body: json.encode(jsonData),
          )
          .timeout(timeoutDuration);

      print(
        'Respuesta del servidor: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Intentar obtener la cita actualizada
        try {
          if (response.body.trim().isNotEmpty) {
            final dynamic data = _parseJson(response.body);
            if (data is Map<String, dynamic>) {
              return Agenda.fromJson(data);
            }
          }
          // Si no hay respuesta, intentar obtener la cita actualizada
          return await getAgendaById(id);
        } catch (e) {
          print('Error al obtener cita actualizada: $e');
          return agenda;
        }
      } else if (response.statusCode == 400) {
        // Manejar errores de validación (400 Bad Request)
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic>) {
            // Caso 1: Estructura estándar de ASP.NET Core { "errors": { ... } }
            if (errorData.containsKey('errors')) {
              final errors = errorData['errors'];
              if (errors is Map<String, dynamic>) {
                final messages = <String>[];
                errors.forEach((key, value) {
                  if (value is List) {
                    messages.addAll(value.map((e) => e.toString()));
                  } else {
                    messages.add(value.toString());
                  }
                });
                if (messages.isNotEmpty) {
                  throw Exception(
                    'Errores de validación:\n${messages.join('\n')}',
                  );
                }
              }
            }
            // Caso 2: Mensaje directo { "message": "..." }
            if (errorData.containsKey('message')) {
              throw Exception(errorData['message']);
            }
          }
        } catch (e) {
          if (e.toString().contains('Exception:')) rethrow;
        }
        throw Exception('Error de validación (400): ${response.body}');
      } else {
        // Intentar parsear el mensaje de error de la API
        try {
          final errorData = json.decode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('message')) {
            throw Exception(
              errorData['message'] ?? 'Error al actualizar la cita',
            );
          }
        } catch (e) {
          // Si no se puede parsear, usar el mensaje original
        }
        throw Exception(
          'Error al actualizar la cita: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Confirmar una cita
  Future<Agenda> confirmarCita(int id) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/Agenda/$id/confirmar'),
            headers: _headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return await getAgendaById(id);
      }
      throw Exception('Error al confirmar la cita: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Completar una cita
  Future<Agenda> completarCita(int id) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/Agenda/$id/completar'),
            headers: _headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return await getAgendaById(id);
      }
      throw Exception('Error al completar la cita: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Cancelar una cita
  Future<Agenda> cancelarCita(int id) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/Agenda/$id/cancelar'),
            headers: _headers,
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return await getAgendaById(id);
      }
      throw Exception('Error al cancelar la cita: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Eliminar una cita
  Future<void> deleteAgenda(int id) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/Agenda/$id'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar la cita: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Obtener estados
  Future<List<Estado>> getEstados() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Estado'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return [];
        }
        final dynamic data = _parseJson(body);
        if (data is List) {
          return data
              .map((json) => Estado.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (data is Map<String, dynamic>) {
          for (var key in data.keys) {
            if (data[key] is List) {
              return (data[key] as List)
                  .map((json) => Estado.fromJson(json as Map<String, dynamic>))
                  .toList();
            }
          }
          return [];
        }
        return [];
      } else if (response.statusCode == 404) {
        // Si el endpoint no existe, devolver valores por defecto
        return [
          Estado(estadoId: 1, nombre: 'Pendiente'),
          Estado(estadoId: 2, nombre: 'Confirmado'),
          Estado(estadoId: 3, nombre: 'Cancelado'),
          Estado(estadoId: 4, nombre: 'Completado'),
        ];
      } else {
        // Para otros errores, devolver valores por defecto
        return [
          Estado(estadoId: 1, nombre: 'Pendiente'),
          Estado(estadoId: 2, nombre: 'Confirmado'),
          Estado(estadoId: 3, nombre: 'Cancelado'),
          Estado(estadoId: 4, nombre: 'Completado'),
        ];
      }
    } catch (e) {
      // En caso de error, devolver valores por defecto
      return [
        Estado(estadoId: 1, nombre: 'Pendiente'),
        Estado(estadoId: 2, nombre: 'Confirmado'),
        Estado(estadoId: 3, nombre: 'Cancelado'),
        Estado(estadoId: 4, nombre: 'Completado'),
      ];
    }
  }

  // Obtener métodos de pago
  Future<List<MetodoPago>> getMetodosPago() async {
    try {
      print('Obteniendo métodos de pago desde: $baseUrl/MetodoPago');
      final response = await http
          .get(Uri.parse('$baseUrl/MetodoPago'), headers: _headers)
          .timeout(timeoutDuration);

      print('Respuesta de métodos de pago: ${response.statusCode}');
      print('Body de métodos de pago: ${response.body}');

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          print('Respuesta de métodos de pago vacía');
          return [];
        }
        try {
          final dynamic data = _parseJson(body);
          if (data is List) {
            final metodos = data
                .map((json) {
                  try {
                    return MetodoPago.fromJson(json as Map<String, dynamic>);
                  } catch (e) {
                    print('Error al parsear método de pago: $e');
                    return null;
                  }
                })
                .where((m) => m != null)
                .cast<MetodoPago>()
                .toList();
            print('Métodos de pago cargados: ${metodos.length}');
            for (var metodo in metodos) {
              print('  - ID: ${metodo.metodopagoId}, Nombre: ${metodo.nombre}');
            }
            return metodos;
          } else if (data is Map<String, dynamic>) {
            for (var key in data.keys) {
              if (data[key] is List) {
                final metodos = (data[key] as List)
                    .map((json) {
                      try {
                        return MetodoPago.fromJson(
                          json as Map<String, dynamic>,
                        );
                      } catch (e) {
                        print('Error al parsear método de pago: $e');
                        return null;
                      }
                    })
                    .where((m) => m != null)
                    .cast<MetodoPago>()
                    .toList();
                print('Métodos de pago cargados: ${metodos.length}');
                return metodos;
              }
            }
            return [];
          }
          return [];
        } catch (parseError) {
          print('Error al parsear métodos de pago: $parseError');
          return [];
        }
      } else if (response.statusCode == 404) {
        print(
          'Endpoint de métodos de pago no encontrado (404), usando valores por defecto',
        );
        // Si el endpoint no existe, devolver lista vacía o valores por defecto
        return [
          MetodoPago(metodopagoId: 1, nombre: 'Efectivo'),
          MetodoPago(metodopagoId: 2, nombre: 'Tarjeta'),
        ];
      } else {
        print('Error al cargar métodos de pago: ${response.statusCode}');
        // En lugar de lanzar excepción, devolver valores por defecto
        return [
          MetodoPago(metodopagoId: 1, nombre: 'Efectivo'),
          MetodoPago(metodopagoId: 2, nombre: 'Tarjeta'),
        ];
      }
    } catch (e) {
      print('Excepción al obtener métodos de pago: $e');
      // Si hay error, devolver valores por defecto en lugar de fallar
      return [
        MetodoPago(metodopagoId: 1, nombre: 'Efectivo'),
        MetodoPago(metodopagoId: 2, nombre: 'Tarjeta'),
      ];
    }
  }

  // Obtener servicios con paginación y búsqueda
  Future<Map<String, dynamic>> getServicios({
    int pagina = 1,
    String? busqueda,
  }) async {
    try {
      // Construir URL con parámetros
      String url = '$baseUrl/Servicios?pagina=$pagina';
      if (busqueda != null && busqueda.isNotEmpty) {
        url += '&buscar=${Uri.encodeComponent(busqueda)}';
      }

      print('Intentando endpoint con paginación: $url');
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(timeoutDuration);

      print('Respuesta servicios status: ${response.statusCode}');
      print('Respuesta servicios body: ${response.body}');

      if (response.statusCode == 200) {
        final result = _parseServiciosPaginados(response.body);
        return result;
      } else if (response.statusCode == 404) {
        // Intentar con ruta singular
        String urlSingular = '$baseUrl/Servicio?pagina=$pagina';
        if (busqueda != null && busqueda.isNotEmpty) {
          urlSingular += '&buscar=${Uri.encodeComponent(busqueda)}';
        }
        
        final responseSingular = await http
            .get(Uri.parse(urlSingular), headers: _headers)
            .timeout(timeoutDuration);
        print('Intentando endpoint singular: $urlSingular');
        print('Respuesta singular status: ${responseSingular.statusCode}');
        if (responseSingular.statusCode == 200) {
          return _parseServiciosPaginados(responseSingular.body);
        }
      }
      
      // Si no hay respuesta exitosa, devolver estructura vacía
      return {
        'servicios': <Servicio>[],
        'totalPaginas': 1,
        'paginaActual': pagina,
        'totalServicios': 0,
      };
    } catch (e) {
      print('Excepción al obtener servicios: $e');
      return {
        'servicios': <Servicio>[],
        'totalPaginas': 1,
        'paginaActual': pagina,
        'totalServicios': 0,
      };
    }
  }

  Map<String, dynamic> _parseServiciosPaginados(String body) {
    if (body.trim().isEmpty) {
      print('Cuerpo de servicios vacío');
      return {
        'servicios': <Servicio>[],
        'totalPaginas': 1,
        'paginaActual': 1,
        'totalServicios': 0,
      };
    }
    
    try {
      final dynamic data = _parseJson(body);
      List<dynamic> serviciosList = [];
      int totalPaginas = 1;
      int paginaActual = 1;
      int totalServicios = 0;

      if (data is List) {
        serviciosList = data;
        totalServicios = serviciosList.length;
      } else if (data is Map<String, dynamic>) {
        // Buscar información de paginación
        totalPaginas = data['totalPaginas'] ?? data['total_paginas'] ?? 1;
        paginaActual = data['paginaActual'] ?? data['pagina_actual'] ?? 1;
        totalServicios = data['totalServicios'] ?? data['total_servicios'] ?? 0;

        // Buscar lista de servicios
        if (data.containsKey('data') && data['data'] is List) {
          serviciosList = data['data'];
        } else if (data.containsKey('servicios') && data['servicios'] is List) {
          serviciosList = data['servicios'];
        } else if (data.containsKey('items') && data['items'] is List) {
          serviciosList = data['items'];
        } else {
          for (var value in data.values) {
            if (value is List) {
              serviciosList = value;
              break;
            }
          }
        }
      }

      print('Lista de servicios para parsear: ${serviciosList.length} elementos');
      final servicios = serviciosList
          .map((json) {
            try {
              print('Parseando servicio: $json');
              final servicio = Servicio.fromJson(json as Map<String, dynamic>);
              print('Servicio parseado: ID=${servicio.servicioId}, Nombre=${servicio.nombre}, Imagen=${servicio.imagen}');
              return servicio;
            } catch (e) {
              print('Error al parsear servicio individual: $e');
              return null;
            }
          })
          .where((s) => s != null)
          .cast<Servicio>()
          .toList();

      print('Servicios parseados exitosamente: ${servicios.length}');
      
      return {
        'servicios': servicios,
        'totalPaginas': totalPaginas,
        'paginaActual': paginaActual,
        'totalServicios': totalServicios,
      };
    } catch (e) {
      print('Error general parseando servicios paginados: $e');
      return {
        'servicios': <Servicio>[],
        'totalPaginas': 1,
        'paginaActual': 1,
        'totalServicios': 0,
      };
    }
  }

  // Método de compatibilidad - obtener todos los servicios sin paginación
  Future<List<Servicio>> getServiciosLegacy() async {
    try {
      final result = await getServicios(pagina: 1);
      return result['servicios'] as List<Servicio>;
    } catch (e) {
      print('Error en getServiciosLegacy: $e');
      return [];
    }
  }

  // Función para obtener TODOS los registros de una API con paginación
  Future<List<dynamic>> fetchAllPaginated(String endpoint) async {
    final List<dynamic> allItems = [];
    int page = 1;
    bool hasMore = true;
    
    // Asumimos un tamaño de página fijo de 5 según el backend
    const int backendPageSize = 5;

    while (hasMore) {
      // Usar parámetro 'pagina' en lugar de 'page' y 'pageSize'
      final url = Uri.parse('$baseUrl$endpoint?pagina=$page');
      print('Fetching: $url');

      final response = await http
          .get(url, headers: _headers)
          .timeout(timeoutDuration);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = _parseJson(response.body);
        List<dynamic> items = [];

        if (decoded is List) {
          items = decoded;
        } else if (decoded is Map) {
          print('Response keys: ${decoded.keys}');
          
          bool foundList = false;
          for (var entry in decoded.entries) {
            if (entry.value is List) {
              items = entry.value as List<dynamic>;
              print('Found list in key: ${entry.key}, items: ${items.length}');
              foundList = true;
              break;
            }
          }
          
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
          page++;
          
          if (items.length < backendPageSize) {
            print('Page has fewer items ($items.length) than pageSize ($backendPageSize), stopping');
            hasMore = false;
          } else {
            print('Continuing to next page...');
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



  // Obtener clientes (todos los registros con paginación)
  Future<List<Cliente>> getClientes() async {
    try {
      final clientesJson = await fetchAllPaginated('/Clientes');
      return clientesJson
          .map((json) {
            try {
              return Cliente.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .where((c) => c != null)
          .cast<Cliente>()
          .toList();
    } catch (e) {
      print('Excepción al obtener clientes: $e');
      return [];
    }
  }

  List<Cliente> _parseClienteList(String body) {
    if (body.trim().isEmpty) {
      print('⚠️ _parseClienteList: body vacío');
      return [];
    }
    try {
      final dynamic data = _parseJson(body);
      print('📦 Datos parseados (tipo): ${data.runtimeType}');
      
      List<dynamic> list = [];
      if (data is List) {
        print('✓ Datos es una lista directa');
        list = data;
      } else if (data is Map<String, dynamic>) {
        print('✓ Datos es un Map, buscando lista...');
        // Buscar lista en propiedades comunes como 'data', 'items', 'values'
        if (data.containsKey('data') && data['data'] is List) {
          print('  → Encontrado en "data"');
          list = data['data'];
        } else if (data.containsKey('items') && data['items'] is List) {
          print('  → Encontrado en "items"');
          list = data['items'];
        } else if (data.containsKey('clientes') && data['clientes'] is List) {
          print('  → Encontrado en "clientes"');
          list = data['clientes'];
        } else {
          print('  → Buscando primera propiedad que sea lista...');
          for (var entry in data.entries) {
            if (entry.value is List) {
              print('  → Encontrado en "${entry.key}"');
              list = entry.value;
              break;
            }
          }
        }
      }
      
      print('📋 Items a procesar: ${list.length}');
      final result = list
          .map((json) {
            try {
              if (json is! Map<String, dynamic>) {
                print('  ⚠️ Ignorando item que no es Map: ${json.runtimeType}');
                return null;
              }
              return Cliente.fromJson(json);
            } catch (e) {
              print('  ⚠️ Error parseando cliente: $e | JSON: $json');
              return null;
            }
          })
          .where((c) => c != null)
          .cast<Cliente>()
          .toList();
      
      print('✅ Clientes parseados exitosamente: ${result.length}');
      return result;
    } catch (e) {
      print('❌ Error en _parseClienteList: $e');
      print('📝 Body: ${body.substring(0, min(300, body.length))}...');
      return [];
    }
  }

  // Obtener empleados (todos los registros con paginación)
  Future<List<Empleado>> getEmpleados() async {
    try {
      final empleadosJson = await fetchAllPaginated('/Empleados');
      return empleadosJson
          .map((json) {
            try {
              return Empleado.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .where((e) => e != null)
          .cast<Empleado>()
          .toList();
    } catch (e) {
      print('Excepción al obtener empleados: $e');
      return [];
    }
  }

  // Buscar empleado por usuario ID
  Future<Empleado?> getEmpleadoPorUsuarioId(int userId) async {
    try {
      final empleados = await getEmpleados();
      if (empleados.isNotEmpty) {
        try {
          return empleados.firstWhere(
            (e) => e.usuarioId == userId,
          );
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (e) {
      print("Error buscando empleado por ID de usuario: $e");
      return null;
    }
  }

  List<Empleado> _parseEmpleadoList(String body) {
    if (body.trim().isEmpty) {
      print('⚠️ _parseEmpleadoList: body vacío');
      return [];
    }
    try {
      final dynamic data = _parseJson(body);
      print('📦 Datos parseados (tipo): ${data.runtimeType}');
      
      List<dynamic> list = [];
      if (data is List) {
        print('✓ Datos es una lista directa');
        list = data;
      } else if (data is Map<String, dynamic>) {
        print('✓ Datos es un Map, buscando lista...');
        if (data.containsKey('data') && data['data'] is List) {
          print('  → Encontrado en "data"');
          list = data['data'];
        } else if (data.containsKey('items') && data['items'] is List) {
          print('  → Encontrado en "items"');
          list = data['items'];
        } else if (data.containsKey('empleados') && data['empleados'] is List) {
          print('  → Encontrado en "empleados"');
          list = data['empleados'];
        } else {
          print('  → Buscando primera propiedad que sea lista...');
          for (var entry in data.entries) {
            if (entry.value is List) {
              print('  → Encontrado en "${entry.key}"');
              list = entry.value;
              break;
            }
          }
        }
      }
      
      print('📋 Items a procesar: ${list.length}');
      final result = list
          .map((json) {
            try {
              if (json is! Map<String, dynamic>) {
                print('  ⚠️ Ignorando item que no es Map: ${json.runtimeType}');
                return null;
              }
              return Empleado.fromJson(json);
            } catch (e) {
              print('  ⚠️ Error parseando empleado: $e | JSON: $json');
              return null;
            }
          })
          .where((e) => e != null)
          .cast<Empleado>()
          .toList();
      
      print('✅ Empleados parseados exitosamente: ${result.length}');
      return result;
    } catch (e) {
      print('❌ Error en _parseEmpleadoList: $e');
      print('📝 Body: ${body.substring(0, min(300, body.length))}...');
      return [];
    }
  }

  // Obtener horarios generales
  Future<List<Horario>> getHorarios() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Horario'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return _parseHorarioList(response.body);
      }
      return [];
    } catch (e) {
      print('Excepción al obtener horarios: $e');
      return [];
    }
  }

  List<Horario> _parseHorarioList(String body) {
    if (body.trim().isEmpty) return [];
    try {
      final dynamic data = _parseJson(body);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data.containsKey('data') && data['data'] is List) {
          list = data['data'];
        } else if (data.containsKey('items') && data['items'] is List) {
          list = data['items'];
        } else {
          for (var value in data.values) {
            if (value is List) {
              list = value;
              break;
            }
          }
        }
      }
      return list
          .map((json) {
            try {
              return Horario.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .where((h) => h != null)
          .cast<Horario>()
          .toList();
    } catch (e) {
      print('Error parseando lista de horarios: $e');
      return [];
    }
  }

  // Obtener horarios de un empleado específico
  Future<List<HorarioEmpleado>> getHorariosEmpleado(String documentoEmpleado) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/HorarioEmpleado/empleado/$documentoEmpleado'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return _parseHorarioEmpleadoList(response.body);
      }
      return [];
    } catch (e) {
      print('Excepción al obtener horarios de empleado: $e');
      return [];
    }
  }

  List<HorarioEmpleado> _parseHorarioEmpleadoList(String body) {
    if (body.trim().isEmpty) {
      print('Cuerpo de horarios de empleado vacío');
      return [];
    }
    
    print('Parseando horarios de empleado. Body: ${body.substring(0, body.length > 500 ? 500 : body.length)}');
    
    try {
      final dynamic data = _parseJson(body);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        print('Data es Map, keys: ${data.keys}');
        if (data.containsKey('data') && data['data'] is List) {
          list = data['data'];
        } else if (data.containsKey('items') && data['items'] is List) {
          list = data['items'];
        } else {
          for (var value in data.values) {
            if (value is List) {
              list = value;
              break;
            }
          }
        }
      }
      
      print('Lista de horarios encontrada: ${list.length} items');
      
      final result = list
          .map((json) {
            try {
              return HorarioEmpleado.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              print('Error parseando horario empleado individual: $e');
              return null;
            }
          })
          .where((h) => h != null)
          .cast<HorarioEmpleado>()
          .toList();
      
      print('Horarios de empleado parseados exitosamente: ${result.length}');
      return result;
    } catch (e) {
      print('Error parseando lista de horarios de empleado: $e');
      return [];
    }
  }

  // Obtener citas de un empleado en una fecha específica
  Future<List<Agenda>> getAgendasEmpleadoFecha(String documentoEmpleado, DateTime fecha) async {
    try {
      final fechaStr = fecha.toIso8601String().split('T')[0];
      final url = '$baseUrl/Agenda/empleado/$documentoEmpleado/fecha/$fechaStr';
      
      print('🔍 getAgendasEmpleadoFecha:');
      print('  - URL: $url');
      print('  - Documento empleado: $documentoEmpleado');
      print('  - Fecha: $fechaStr');
      
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(timeoutDuration);

      print('  - Status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('  - Response body (primeros 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        final citas = _parseAgendaList(response.body);
        print('  - Citas parseadas: ${citas.length}');
        return citas;
      }
      
      print('  - No hubo éxito en la solicitud, devolviendo lista vacía');
      return [];
    } catch (e) {
      print('❌ Excepción al obtener agendas de empleado por fecha: $e');
      return [];
    }
  }

  // Obtener horas disponibles de un empleado en una fecha específica
  Future<List<String>> getHorasDisponibles(String documentoEmpleado, DateTime fecha) async {
    try {
      final fechaStr = fecha.toIso8601String().split('T')[0];
      final url = '$baseUrl/Agenda/horas-disponibles?documentoEmpleado=$documentoEmpleado&fecha=$fechaStr';
      
      print('🔍 getHorasDisponibles:');
      print('  - URL: $url');
      print('  - Documento empleado: $documentoEmpleado');
      print('  - Fecha: $fechaStr');
      
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(timeoutDuration);

      print('  - Status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('  - Response body: ${response.body}');
        
        try {
          final data = _parseJson(response.body);
          if (data is Map && data.containsKey('horasDisponibles') && data['horasDisponibles'] is List) {
            final List<String> horas = (data['horasDisponibles'] as List)
                .map((h) => h.toString())
                .toList();
            print('  - Horas disponibles: $horas');
            return horas;
          }
        } catch (e) {
          print('  - Error parseando horas disponibles: $e');
        }
      }
      
      return [];
    } catch (e) {
      print('❌ Excepción al obtener horas disponibles: $e');
      return [];
    }
  }

  // Búsqueda dinámica de clientes por nombre o documento
  Future<List<Cliente>> searchClientes(String query) async {
    try {
      if (query.isEmpty) {
        print('⚠️ Búsqueda de clientes: query vacío');
        return [];
      }

      final encodedQuery = Uri.encodeComponent(query);
      final url = '$baseUrl/Clientes?buscar=$encodedQuery&pagina=1';
      
      print('🔍 Buscando clientes en: $url');
      
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(timeoutDuration);

      print('📊 Status de respuesta clientes: ${response.statusCode}');
      print('📄 Body (primeros 200 chars): ${response.body.substring(0, min(200, response.body.length))}');

      if (response.statusCode == 200) {
        final clientes = _parseClienteList(response.body);
        print('✅ Clientes encontrados: ${clientes.length}');
        return clientes;
      } else {
        print('❌ Error en búsqueda de clientes: ${response.statusCode}');
        print('📝 Respuesta: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Excepción en búsqueda de clientes: $e');
      return [];
    }
  }

  // Búsqueda dinámica de empleados por nombre o documento
  Future<List<Empleado>> searchEmpleados(String query) async {
    try {
      if (query.isEmpty) {
        print('⚠️ Búsqueda de empleados: query vacío');
        return [];
      }

      final encodedQuery = Uri.encodeComponent(query);
      final url = '$baseUrl/Empleados?buscar=$encodedQuery&pagina=1';
      
      print('🔍 Buscando empleados en: $url');
      
      final response = await http
          .get(Uri.parse(url), headers: _headers)
          .timeout(timeoutDuration);

      print('📊 Status de respuesta empleados: ${response.statusCode}');
      print('📄 Body (primeros 200 chars): ${response.body.substring(0, min(200, response.body.length))}');

      if (response.statusCode == 200) {
        final empleados = _parseEmpleadoList(response.body);
        print('✅ Empleados encontrados: ${empleados.length}');
        return empleados;
      } else {
        print('❌ Error en búsqueda de empleados: ${response.statusCode}');
        print('📝 Respuesta: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Excepción en búsqueda de empleados: $e');
      return [];
    }
  }

  // Búsqueda dinámica de servicios
  Future<List<Servicio>> searchServicios(String query) async {
    try {
      if (query.isEmpty) {
        return [];
      }

      final result = await getServicios(pagina: 1, busqueda: query);
      final servicios = result['servicios'] as List<Servicio>;
      print('✅ Servicios encontrados: ${servicios.length}');
      return servicios;
    } catch (e) {
      print('❌ Excepción en búsqueda de servicios: $e');
      return [];
    }
  }
}
