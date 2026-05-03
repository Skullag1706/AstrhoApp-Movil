import 'dart:convert';
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

  // Obtener todas las citas
  Future<List<Agenda>> getAgendas() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Agenda'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return _parseAgendaList(response.body);
      }
      return [];
    } catch (e) {
      print('Excepción al obtener todas las citas: $e');
      return [];
    }
  }

  // Obtener citas del cliente logueado
  Future<List<Agenda>> getMisCitas() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Agenda/mis-citas'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return _parseAgendaList(response.body);
      } else {
        print('Error en mis-citas: ${response.statusCode} - ${response.body}');
        return [];
      }
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

  // Obtener servicios
  Future<List<Servicio>> getServicios() async {
    try {
      // Intentar primero con la ruta plural
      final response = await http
          .get(Uri.parse('$baseUrl/Servicios'), headers: _headers)
          .timeout(timeoutDuration);

      print('Intentando endpoint: $baseUrl/Servicios');
      print('Respuesta servicios status: ${response.statusCode}');
      print('Respuesta servicios body: ${response.body}');

      if (response.statusCode == 200) {
        return _parseServicioList(response.body);
      } else if (response.statusCode == 404) {
        // Intentar con ruta singular
        final responseSingular = await http
            .get(Uri.parse('$baseUrl/Servicio'), headers: _headers)
            .timeout(timeoutDuration);
        print('Intentando endpoint singular: $baseUrl/Servicio');
        print('Respuesta singular status: ${responseSingular.statusCode}');
        if (responseSingular.statusCode == 200) {
          return _parseServicioList(responseSingular.body);
        }
      }
      return [];
    } catch (e) {
      print('Excepción al obtener servicios: $e');
      return [];
    }
  }

  List<Servicio> _parseServicioList(String body) {
    if (body.trim().isEmpty) {
      print('Cuerpo de servicios vacío');
      return [];
    }
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
      print('Lista de servicios para parsear: ${list.length} elementos');
      final servicios = list
          .map((json) {
            try {
              print('Parseando servicio: $json');
              final servicio = Servicio.fromJson(json as Map<String, dynamic>);
              print('Servicio parseado: ID=${servicio.servicioId}, Nombre=${servicio.nombre}, Precio=${servicio.precio}');
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
      for (var s in servicios) {
        print('  - ${s.servicioId}: ${s.nombre} - ${s.precio}');
      }
      return servicios;
    } catch (e) {
      print('Error general parseando lista de servicios: $e');
      return [];
    }
  }

  // Función para obtener TODOS los registros de una API con paginación
  Future<List<dynamic>> fetchAllPaginated(String endpoint) async {
    final List<dynamic> allItems = [];
    int page = 1;
    bool hasMore = true;
    const int pageSize = 100;

    while (hasMore) {
      final url = Uri.parse('$baseUrl$endpoint?page=$page&pageSize=$pageSize');
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
          
          if (items.length < pageSize) {
            print('Page has fewer items ($items.length) than pageSize ($pageSize), stopping');
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
    if (body.trim().isEmpty) return [];
    try {
      final dynamic data = _parseJson(body);
      List<dynamic> list = [];
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        // Buscar lista en propiedades comunes como 'data', 'items', 'values'
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
              return Cliente.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .where((c) => c != null)
          .cast<Cliente>()
          .toList();
    } catch (e) {
      print('Error parseando lista de clientes: $e');
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
              return Empleado.fromJson(json as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .where((e) => e != null)
          .cast<Empleado>()
          .toList();
    } catch (e) {
      print('Error parseando lista de empleados: $e');
      return [];
    }
  }
}
