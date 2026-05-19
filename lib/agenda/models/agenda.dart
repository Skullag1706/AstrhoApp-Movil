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
    // Manejar estado (puede ser objeto o ID/Nombre directo)
    String estadoNombre = '';
    int? estadoIdValue;
    if (json['estado'] != null) {
      if (json['estado'] is Map<String, dynamic>) {
        estadoNombre = json['estado']['nombre']?.toString() ?? '';
        estadoIdValue = json['estado']['estadoId'] ?? json['estado']['estado_id'];
      } else {
        estadoNombre = json['estado'].toString();
      }
    }
    estadoNombre = estadoNombre.isNotEmpty
        ? estadoNombre
        : (json['nombreEstado'] ?? json['nombre_estado'] ?? '').toString();
    estadoIdValue = estadoIdValue ?? json['estadoId'] ?? json['estado_id'];

    // Manejar metodoPago (puede ser objeto o ID/Nombre directo)
    String metodoPagoNombre = '';
    int? metodoPagoIdValue;
    if (json['metodoPago'] != null || json['metodo_pago'] != null) {
      final mp = json['metodoPago'] ?? json['metodo_pago'];
      if (mp is Map<String, dynamic>) {
        metodoPagoNombre = mp['nombre']?.toString() ?? '';
        metodoPagoIdValue = mp['metodopagoId'] ?? mp['metodopago_id'];
      } else {
        metodoPagoNombre = mp.toString();
      }
    }
    metodoPagoNombre = metodoPagoNombre.isNotEmpty
        ? metodoPagoNombre
        : (json['nombreMetodoPago'] ??
                json['nombre_metodo_pago'] ??
                json['metodoPagoNombre'] ??
                '')
            .toString();
    metodoPagoIdValue = metodoPagoIdValue ??
        json['metodopagoId'] ??
        json['metodopago_id'] ??
        json['metodoPagoId'];

    // Manejar cliente y empleado (pueden ser objetos o nombres directos)
    String? nombreClienteValue = json['clienteNombre'] ??
        json['nombreCliente'] ??
        json['nombre_cliente'];
    // Solo intentar acceder a ['nombre'] si cliente es un Map
    final clienteField = json['cliente'];
    if (clienteField != null) {
      if (clienteField is Map<String, dynamic>) {
        nombreClienteValue ??= clienteField['nombre']?.toString();
      } else {
        nombreClienteValue ??= clienteField.toString();
      }
    }

    String? nombreEmpleadoValue = json['empleadoNombre'] ??
        json['nombreEmpleado'] ??
        json['nombre_empleado'];
    // Solo intentar acceder a ['nombre'] si empleado es un Map
    final empleadoField = json['empleado'];
    if (empleadoField != null) {
      if (empleadoField is Map<String, dynamic>) {
        nombreEmpleadoValue ??= empleadoField['nombre']?.toString();
      } else {
        nombreEmpleadoValue ??= empleadoField.toString();
      }
    }

    // Si servicios es un array de strings o de objetos
    List<Servicio>? serviciosList;
    if (json['servicios'] != null) {
      if (json['servicios'] is List) {
        serviciosList = (json['servicios'] as List).map((s) {
          if (s is String) {
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
      documentoCliente: json['documentoCliente']?.toString() ??
          json['documento_cliente']?.toString() ??
          '',
      documentoEmpleado: json['documentoEmpleado']?.toString() ??
          json['documento_empleado']?.toString() ??
          '',
      ventaId: json['ventaId']?.toString() ?? json['venta_id']?.toString(),
      fechaCita: DateTime.tryParse(json['fechaCita']?.toString() ?? '') ??
          DateTime.tryParse(json['fecha_cita']?.toString() ?? '') ??
          DateTime.now(),
      horaInicio:
          json['horaInicio']?.toString() ?? json['hora_inicio']?.toString() ?? '',
      estadoId: estadoIdValue is int ? estadoIdValue : (int.tryParse(estadoIdValue?.toString() ?? '') ?? 0),
      metodopagoId: metodoPagoIdValue is int ? metodoPagoIdValue : (int.tryParse(metodoPagoIdValue?.toString() ?? '') ?? 0),
      observaciones: json['observaciones']?.toString(),
      nombreCliente: nombreClienteValue?.toString(),
      nombreEmpleado: nombreEmpleadoValue?.toString(),
      nombreEstado: estadoNombre,
      nombreMetodoPago: metodoPagoNombre,
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
  final String? imagen;

  Servicio({
    required this.servicioId,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.duracion,
    required this.estado,
    this.imagen,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) {
    final precioValue = json['precio'];
    double precioDouble = 0.0;
    if (precioValue != null) {
      if (precioValue is double) {
        precioDouble = precioValue;
      } else if (precioValue is int) {
        precioDouble = precioValue.toDouble();
      } else if (precioValue is String) {
        try {
          precioDouble = double.parse(precioValue);
        } catch (_) {
          precioDouble = 0.0;
        }
      }
    }
    
    final duracionValue = json['duracion'] ?? json['duración'] ?? json['duracionMinutos'] ?? json['duracion_minutos'];
    int duracionInt = 0;
    if (duracionValue != null) {
      if (duracionValue is int) {
        duracionInt = duracionValue;
      } else if (duracionValue is double) {
        duracionInt = duracionValue.toInt();
      } else if (duracionValue is String) {
        try {
          duracionInt = int.parse(duracionValue);
        } catch (_) {
          duracionInt = 0;
        }
      }
    }
    
    return Servicio(
      servicioId: json['servicioId'] ?? json['servicio_id'] ?? 0,
      nombre: json['nombre']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      precio: precioDouble,
      duracion: duracionInt,
      estado: json['estado'] is bool ? json['estado'] : (json['estado'] == 1 || json['estado'] == 'true' || json['estado'] == 'True'),
      imagen: json['imagen']?.toString() ?? json['imagenUrl']?.toString() ?? json['imagen_url']?.toString(),
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
      'imagen': imagen,
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
  final String? direccion;
  final String? nombreUsuario;

  Cliente({
    required this.documentoCliente,
    required this.nombre,
    this.telefono,
    this.email,
    this.tipoDocumento,
    this.estado,
    this.usuarioId,
    this.direccion,
    this.nombreUsuario,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    final docCliente =
        json['documentoCliente']?.toString() ??
        json['documento_cliente']?.toString() ??
        '';
    final nombreCliente = json['nombre']?.toString() ?? '';

    // Validar que al menos tenga documento o nombre
    if (docCliente.isEmpty && nombreCliente.isEmpty) {
      throw Exception('Cliente inválido: falta documento y nombre');
    }

    // Parsear usuarioId desde múltiples nombres de campo y tipos
    int? parseUsuarioId() {
      final possibleIds = [
        json['usuarioId'],
        json['usuario_id'],
        json['idUsuario'],
        json['id_usuario'],
      ];
      for (final id in possibleIds) {
        if (id != null) {
          if (id is int) return id;
          if (id is String) {
            final parsed = int.tryParse(id);
            if (parsed != null) return parsed;
          }
        }
      }
      return null;
    }

    return Cliente(
      documentoCliente: docCliente.isNotEmpty ? docCliente : nombreCliente,
      nombre: nombreCliente.isNotEmpty ? nombreCliente : docCliente,
      telefono: json['telefono']?.toString(),
      email: json['email']?.toString(),
      tipoDocumento:
          json['tipoDocumento']?.toString() ??
          json['tipo_documento']?.toString(),
      estado: json['estado'] is bool
          ? json['estado']
          : (json['estado'] == 1 || json['estado'] == 'true'),
      usuarioId: parseUsuarioId(),
      direccion:
          json['dirección']?.toString() ??
          json['direccion']?.toString() ??
          json['dirección_cliente']?.toString(),
      nombreUsuario: json['nombreUsuario']?.toString(),
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
  final int? usuarioId;
  final String? direccion;

  Empleado({
    required this.documentoEmpleado,
    required this.nombre,
    this.telefono,
    this.email,
    this.tipoDocumento,
    this.estado,
    this.usuarioId,
    this.direccion,
  });

  factory Empleado.fromJson(Map<String, dynamic> json) {
    final docEmpleado =
        json['documentoEmpleado']?.toString() ??
        json['documento_empleado']?.toString() ??
        '';
    final nombreEmpleado = json['nombre']?.toString() ?? '';

    // Validar que al menos tenga documento o nombre
    if (docEmpleado.isEmpty && nombreEmpleado.isEmpty) {
      throw Exception('Empleado inválido: falta documento y nombre');
    }

    // Parsear usuarioId desde múltiples nombres de campo y tipos
    int? parseUsuarioId() {
      final possibleIds = [
        json['usuarioId'],
        json['usuario_id'],
        json['idUsuario'],
        json['id_usuario'],
      ];
      for (final id in possibleIds) {
        if (id != null) {
          if (id is int) return id;
          if (id is String) {
            final parsed = int.tryParse(id);
            if (parsed != null) return parsed;
          }
        }
      }
      return null;
    }

    return Empleado(
      documentoEmpleado: docEmpleado.isNotEmpty ? docEmpleado : nombreEmpleado,
      nombre: nombreEmpleado.isNotEmpty ? nombreEmpleado : docEmpleado,
      telefono: json['telefono']?.toString(),
      email: json['email']?.toString(),
      tipoDocumento:
          json['tipoDocumento']?.toString() ??
          json['tipo_documento']?.toString(),
      estado: json['estado'] is bool
          ? json['estado']
          : (json['estado'] == 1 || json['estado'] == 'true'),
      usuarioId: parseUsuarioId(),
      direccion:
          json['dirección']?.toString() ??
          json['direccion']?.toString() ??
          json['dirección_empleado']?.toString(),
    );
  }
}

class Horario {
  final int horarioId;
  final String diaSemana;
  final String horaInicio;
  final String horaFin;
  final bool estado;

  Horario({
    required this.horarioId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
  });

  factory Horario.fromJson(Map<String, dynamic> json) {
    // Obtener horas con valores por defecto en caso de error
    String horaInicioStr = json['horaInicio']?.toString() ?? json['hora_inicio']?.toString() ?? '09:00:00';
    String horaFinStr = json['horaFin']?.toString() ?? json['hora_fin']?.toString() ?? '18:00:00';
    
    // Si la hora está vacía, usar valores por defecto
    if (horaInicioStr.isEmpty) horaInicioStr = '09:00:00';
    if (horaFinStr.isEmpty) horaFinStr = '18:00:00';
    
    return Horario(
      horarioId: json['horarioId'] ?? json['horario_id'] ?? 0,
      diaSemana: json['diaSemana']?.toString() ?? json['dia_semana']?.toString() ?? 'lunes',
      horaInicio: horaInicioStr,
      horaFin: horaFinStr,
      estado: json['estado'] is bool ? json['estado'] : (json['estado'] == 1 || json['estado'] == 'true'),
    );
  }
}

class HorarioEmpleado {
  final int horarioEmpleadoId;
  final String documentoEmpleado;
  final int horarioId;
  final bool estado;
  final Horario? horario;

  HorarioEmpleado({
    required this.horarioEmpleadoId,
    required this.documentoEmpleado,
    required this.horarioId,
    required this.estado,
    this.horario,
  });

  factory HorarioEmpleado.fromJson(Map<String, dynamic> json) {
    print('Parsing HorarioEmpleado from: $json');
    
    Horario? horarioObj;
    
    // Intentar diferentes formas de encontrar el horario
    if (json['horario'] != null && json['horario'] is Map<String, dynamic>) {
      horarioObj = Horario.fromJson(json['horario']);
    } else if (json['Horario'] != null && json['Horario'] is Map<String, dynamic>) {
      horarioObj = Horario.fromJson(json['Horario']);
    } else {
      // Si el horario viene en la misma estructura (sin anidamiento)
      print('Horario no está anidado, intentando leer directamente');
      try {
        horarioObj = Horario.fromJson(json);
      } catch (e) {
        print('Error creando horario desde json principal: $e');
        // Horario por defecto si todo falla
        horarioObj = Horario(
          horarioId: json['horarioId'] ?? json['horario_id'] ?? 0,
          diaSemana: json['diaSemana']?.toString() ?? json['dia_semana']?.toString() ?? 'lunes',
          horaInicio: json['horaInicio']?.toString() ?? json['hora_inicio']?.toString() ?? '09:00:00',
          horaFin: json['horaFin']?.toString() ?? json['hora_fin']?.toString() ?? '18:00:00',
          estado: true,
        );
      }
    }

    print('HorarioEmpleado creado - horario: ${horarioObj.diaSemana}, ${horarioObj.horaInicio} - ${horarioObj.horaFin}');

    return HorarioEmpleado(
      horarioEmpleadoId: json['horarioEmpleadoId'] ?? json['horario_empleado_id'] ?? 0,
      documentoEmpleado: json['documentoEmpleado']?.toString() ?? json['documento_empleado']?.toString() ?? '',
      horarioId: json['horarioId'] ?? json['horario_id'] ?? 0,
      estado: json['estado'] is bool ? json['estado'] : (json['estado'] == 1 || json['estado'] == 'true'),
      horario: horarioObj,
    );
  }
}
