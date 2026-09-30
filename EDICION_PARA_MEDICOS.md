# Edición para todos — candidata 2.4

Modo comunidad: paquete Android separado del original y de la beta. Cada médico configura su perfil y mantiene su base cifrada independiente. No hay nube compartida.

## Firma de la aplicación
Se preparó una clave estable privada; no está incluida en el repositorio. En GitHub: Settings → Secrets and variables → Actions → New repository secret. Nombre: ANGEL_SIGNING_JSON. Valor: contenido completo del archivo privado de firma entregado por separado. No subas ese archivo al repositorio ni lo compartas con los otros médicos. Ellos solo necesitan la APK. Conserva una copia privada: perder esta clave impide publicar actualizaciones compatibles.
Luego Actions → Generar APK Angel Medical → Run workflow → modo comunidad.

## Prueba antes de liberar
1. Crear un paciente ficticio y una historia inicial, evolución y receta. Abrir el historial y verificar todo el texto.
2. Imprimir y revisar PDF, autor, identificación, fecha y firmas pendientes.
3. Crear respaldo cifrado, guardarlo fuera del teléfono y restaurarlo primero con datos ficticios.
4. Comprobar bloqueo PIN/biometría, agenda, adjuntos y hospitalización/egreso.
5. Cada amigo verifica su nombre, cédula, establecimiento y logo.
6. Incorporar catálogo CIE-10 válido; no se recibió el original.
7. Revisar requisitos normativos y procedimientos del establecimiento. La app no tiene certificación NOM ni firma electrónica avanzada.

Para transferir expedientes desde una instalación anterior, usa respaldo cifrado completo; nunca desinstales la app original. Revisa el perfil tras restaurar y evita mezclar bases de médicos distintos. La restauración debe probarse primero con datos ficticios.

2.4 añade aviso de catálogo pendiente, validación previa de filas importadas y actualización de catálogo sin cambiar IDs ni favoritos existentes. El historial conserva los códigos registrados previamente.
