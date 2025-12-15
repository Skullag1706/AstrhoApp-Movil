import 'dart:convert';
import 'package:http/http.dart' as http;
import '/agenda/models/agenda.dart';

class ApiService {
  static const String baseUrl = 'http://astrhoapp.somee.com/api';
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
          .timeout(
            timeoutDuration,
            onTimeout: () {
              throw Exception('Tiempo de espera agotado al cargar las citas');
            },
          );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return [];
        }

        try {
          final dynamic data = _parseJson(body);

          // Si la respuesta es una lista directamente
          if (data is List) {
            return data
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    try {
                      return Agenda.fromJson(item);
                    } catch (e) {
                      return null;
                    }
                  } else {
                    return null;
                  }
                })
                .where(
                  (agenda) =>
                      agenda != null && agenda.documentoCliente.isNotEmpty,
                )
                .cast<Agenda>()
                .toList();
          }
          // Si la respuesta es un objeto con una propiedad que contiene la lista
          else if (data is Map<String, dynamic>) {
            // Intentar encontrar una propiedad que sea una lista
            for (var key in data.keys) {
              if (data[key] is List) {
                return (data[key] as List)
                    .map((item) {
                      if (item is Map<String, dynamic>) {
                        try {
                          return Agenda.fromJson(item);
                        } catch (e) {
                          return null;
                        }
                      }
                      return null;
                    })
                    .where(
                      (agenda) =>
                          agenda != null && agenda.documentoCliente.isNotEmpty,
                    )
                    .cast<Agenda>()
                    .toList();
              }
            }
            // Si no hay lista, devolver vacío
            return [];
          }
          // Si la respuesta es un String (mensaje de error)
          else if (data is String) {
            // Si es un mensaje de error, devolver lista vacía
            return [];
          }
          return [];
        } catch (parseError) {
          // Si falla el parseo, puede ser que la respuesta sea un mensaje de error
          // Devolver lista vacía en lugar de fallar
          return [];
        }
      } else {
        // Si el status code no es 200, devolver lista vacía en lugar de lanzar excepción
        return [];
      }
    } catch (e) {
      // En caso de cualquier error, devolver lista vacía
      return [];
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
      throw e;
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
      final response = await http
          .get(Uri.parse('$baseUrl/Servicio'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          print('Respuesta de servicios vacía');
          return [];
        }
        try {
          final dynamic data = _parseJson(body);
          if (data is List) {
            final servicios = data
                .map((json) {
                  try {
                    return Servicio.fromJson(json as Map<String, dynamic>);
                  } catch (e) {
                    print('Error al parsear servicio: $e');
                    return null;
                  }
                })
                .where((s) => s != null)
                .cast<Servicio>()
                .toList();
            print('Servicios cargados: ${servicios.length}');
            return servicios;
          } else if (data is Map<String, dynamic>) {
            for (var key in data.keys) {
              if (data[key] is List) {
                final servicios = (data[key] as List)
                    .map((json) {
                      try {
                        return Servicio.fromJson(json as Map<String, dynamic>);
                      } catch (e) {
                        print('Error al parsear servicio: $e');
                        return null;
                      }
                    })
                    .where((s) => s != null)
                    .cast<Servicio>()
                    .toList();
                print('Servicios cargados: ${servicios.length}');
                return servicios;
              }
            }
            print('No se encontró lista de servicios en la respuesta');
            return [];
          }
          print('Formato de respuesta inesperado para servicios');
          return [];
        } catch (parseError) {
          print('Error al parsear servicios: $parseError');
          // Intentar con ruta alternativa (plural)
          try {
            final responseAlt = await http
                .get(Uri.parse('$baseUrl/Servicios'))
                .timeout(timeoutDuration);
            if (responseAlt.statusCode == 200) {
              final body = responseAlt.body.trim();
              if (body.isEmpty) return [];
              final dynamic data = _parseJson(body);
              if (data is List) {
                return data
                    .map((json) {
                      try {
                        return Servicio.fromJson(json as Map<String, dynamic>);
                      } catch (e) {
                        return null;
                      }
                    })
                    .where((s) => s != null)
                    .cast<Servicio>()
                    .toList();
              }
            }
          } catch (e) {
            print('Error al obtener servicios (ruta alternativa): $e');
          }
          return [];
        }
      } else if (response.statusCode == 404) {
        // Intentar con ruta alternativa (plural)
        try {
          final responseAlt = await http
              .get(Uri.parse('$baseUrl/Servicios'))
              .timeout(timeoutDuration);
          if (responseAlt.statusCode == 200) {
            final body = responseAlt.body.trim();
            if (body.isEmpty) return [];
            final dynamic data = _parseJson(body);
            if (data is List) {
              return data
                  .map((json) {
                    try {
                      return Servicio.fromJson(json as Map<String, dynamic>);
                    } catch (e) {
                      return null;
                    }
                  })
                  .where((s) => s != null)
                  .cast<Servicio>()
                  .toList();
            }
          }
        } catch (e) {
          print('Error al obtener servicios (ruta alternativa): $e');
        }
        print('Error 404 al obtener servicios');
        return [];
      } else {
        print(
          'Error al obtener servicios: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('Excepción al obtener servicios: $e');
      return [];
    }
  }

  // Obtener clientes
  Future<List<Cliente>> getClientes() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Cliente'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return [];
        }
        try {
          final dynamic data = _parseJson(body);
          if (data is List) {
            return data
                .map((json) {
                  try {
                    return Cliente.fromJson(json as Map<String, dynamic>);
                  } catch (e) {
                    // Si hay error al parsear un cliente, omitirlo
                    return null;
                  }
                })
                .where((c) => c != null)
                .cast<Cliente>()
                .toList();
          } else if (data is Map<String, dynamic>) {
            for (var key in data.keys) {
              if (data[key] is List) {
                return (data[key] as List)
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
              }
            }
            return [];
          }
          return [];
        } catch (parseError) {
          // Si hay error al parsear, intentar con rutas alternativas
          print('Error al parsear clientes: $parseError');
          return [];
        }
      } else if (response.statusCode == 404) {
        // Intentar con ruta alternativa (plural)
        try {
          final responseAlt = await http
              .get(Uri.parse('$baseUrl/Clientes'))
              .timeout(timeoutDuration);
          if (responseAlt.statusCode == 200) {
            final body = responseAlt.body.trim();
            if (body.isEmpty) return [];
            final dynamic data = _parseJson(body);
            if (data is List) {
              return data
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
            }
          }
        } catch (e) {
          print('Error al obtener clientes (ruta alternativa): $e');
        }
        return [];
      } else {
        print(
          'Error al obtener clientes: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('Excepción al obtener clientes: $e');
      return [];
    }
  }

  // Obtener citas del cliente logueado
  Future<List<Agenda>> getMisCitas() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Agenda/mis-citas'), headers: _headers)
          .timeout(
            timeoutDuration,
            onTimeout: () {
              throw Exception('Tiempo de espera agotado al cargar mis citas');
            },
          );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return [];
        }

        try {
          final dynamic data = _parseJson(body);

          // Si la respuesta es una lista directamente
          if (data is List) {
            return data
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    try {
                      return Agenda.fromJson(item);
                    } catch (e) {
                      return null;
                    }
                  } else {
                    return null;
                  }
                })
                .where((agenda) => agenda != null)
                .cast<Agenda>()
                .toList();
          }
          // Si la respuesta es un objeto con una propiedad que contiene la lista
          else if (data is Map<String, dynamic>) {
            // Intentar encontrar una propiedad que sea una lista
            for (var key in data.keys) {
              if (data[key] is List) {
                return (data[key] as List)
                    .map((item) {
                      if (item is Map<String, dynamic>) {
                        try {
                          return Agenda.fromJson(item);
                        } catch (e) {
                          return null;
                        }
                      } else {
                        return null;
                      }
                    })
                    .where((agenda) => agenda != null)
                    .cast<Agenda>()
                    .toList();
              }
            }
          }
          return [];
        } catch (e) {
          throw Exception('Error al procesar los datos de mis citas: $e');
        }
      } else {
        throw Exception(
          'Error al cargar mis citas: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Buscar cliente por usuario ID (para autocompletar formularios)
  Future<Cliente?> getClientePorUsuarioId(int userId) async {
    try {
      // Intentamos usar el endpoint público que usa AuthService
      final response = await http.get(Uri.parse('$baseUrl/Clientes'));

      if (response.statusCode == 200) {
        final body = response.body.trim();
        final dynamic data = _parseJson(body);
        if (data is List) {
          final clienteData = data.firstWhere(
            (c) => c['usuarioId'] == userId,
            orElse: () => null,
          );
          if (clienteData != null) {
            return Cliente.fromJson(clienteData);
          }
        }
      }
      return null;
    } catch (e) {
      print("Error buscando cliente por ID: $e");
      return null;
    }
  }

  // Obtener empleados
  Future<List<Empleado>> getEmpleados() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Empleado'), headers: _headers)
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return [];
        }
        try {
          final dynamic data = _parseJson(body);
          if (data is List) {
            return data
                .map((json) {
                  try {
                    return Empleado.fromJson(json as Map<String, dynamic>);
                  } catch (e) {
                    // Si hay error al parsear un empleado, omitirlo
                    return null;
                  }
                })
                .where((e) => e != null)
                .cast<Empleado>()
                .toList();
          } else if (data is Map<String, dynamic>) {
            for (var key in data.keys) {
              if (data[key] is List) {
                return (data[key] as List)
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
              }
            }
            return [];
          }
          return [];
        } catch (parseError) {
          // Si hay error al parsear, intentar con rutas alternativas
          print('Error al parsear empleados: $parseError');
          return [];
        }
      } else if (response.statusCode == 404) {
        // Intentar con ruta alternativa (plural)
        try {
          final responseAlt = await http
              .get(Uri.parse('$baseUrl/Empleados'))
              .timeout(timeoutDuration);
          if (responseAlt.statusCode == 200) {
            final body = responseAlt.body.trim();
            if (body.isEmpty) return [];
            final dynamic data = _parseJson(body);
            if (data is List) {
              return data
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
            }
          }
        } catch (e) {
          print('Error al obtener empleados (ruta alternativa): $e');
        }
        return [];
      } else {
        print(
          'Error al obtener empleados: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('Excepción al obtener empleados: $e');
      return [];
    }
  }
}
