# Ángel Medical 2.9.1

Corrige OPERATION_FAILED al integrar la firma al PDF en Android. PdfDocument.save usa un isolate de fondo; el callback de firma requiere el BinaryMessenger del isolate de interfaz. Para documentos firmados se utiliza Document.write(PdfStream), que conserva ese contexto. Los documentos sin firma mantienen save.

Prueba de regresión: generación de PDF con llamada real a MethodChannel y manejador simulado; comprueba que la llamada llega una vez al messenger de interfaz. Se conservan las pruebas de CMS real con OpenSSL, rechazo de alteraciones y paginación.

Sin migraciones ni cambios en expedientes o firmas existentes. No guarda clave privada ni contraseña.
