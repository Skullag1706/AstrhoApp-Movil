# Fix: Error 404 al Cambiar Estado de Citas

## Problema Identificado

Al intentar confirmar, completar o cancelar una cita desde `agenda_detail_screen.dart`, ocurría un error 404:

```
Exception: Error al confirmar la cita: 404
```

### Causa Raíz

El código estaba intentando usar endpoints específicos que **no existen en el backend**:

```
PUT /api/Agenda/{id}/confirmar       ← 404 Not Found
PUT /api/Agenda/{id}/completar       ← 404 Not Found
PUT /api/Agenda/{id}/cancelar        ← 404 Not Found
```

El backend solo tiene el endpoint genérico para actualizar agendas:

```
PUT /api/Agenda/{id}                 ← ✅ Existe
```

## Solución Aplicada

Reemplazé los métodos `confirmarCita()`, `completarCita()` y `cancelarCita()` para:

1. **Obtener la cita actual** usando `getAgendaById(id)`
2. **Crear una copia actualizada** con el nuevo `estadoId`:
   - `estadoId: 2` = Confirmado
   - `estadoId: 3` = Cancelado
   - `estadoId: 4` = Completado
3. **Usar el endpoint genérico** `updateAgenda()` para actualizar

### Código Anterior (Problemático)

```dart
Future<Agenda> confirmarCita(int id) async {
  final response = await http
      .put(
        Uri.parse('$baseUrl/Agenda/$id/confirmar'),  // ← 404
        headers: _headers,
      )
      .timeout(timeoutDuration);
  
  if (response.statusCode == 200 || response.statusCode == 204) {
    return await getAgendaById(id);
  }
  throw Exception('Error: ${response.statusCode}');
}
```

### Código Nuevo (Correcto)

```dart
Future<Agenda> confirmarCita(int id) async {
  try {
    // 1. Obtener cita actual
    final agenda = await getAgendaById(id);
    
    // 2. Crear copia con nuevo estado (ID: 2 = Confirmado)
    final agendaActualizada = Agenda(
      agendaId: agenda.agendaId,
      documentoCliente: agenda.documentoCliente,
      documentoEmpleado: agenda.documentoEmpleado,
      ventaId: agenda.ventaId,
      fechaCita: agenda.fechaCita,
      horaInicio: agenda.horaInicio,
      estadoId: 2,  // ← Confirmado
      metodopagoId: agenda.metodopagoId,
      observaciones: agenda.observaciones,
      nombreCliente: agenda.nombreCliente,
      nombreEmpleado: agenda.nombreEmpleado,
      nombreEstado: 'Confirmado',
      nombreMetodoPago: agenda.nombreMetodoPago,
      servicios: agenda.servicios,
    );
    
    // 3. Usar endpoint genérico existente
    return await updateAgenda(id, agendaActualizada);
  } catch (e) {
    throw Exception('Error al confirmar la cita: $e');
  }
}
```

## Mapeo de Estados

Los IDs de estado se definen en la API:

| ID  | Nombre       | Descripción                    |
|-----|------|------|
| 1   | Pendiente    | Cita creada, sin confirmar     |
| 2   | Confirmado   | Cliente confirmó la cita       |
| 3   | Cancelado    | Cita cancelada                 |
| 4   | Completado   | Cita completada/realizada      |

## Cambios de Arquitectura

### Antes (Endpoints no existentes)

```
confirmarCita(id)    → PUT /Agenda/{id}/confirmar
completarCita(id)    → PUT /Agenda/{id}/completar
cancelarCita(id)     → PUT /Agenda/{id}/cancelar
```

### Después (Endpoint genérico existente)

```
confirmarCita(id)    → getAgendaById(id) → updateAgenda(id, {...estadoId: 2})
completarCita(id)    → getAgendaById(id) → updateAgenda(id, {...estadoId: 4})
cancelarCita(id)     → getAgendaById(id) → updateAgenda(id, {...estadoId: 3})
```

## Flujo Completo

```
1. Usuario presiona "Confirmar Cita" en agenda_detail_screen
   ↓
2. Llama a _apiService.confirmarCita(agendaId)
   ↓
3. confirmarCita() obtiene la cita actual
   ↓
4. Crea una copia con estadoId: 2
   ↓
5. Llama a updateAgenda() con la cita actualizada
   ↓
6. updateAgenda() hace PUT /api/Agenda/{id} con el JSON completo
   ↓
7. Backend actualiza el estado
   ↓
8. getAgendaById() obtiene los datos actualizados
   ↓
9. UI se actualiza con el nuevo estado
```

## Impacto Esperado

✅ **No más errores 404** - Usa endpoints que existen en el backend  
✅ **Estados se actualizan correctamente** - Las citas cambian de estado  
✅ **Experiencia consistente** - El mismo patrón para confirmar, completar, cancelar  
✅ **Manejo de errores mejorado** - Try-catch captura excepciones claramente  

## Testing

1. **Confirmar una cita**
   - Abrir agenda_detail_screen con una cita "Pendiente"
   - Presionar "Confirmar Cita"
   - ✅ Debe cambiar a "Confirmado"
   - ✅ No debe haber error 404

2. **Completar una cita**
   - Abrir una cita "Confirmado"
   - Presionar "Completar Cita"
   - ✅ Debe cambiar a "Completado"

3. **Cancelar una cita**
   - Abrir una cita (en cualquier estado excepto completado)
   - Presionar "Cancelar Cita" y confirmar
   - ✅ Debe cambiar a "Cancelado"

## Notas Técnicas

- Los IDs de estado vienen del backend (1, 2, 3, 4)
- El campo `nombreEstado` se actualiza junto con `estadoId`
- Se obtiene la cita actual primero para preservar todos los campos
- El método `updateAgenda()` hace un PUT con el JSON completo de la cita
- Los cambios se reflejan inmediatamente en la UI después de la respuesta

## Archivos Modificados

- `lib/core/services/api_service.dart`
  - Reemplazado `confirmarCita()` - Ahora usa `updateAgenda()` con `estadoId: 2`
  - Reemplazado `completarCita()` - Ahora usa `updateAgenda()` con `estadoId: 4`
  - Reemplazado `cancelarCita()` - Ahora usa `updateAgenda()` con `estadoId: 3`

