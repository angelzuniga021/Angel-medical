# Ángel Medical 2.7.0

## Perfil y actualizaciones

Un perfil con nombre o cédula guardados se reconoce como existente aunque falten campos requeridos. La bienvenida ya no exige repetir la configuración completa para consultar la base. Inicio muestra qué falta y permite revisar los valores guardados. Las validaciones al finalizar notas mantienen los requisitos de identificación y establecimiento.

Al modificar el perfil se conserva el anterior en `nom_profile_previous` dentro de la misma base cifrada. Si el perfil principal queda vacío, se recupera ese perfil anterior de la misma base y se registra la recuperación. JSON corrupto produce error; no se sustituye silenciosamente ni se deduce identidad de notas de otros médicos.

Restaurar un respaldo antiguo sin identidad conserva el perfil local existente. Si el respaldo incluye identidad, se respeta ese perfil. La base y sus claves no se recrean ni se sustituyen durante una actualización de APK. La causa exacta del episodio reportado no puede confirmarse sin revisar la configuración del dispositivo; se corrige la condición de bienvenida y se protege el flujo de restauración relacionado.

## Expediente y captura

- Cabecera del paciente rediseñada con identidad, conteos y alergias.
- Resumen de consulta con alergias completas, medicación habitual registrada, antecedentes y última valoración clínica (no última receta/documento).
- Historial con iconos por tipo de atención, jerarquía visual de fechas y contenido, búsqueda y filtros desplazables.
- Estado explícito: registro guardado sin firma electrónica; borradores siguen separados.
- Progreso por pasos de captura, sin confundirlo con cumplimiento normativo.
- Revisión del contenido antes de finalizar, con opción de seguir editando. Finalizar mantiene validación transaccional y registro de correcciones.

La versión conserva el catálogo CIE-10 de 2.6. No agrega firma criptográfica SAT, validación de revocación ni certificación NOM-024. Se mantienen las validaciones NOM-004 existentes; la revisión completa del alcance normativo sigue pendiente.

## Validación y actualización

CI realiza análisis Flutter, pruebas de perfiles/restauración y diseño en pantalla de 320 px con texto al 150%, pruebas existentes, checks de catálogo y conservación de datos, y APK comunitaria con firma estable. Validación visual final en teléfono real corresponde a la prueba de instalación.

Crear respaldo externo y actualizar sobre la APK comunitaria existente, sin desinstalar ni borrar datos.
