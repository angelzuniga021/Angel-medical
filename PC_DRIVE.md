# Preparación PC y Drive

Esta versión prepara intercambio, no entrega todavía aplicación de PC ni sincronización. No debe abrirse directamente una base SQLCipher dentro de una carpeta Drive: dos dispositivos pueden sobrescribir cambios o compartir un archivo incompleto.

## Formato AMX v1

Contenedor JSON `format=angel-medical-encrypted-exchange`, `v=1`, con `salt`, `nonce`, `mac`, `data` codificados Base64. Derivación PBKDF2-HMAC-SHA256, 150000 iteraciones, clave de 256 bits, sal aleatoria de 16 bytes. Cifrado AES-GCM-256; autenticación debe validarse antes de interpretar contenido. Contraseña UTF-8 exacta; no se almacena.

Contenido descifrado JSON `format=angel-medical-logical-snapshot`, `version=1`, `app_version`, `schema_version`, `database_uuid`, `created_at` UTC y `tables`. Una identidad aleatoria de 128 bits identifica la base; ID y relaciones existentes se conservan. Celdas SQL BLOB se representan como objeto `{"$binary":"BASE64"}`. Incluye perfiles, notas, historial, documentos y firmas. No contiene clave privada de e.firma ni clave de cifrado SQLCipher, que no están en tablas exportadas.

El archivo contiene datos clínicos sensibles cifrados; proteger contraseña y acceso a Drive. `.amx` no puede restaurarse con el restaurador `.ambak`. Continuar creando respaldos `.ambak` para recuperación actual. AMX conserva todas las filas, pero no define un mecanismo de fusión ni protección frente a sobrescritura entre equipos.

## Próxima fase

- Lector/escritor de escritorio y restauración validada de AMX con relaciones, archivos y firmas.
- Identidades globales por registro, eventos de cambio, versiones y resolución de conflictos; evitar sustitución de una base completa por otra.
- Autorización de Drive, intercambio cifrado, autenticación por usuario/dispositivo y auditoría de acceso.
- Pruebas de trabajo sin conexión, cambios simultáneos, revocación de dispositivos y recuperación.

Hasta implementar y probar estas funciones, compartir un AMX es únicamente transferir una instantánea cifrada.
