# Angel Medical 2.3 — beta para GitHub

Proyecto Flutter para una beta privada. Aún no se ha compilado ni probado en Android esta versión. No es una certificación de cumplimiento NOM.

## Qué cambia
- Historia clínica inicial guiada por secciones, preguntas y estructuras para completar. No genera diagnósticos, dosis ni hallazgos automáticamente.
- Bloqueo de finalización si quedan marcadores `[Completar]` en campos activos.
- Perfil de cada médico, cédula, establecimiento, domicilio, teléfono y logo propio; los datos del autor quedan guardados con cada nota.
- Conserva borradores, notas anteriores, correcciones auditadas, respaldo cifrado y adaptación documental de la versión 2.2. Consulta ADAPTACION_NOM.md.
- Primera configuración obligatoria del perfil. Cada instalación mantiene un expediente local independiente. No hay cuentas compartidas, sincronización entre médicos ni colaboración en tiempo real.

## Subir a GitHub
1. Crea un repositorio **privado** y descomprime este paquete.
2. Sube el contenido de esta carpeta a la raíz del repositorio, incluyendo `.github`. No subas pacientes, respaldos ni claves de firma. No reemplaces un repositorio existente sin revisar sus diferencias.
3. En GitHub abre **Actions → Generar APK Angel Medical → Run workflow**, selecciona **pruebas**.
4. Cuando todas las verificaciones pasen, descarga el artifact de esa ejecución y extrae la APK. Si falla, comparte el registro de error, sin secretos.

GitHub hace la compilación; no requiere Flutter en tu PC. Para subir cómodamente una carpeta completa puedes usar GitHub Desktop en una PC. Esta entrega es código y configuración, no una APK ya compilada.

## Tres modos
- **pruebas**: aplicación separada del Angel Medical actual, perfil vacío, firma temporal de CI. Usa exclusivamente pacientes ficticios. La firma puede cambiar entre ejecuciones y no garantiza actualizaciones conservando datos.
- **comunidad**: aplicación separada para los otros médicos, perfil vacío, requiere firma estable. Cada médico configura sus datos. No es una base clínica compartida.
- **personal**: mismo identificador Android de la aplicación de Ángel. Requiere exactamente la clave con que se firmó la APK instalada; una clave nueva no puede actualizarla. Haz respaldo verificable antes de probar una actualización y conserva la aplicación anterior.

## Firma estable
Crea en Settings → Environments los entornos `comunidad` y `personal`. En cada uno guarda secretos `ANGEL_KEYSTORE_B64`, `ANGEL_STORE_PASSWORD`, `ANGEL_KEY_ALIAS`, `ANGEL_KEY_PASSWORD`. El primero contiene el archivo keystore codificado en base64. No publiques ni envíes estas claves por chat.
Para comunidad se puede crear una clave propia una sola vez con Java/keytool; conserva una copia privada con sus contraseñas. Para personal usa la clave original, que pudo ser el debug.keystore del PC que compiló la versión instalada. No la regeneres.
Las APK firmadas también se entregan como artifacts privados; el flujo no publica releases ni convierte el repositorio en público. La licencia para publicar código abierto está pendiente de definir.

## Límites y revisión antes de uso clínico
- Campos basados en NOM-004-SSA3-2012 y controles documentales; no equivalen por sí solos a cumplimiento integral. Revisión médica, jurídica y técnica pendiente, incluyendo aplicabilidad de NOM-024, firma electrónica, conservación y procedimientos del establecimiento.
- Catálogo CIE-10 original no recibido: `assets/data/cie10_full.json` contiene una lista vacía. Falta incorporar un catálogo válido con el formato que lee la app antes de ofrecer esa búsqueda. No se inventaron códigos.
- Logos originales no disponibles; se usa encabezado neutro o el logo cargado. El logo queda en la base cifrada y en instantáneas de autor por nota, lo que aumenta su tamaño.
- Falta ejecutar análisis Flutter, pruebas de widgets y compilación real en Actions, y comprobar instalación, apertura del historial completo, PDF, respaldos y actualización en dispositivos. Primero prueben ustedes tres con datos ficticios.
- No hay validación oficial, firma electrónica avanzada ni sugerencias diagnósticas por IA. El médico confirma y firma el contenido.

## Pruebas locales de lógica
`dart test/nom_cases.dart`, `dart test/guidance_cases.dart`, `dart checks/check_models.dart`, `python checks/check_migration.py`, `python checks/check_nom_migration.py`.
Los scripts SQL comprueban preservación y rollback con SQLite de prueba; la migración SQLCipher del dispositivo también requiere prueba Android.
