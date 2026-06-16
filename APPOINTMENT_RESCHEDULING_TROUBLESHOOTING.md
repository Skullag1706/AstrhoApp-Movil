# Appointment Rescheduling - Complete Troubleshooting Guide

## Root Cause Analysis

### The Problem
When users attempted to reschedule an appointment, the following occurred:
1. The appointment flow seemed to complete normally
2. A confirmation message/modal appeared (but was empty)
3. The PUT request to update the appointment was NOT being executed
4. The appointment in the database was NOT being updated

### Why This Happened

There was a **navigation flow bug** that prevented the API call from being properly executed. The code was immediately returning from the appointment flow screen without actually showing the confirmation step or properly handling the API response.

---

## Implementation Details

### Fix #1: API Request Logging

**File:** `lib/core/services/api_service.dart`

**Method:** `updateAgenda(int id, Agenda agenda)`

**What Was Added:**

```dart
// BEFORE: Minimal logging
print('Respuesta del servidor: ${response.statusCode} - ${response.body}');

// AFTER: Comprehensive logging
print('========================================');
print('🔄 ACTUALIZANDO CITA (PUT REQUEST)');
print('========================================');
print('URL: $baseUrl/Agenda/$id');
print('Agenda ID: $id');
print('Datos enviados: ${json.encode(jsonData)}');
print('Headers: $_headers');
// ... response logging ...
print('Status Code: ${response.statusCode}');
print('Response Body: ${response.body}');
print('Response Headers: ${response.headers}');
```

**Why This Matters:**
- Shows exactly what URL is being called
- Displays the complete request payload
- Shows whether headers (especially authorization) are included
- Captures the full response for debugging API issues

---

### Fix #2: Confirmation Logging

**File:** `lib/agenda/screens/appointment_flow_screen.dart`

**Method:** `_confirmAppointment()`

**What Was Added:**

```dart
// BEFORE: No pre-submission logging
final agenda = Agenda(...);
agendaResultado = await _apiService.updateAgenda(agenda.agendaId!, agenda);

// AFTER: Detailed pre and post-submission logging
print('========================================');
print('🔄 PREPARANDO ACTUALIZACIÓN DE CITA');
print('========================================');
print('Agenda ID a actualizar: ${widget.agendaToEdit!.agendaId}');
print('Documento Cliente: ${selectedCliente!.documentoCliente}');
// ... more logging ...

print('📤 Enviando PUT request...');
agendaResultado = await _apiService.updateAgenda(agenda.agendaId!, agenda);
print('✅ Respuesta recibida del servidor');
print('Resultado: ${agendaResultado.agendaId}');
```

**Why This Matters:**
- Confirms all data is correctly populated before API call
- Shows when the API call starts and completes
- Helps identify if the appointment object is properly formed

---

### Fix #3: Navigation Flow (THE CRITICAL FIX)

**File:** `lib/agenda/screens/appointment_flow_screen.dart`

**Method:** `_confirmAppointment()`, lines 2945-2965

**What Was Changed:**

```dart
// BEFORE: Closes the entire appointment screen without showing confirmation
if (mounted) {
  Navigator.pop(context, agendaResultado);
}

// AFTER: Navigates to the confirmation screen (step 7)
if (mounted) {
  setState(() {
    currentStep = _getSteps().length - 1;  // Set to last step (confirmation)
  });
  
  _pageController.animateToPage(
    currentStep,
    duration: const Duration(milliseconds: 500),
    curve: Curves.easeInOut,
  );
}
```

**Why This Was the Key Issue:**
- The old code called `Navigator.pop()` immediately after the API call
- This **closed the entire appointment booking screen** 
- Users never saw the confirmation screen with the appointment details
- The API call happened, but users had no feedback

**How It Works Now:**
1. User clicks "Confirmar Cita" on the summary screen (step 6)
2. `_confirmAppointment()` is called
3. API request is sent (PUT for updates, POST for new appointments)
4. Upon success, the code now navigates to the confirmation screen (step 7)
5. User sees the confirmation with appointment details
6. User can click "Ver mis citas" or "Ir al inicio" to exit

---

## Understanding the Appointment Flow Steps

The appointment booking process has 7 steps:

| Step | Screen | Purpose |
|------|--------|---------|
| 0 | Cliente Selection | Select which client (for assistants/admins) |
| 1 | Services | Choose services to schedule |
| 2 | Payment Method | Select payment method |
| 3 | Professional | Choose which professional to book |
| 4 | Schedule | Select date and time |
| 5 | Summary | Review all details before confirming |
| **6** | **Confirmation** | **Show success after API call** |

**Key Point:** Step 6 (confirmation) was being skipped because the code was returning/closing before getting there.

---

## Expected Console Output During Rescheduling

### When Everything Works Correctly:

```
========================================
🔄 PREPARANDO ACTUALIZACIÓN DE CITA
========================================
Agenda ID a actualizar: 123
Documento Cliente: 1028192812
Documento Empleado: 0987654321
Fecha: 2026-06-20
Hora: 14:30:00
Servicios seleccionados: {1, 2, 3}
Método de pago: 2

📤 Enviando PUT request...

========================================
🔄 ACTUALIZANDO CITA (PUT REQUEST)
========================================
URL: http://www.astrhoapp.somee.com/api/Agenda/123
Agenda ID: 123
Datos enviados: {"documentoCliente":"1028192812","documentoEmpleado":"0987654321",...}
Headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer eyJ...'}

========================================
📊 RESPUESTA DEL SERVIDOR
========================================
Status Code: 200
Response Body: {"agendaId":123,"documentoCliente":"1028192812",...}
Response Headers: {content-type: application/json, ...}

✅ PUT Request exitoso (200)
✅ Respuesta parseada como Agenda

✅ Respuesta recibida del servidor
Resultado: 123

========================================
✅ NAVEGANDO A PANTALLA DE CONFIRMACIÓN
========================================
currentStep anterior: 5
Total de pasos: 7
currentStep nuevo: 6

✅ Animación iniciada hacia página 6
```

### If There's an Error:

```
========================================
❌ ERROR EN CONFIRMACIÓN DE CITA
========================================
Error: Exception: Error al actualizar la cita: No autorizado para registrar cliente
Stack Trace: ... (full stack trace shown)
isLoading: false
```

---

## Common Issues and Solutions

### Issue #1: Confirmation Screen Appears But Shows No Data

**Symptoms:**
- User sees "¡Cita Confirmada!" message but details are blank

**Possible Causes:**
1. The `selectedEmpleado` or `selectedCliente` became null
2. The `serviciosSeleccionados` list is empty
3. Data wasn't properly passed through the steps

**How to Debug:**
1. Check console logs for step 6 navigation message
2. Look for data in the logs before "Confirmación" step
3. Verify that `selectedEmpleado`, `selectedCliente`, etc. have values

**Solution:**
- Verify all required fields are selected before reaching summary
- Check that the data persists across step transitions

---

### Issue #2: PUT Request Returns 401 Unauthorized

**Symptoms:**
- Error logs show "Status Code: 401"
- Message: "No autorizado para..."

**Possible Causes:**
1. Authentication token expired
2. Token not included in request headers
3. User permissions don't allow appointment updates

**How to Debug:**
1. Check the "Authorization" header in logs
2. Verify token starts with "Bearer "
3. Check user role/permissions

**Solution:**
- Log out and log back in to refresh token
- Verify user has appointment edit permissions
- Check token expiration time

---

### Issue #3: PUT Request Returns 400 Bad Request

**Symptoms:**
- Error logs show "Status Code: 400"
- Message contains validation errors

**Possible Causes:**
1. Required fields missing from request body
2. Data format is invalid (wrong date format, etc.)
3. Appointment state doesn't allow updates

**How to Debug:**
1. Check the "Datos enviados" log for the request body
2. Verify all required fields are present
3. Check error response message in logs

**Solution:**
- Ensure all required fields are selected
- Verify date format is YYYY-MM-DD
- Check if appointment is in a state that can be updated (not completed/cancelled)

---

### Issue #4: PUT Request Returns 500 Server Error

**Symptoms:**
- Error logs show "Status Code: 500"
- "Este servicio no se encuentra disponible actualmente"

**Possible Causes:**
1. Backend database error
2. Backend service is down
3. Invalid data caused database query error

**How to Debug:**
1. Check backend error logs
2. Verify database connectivity
3. Test endpoint directly with Postman/cURL

**Solution:**
- Check backend server status
- Contact backend team with request details from logs
- Retry after verifying backend is operational

---

### Issue #5: Navigation to Confirmation Doesn't Happen

**Symptoms:**
- API call succeeds but user doesn't see confirmation screen
- User gets kicked back to home screen or previous screen

**Possible Causes:**
1. `mounted` check failed
2. PageController reference was disposed
3. `_getSteps().length` calculation was wrong

**How to Debug:**
1. Check console for "NAVEGANDO A PANTALLA DE CONFIRMACIÓN" message
2. Look for any errors about PageController or mounted state
3. Verify total steps count in logs

**Solution:**
- Ensure the screen is still mounted (check for "mounted" logs)
- Verify PageView still exists and PageController is valid
- Check that `_getSteps().length` matches expected count

---

## Testing Checklist

- [ ] Create a new appointment (verify it works)
- [ ] Open an existing appointment for rescheduling
- [ ] Change the date to a different date
- [ ] Change the time to a different time
- [ ] Change the services
- [ ] Change the professional (if allowed)
- [ ] Change the payment method
- [ ] Click "Confirmar Cita"
- [ ] Verify console logs show successful PUT request
- [ ] Verify confirmation screen appears with correct details
- [ ] Click "Ver mis citas"
- [ ] Refresh the appointments list
- [ ] Verify the appointment reflects the new details

---

## API Endpoint Details

### Endpoint
```
PUT /api/Agenda/{appointmentId}
```

### Authentication
```
Authorization: Bearer {jwt_token}
Content-Type: application/json
```

### Request Body Structure
```json
{
  "agendaId": 123,                          // Optional, included in ID
  "documentoCliente": "1028192812",         // Required
  "documentoEmpleado": "0987654321",        // Required
  "fechaCita": "2026-06-20",                // Required (YYYY-MM-DD format)
  "horaInicio": "14:30:00",                 // Required (HH:MM:SS format)
  "metodoPagoId": 2,                        // Required
  "serviciosIds": [1, 2, 3],                // Required (array of service IDs)
  "estadoId": 1,                            // Optional (1=Pending, 2=Confirmed, etc.)
  "observaciones": "Special instructions"   // Optional
}
```

### Success Response (200 OK)
```json
{
  "agendaId": 123,
  "documentoCliente": "1028192812",
  "documentoEmpleado": "0987654321",
  "fechaCita": "2026-06-20",
  "horaInicio": "14:30:00",
  "nombreCliente": "Juan Pérez",
  "nombreEmpleado": "María García",
  "nombreEstado": "Pendiente",
  "nombreMetodoPago": "Tarjeta",
  "servicios": [...]
}
```

### Error Response (400 Bad Request)
```json
{
  "errors": {
    "fechaCita": ["La fecha no puede ser en el pasado"],
    "serviciosIds": ["Debe seleccionar al menos un servicio"]
  }
}
```

---

## Performance Considerations

1. **API Call Duration:** PUT requests typically take 1-3 seconds
2. **Page Navigation:** Animation takes 500ms, no blocking
3. **No UI Freezing:** isLoading state prevents double-submission
4. **Error Handling:** If error occurs, user sees error message and can retry

---

## Future Improvements

1. **Add optimistic updates** to show changes immediately
2. **Implement refresh** to sync with backend after confirmation
3. **Add retry logic** for failed requests
4. **Cache appointment data** to reduce API calls
5. **Add analytics** to track rescheduling success rates



---

## PageController Error Fix

### Issue: "PageController is not attached to a PageView"

**Error Message:**
```
E/flutter (20008): Failed assertion: line 189 pos 12: 'positions.isNotEmpty': 
PageController is not attached to a PageView.
```

**Root Cause:**
The code was trying to animate the PageController immediately after calling `setState()`, but the PageView wasn't fully rebuilt yet. This caused the PageController to not have any attached PageViews.

**Solution Implemented:**
Wrapped the `animateToPage()` call in `Future.microtask()` which defers execution until after the current frame's UI rebuild is complete.

**Code Change:**
```dart
// BEFORE: Causes PageController error
setState(() {
  currentStep = _getSteps().length - 1;
});
_pageController.animateToPage(currentStep, ...); // ❌ ERROR

// AFTER: Defers animation until PageView is ready
setState(() {
  currentStep = _getSteps().length - 1;
});
Future.microtask(() {
  if (mounted && _pageController.hasClients) {
    _pageController.animateToPage(currentStep, ...); // ✅ WORKS
  }
});
```

**How It Works:**
1. `setState()` is called to update `currentStep`
2. Flutter schedules a rebuild of the UI with the new `currentStep`
3. PageView rebuilds with `currentStep` value (via `controller: _pageController`)
4. `Future.microtask()` executes AFTER the rebuild completes
5. `_pageController.hasClients` confirms PageView is ready
6. `animateToPage()` now works because PageView is attached

**Fallback Mechanism:**
If `animateToPage()` still fails, the code falls back to `jumpToPage()` which doesn't require animation:
```dart
if (mounted && _pageController.hasClients) {
  _pageController.jumpToPage(currentStep); // Instant page switch
}
```

**Why This Pattern Works:**
- Microelements execution order: sync code → setState → rebuild → microelements → animation frames
- By using `Future.microtask()`, we ensure the PageView is fully rendered before trying to animate
- The `hasClients` check validates the PageController is properly attached
- The fallback ensures users see the confirmation screen even if animation fails

