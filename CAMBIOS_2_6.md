# Ángel Medical 2.6.0

- Interfaz Material 3 actualizada en azul/celeste: superficies, tipografía de encabezados, campos con foco visible, navegación y avisos flotantes. Inicio con accesos a pacientes y biblioteca CIE-10.
- Biblioteca CIE-10 independiente y selector de diagnósticos en consultas: búsqueda con/sin acentos, códigos con/sin punto, favoritos, capítulos y advertencia para códigos complementarios de morbilidad.
- Catálogo recibido del usuario: 14,498 registros originales; 14,497 referencias CIE-10 y un marcador 9999 excluido. 12,551 códigos marcados vigentes disponibles para nuevas selecciones. Referencias no vigentes conservadas en el recurso para filtrar nuevas selecciones, sin reescribir notas previas.
- Fuente y huellas SHA-256 en assets/data/cie10_source.json. La fecha de edición no está declarada en el archivo; no se afirma que sea la edición 2026. CATALOG_KEY original conservada; presentación decimal solo en pantalla/selección nueva.
- Carga adicional transaccional y repetible en instalaciones existentes; preserva IDs, favoritos y descripciones importadas. No se reemplaza ni recrea la base ni sus claves. La marca de versión se registra en la misma transacción.
- Búsqueda agrupa equivalentes con/sin punto y prioriza favoritos; cambiar favorito afecta ambos equivalentes. Diagnósticos históricos conservados íntegros.
- Se mantienen las validaciones y documentación NOM-004 existentes. Esta versión no acredita certificación NOM-024 ni incorpora firma electrónica real.

## Validación

Checks Python: catálogo, conservación de IDs/favoritos/notas, importación repetida, rollback y migraciones existentes. CI: análisis Flutter, pruebas del recurso completo y pruebas de pantalla de 320 px con texto 150% en temas claro/oscuro, construcción de APK comunitaria firmada.

Actualizar sobre la edición comunitaria existente, sin desinstalar. Crear y conservar un respaldo externo antes de actualizar. Verificación visual en dispositivo real pendiente de prueba del usuario.
