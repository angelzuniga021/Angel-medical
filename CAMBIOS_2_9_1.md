# Ángel Medical 2.9.1

Corrige OPERATION_FAILED al integrar la firma al PDF en Android. PdfDocument.save usa un isolate de fondo; el callback de firma requiere el BinaryMessenger del isolate de interfaz. Se serializa el PDF con reserva criptográfica en el isolate de fondo; después, en el isolate de interfaz, se firma su ByteRange y se completa la reserva sin cambiar offsets. Un PDF provisional nunca se devuelve ni se guarda si falla la firma. Las credenciales no se capturan en el callback enviado al isolate de fondo.

Prueba de regresión: generación de PDF con llamada real a MethodChannel y manejador simulado; comprueba que la llamada llega una vez al messenger de interfaz. Se conservan las pruebas de CMS real con OpenSSL, rechazo de alteraciones y paginación.

Sin migraciones ni cambios en expedientes o firmas existentes. No guarda clave privada ni contraseña.
