class Agenda {
  final int? agendaId;
  final String documentoCliente;
  final String documentoEmpleado;
  final String? ventaId;
  final DateTime fechaCita;
  final String horaInicio;
  final int? estadoId;
  final int metodopagoId;
  final String? observaciones;
  final String? nombreCliente;
  final String? nombreEmpleado;
  final String? nombreEstado;
  final String? nombreMetodoPago;
  final List<Servicio>? servicios;

  Agenda({
    this.agendaId,
    required this.documentoCliente,
    required this.documentoEmpleado,
    this.ventaId,
    required this.fechaCita,
    required this.horaInicio,
    this.estadoId,
    required this.metodopagoId,
    this.observaciones,
    this.nombreCliente,
    this.nombreEmpleado,
    this.nombreEstado,
    this.nombreMetodoPago,
    this.servicios,
  });

  factory Agenda.fromJson(Map<String, dynamic> json) {
    // La API devuelve 'estado' como String y 'metodoPago' como String
    // Necesitamos mapearlos a IDs si es necesario, pero por ahora los guardamos como nombres
    String estadoNombre =
        json['estado']?.toString() ?? json['estadoId']?.toString() ?? '';
    String metodoPagoNombre =
        json['nombreMetodoPago']?.toString() ??
        json['nombre_metodo_pago']?.toString() ??
        json['metodoPago']?.toString() ??
        json['metodo_pago']?.toString() ??
        '';

    // Si servicios es un array de strings, crear objetos Servicio simples
    List<Servicio>? serviciosList;
    if (json['servicios'] != null) {
      if (json['servicios'] is List) {
        serviciosList = (json['servicios'] as List).map((s) {
          if (s is String) {
            // Si es un string, crear un Servicio simple
            return Servicio(
              servicioId: 0,
              nombre: s,
              precio: 0,
              duracion: 0,
              estado: true,
            );
          } else if (s is Map<String, dynamic>) {
            return Servicio.fromJson(s);
          }
          return Servicio(
            servicioId: 0,
            nombre: s.toString(),
            precio: 0,
            duracion: 0,
            estado: true,
          );
        }).toList();
      }
    }

    return Agenda(
      agendaId: json['agendaId'] ?? json['agenda_id'],
      documentoCliente:
          json['documentoCliente'] ?? json['documento_cliente'] ?? '',
      documentoEmpleado:
          json['documentoEmpleado'] ?? json['documento_empleado'] ?? '',
      ventaId: json['ventaId'] ?? json['venta_id'],
      fechaCita: json['fechaCita'] != null
          ? DateTime.parse(json['fechaCita'])
          : json['fecha_cita'] != null
          ? DateTime.parse(json['fecha_cita'])
          : DateTime.now(),
      horaInicio: json['horaInicio'] ?? json['hora_inicio'] ?? '',
      // Quitar campo horaFin
      // Mapear estado: si viene como String, usar 0 como ID temporal
      estadoId: json['estadoId'] ?? json['estado_id'] ?? 0,
      // Mapear metodoPago: intentar obtener el ID numérico primero
      metodopagoId: json['metodopagoId'] is int
          ? json['metodopagoId']
          : json['metodopago_id'] is int
          ? json['metodopago_id']
          : (json['metodopagoId'] != null &&
                json['metodopagoId'].toString().isNotEmpty &&
                int.tryParse(json['metodopagoId'].toString()) != null)
          ? int.parse(json['metodopagoId'].toString())
          : (json['metodopago_id'] != null &&
                json['metodopago_id'].toString().isNotEmpty &&
                int.tryParse(json['metodopago_id'].toString()) != null)
          ? int.parse(json['metodopago_id'].toString())
          : 0,
      observaciones: json['observaciones'],
      nombreCliente:
          json['clienteNombre'] ??
          json['nombreCliente'] ??
          json['nombre_cliente'],
      nombreEmpleado:
          json['empleadoNombre'] ??
          json['nombreEmpleado'] ??
          json['nombre_empleado'],
      nombreEstado: estadoNombre.isNotEmpty
          ? estadoNombre
          : (json['nombreEstado'] ?? json['nombre_estado']),
      nombreMetodoPago: metodoPagoNombre.isNotEmpty
          ? metodoPagoNombre
          : (json['nombreMetodoPago'] ?? json['nombre_metodo_pago']),
      servicios: serviciosList,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'documentoCliente': documentoCliente,
      'documentoEmpleado': documentoEmpleado,
      'fechaCita': fechaCita.toIso8601String().split('T')[0],
      'horaInicio': horaInicio,
      // Quitar horaFin
      'metodoPagoId': metodopagoId,
    };

    // Agregar campos opcionales solo si tienen valor
    if (agendaId != null) {
      json['agendaId'] = agendaId;
    }
    if (estadoId != null && estadoId! > 0) {
      json['estadoId'] = estadoId;
    }
    if (ventaId != null && ventaId!.isNotEmpty) {
      json['ventaId'] = ventaId;
    }
    if (observaciones != null && observaciones!.isNotEmpty) {
      json['observaciones'] = observaciones;
    }

    // Servicios: SIEMPRE enviar la lista de IDs de servicios (requerido por la API)
    // La API requiere que siempre se envíe el array de servicios
    if (servicios != null && servicios!.isNotEmpty) {
      final serviciosIds = servicios!
          .map((s) => s.servicioId)
          .where((id) => id > 0)
          .toList();
      json['serviciosIds'] = serviciosIds;
    } else {
      // Enviar array vacío si no hay servicios (aunque esto no debería pasar por validación)
      json['serviciosIds'] = <int>[];
    }

    return json;
  }
}

class Servicio {
  final int servicioId;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int duracion;
  final bool estado;

  Servicio({
    required this.servicioId,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.duracion,
    required this.estado,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) {
    return Servicio(
      servicioId: json['servicioId'] ?? json['servicio_id'] ?? 0,
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      precio: (json['precio'] ?? json['precio'] ?? 0).toDouble(),
      duracion: json['duracion'] ?? 0,
      estado: json['estado'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'servicioId': servicioId,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'duracion': duracion,
      'estado': estado,
    };
  }
}

class Estado {
  final int estadoId;
  final String nombre;

  Estado({required this.estadoId, required this.nombre});

  factory Estado.fromJson(Map<String, dynamic> json) {
    return Estado(
      estadoId: json['estadoId'] ?? json['estado_id'] ?? 0,
      nombre: json['nombre'] ?? '',
    );
  }
}

class MetodoPago {
  final int metodopagoId;
  final String nombre;

  MetodoPago({required this.metodopagoId, required this.nombre});

  factory MetodoPago.fromJson(Map<String, dynamic> json) {
    return MetodoPago(
      metodopagoId: json['metodopagoId'] ?? json['metodopago_id'] ?? 0,
      nombre: json['nombre'] ?? '',
    );
  }
}

class Cliente {
  final String documentoCliente;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? tipoDocumento;
  final bool? estado;
  final int? usuarioId;

  Cliente({
    required this.documentoCliente,
    required this.nombre,
    this.telefono,
    this.email,
    this.tipoDocumento,
    this.estado,
    this.usuarioId,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    final docCliente =
        json['documentoCliente'] ?? json['documento_cliente'] ?? '';
    final nombreCliente = json['nombre'] ?? '';

    // Validar que al menos tenga documento o nombre
    if (docCliente.isEmpty && nombreCliente.isEmpty) {
      throw Exception('Cliente inválido: falta documento y nombre');
    }

    return Cliente(
      documentoCliente: docCliente.isNotEmpty ? docCliente : nombreCliente,
      nombre: nombreCliente.isNotEmpty ? nombreCliente : docCliente,
      telefono: json['telefono'],
      email: json['email'],
      tipoDocumento: json['tipoDocumento'] ?? json['tipo_documento'],
      estado: json['estado'],
      usuarioId: json['usuarioId'] ?? json['usuario_id'],
    );
  }
}

class Empleado {
  final String documentoEmpleado;
  final String nombre;
  final String? telefono;
  final String? email;
  final String? tipoDocumento;
  final bool? estado;

  Empleado({
    required this.documentoEmpleado,
    required this.nombre,
    this.telefono,
    this.email,
    this.tipoDocumento,
    this.estado,
  });

  factory Empleado.fromJson(Map<String, dynamic> json) {
    final docEmpleado =
        json['documentoEmpleado'] ?? json['documento_empleado'] ?? '';
    final nombreEmpleado = json['nombre'] ?? '';

    // Validar que al menos tenga documento o nombre
    if (docEmpleado.isEmpty && nombreEmpleado.isEmpty) {
      throw Exception('Empleado inválido: falta documento y nombre');
    }

    return Empleado(
      documentoEmpleado: docEmpleado.isNotEmpty ? docEmpleado : nombreEmpleado,
      nombre: nombreEmpleado.isNotEmpty ? nombreEmpleado : docEmpleado,
      telefono: json['telefono'],
      email: json['email'],
      tipoDocumento: json['tipoDocumento'] ?? json['tipo_documento'],
      estado: json['estado'],
    );
  }
}
