# Ángel Medical 3.2

Aplicación Flutter para expediente clínico local cifrado en Android. Cada médico conserva su perfil y su propia base. Esta edición prepara intercambio futuro con PC, pero no incluye todavía una aplicación de escritorio ni sincronización entre dispositivos.

## Novedades de 3.2

- 37 herramientas locales (29 escalas y 8 calculadoras). Se añaden NEWS2 RCP 2017, RCRI Lee 1999, Apgar y Rockall completo.
- NEWS2 usa los valores medidos, valida escala de saturación 2 y muestra alerta por componente de 3 puntos aunque el total sea bajo.
- Acceso externo a PREVENT oficial; requiere internet. No contiene sus ecuaciones ni valida/transcribe resultados. La integración local queda pendiente del acuerdo y código oficial de la AHA.
- Fuentes, alcance y permisos: [ESCALAS_3_2.md](ESCALAS_3_2.md).

## Novedades previas de 3.1

- Catálogo independiente de 33 herramientas: 25 escalas y 8 calculadoras, con favoritos, búsqueda, filtro por tipo/área, cálculo sin internet y registro por paciente.
- Nuevas: PHQ-9, PHQ-2, GAD-7, GAD-2, sPESI 2010 y Ginebra revisada 2006.
- Formularios con avance, respuestas seleccionadas legibles, revisión del contexto y resultados con interpretación y límites. PHQ-9 presenta una alerta independiente del total al responder positivamente el ítem 9; la pregunta funcional no suma puntos.
- Las evaluaciones se guardan como registros nuevos, se pueden agregar al borrador de una nota o exportar a PDF.
- Esta edición no integra una API, contenido ni certificación de MDCalc. Consulta [ESCALAS_3_1.md](ESCALAS_3_1.md) para fuentes y alcance.

## Funciones del expediente

- Mapa corporal interactivo con vistas anterior/posterior, varias regiones, intensidad opcional y descripción. Se conserva en la nota, revisión, PDF y respaldo.
- Firma criptográfica local integrada al PDF con `.cer` y `.key` cifrada. Se conservan las firmas previas y se exporta la versión exacta firmada. Clave privada y contraseña no se guardan en la base.
- Revisión de documentación y pendientes normativos. No constituye certificación ni dictamen de cumplimiento NOM.
- Exportación cifrada `.amx` para un futuro lector en PC, compartible por el menú del sistema, incluido Drive cuando esté disponible. La recuperación actual sigue usando `.ambak`.
- Conservación del perfil existente al actualizar; historia guiada, resumen del paciente, historial completo, correcciones auditadas, agenda, documentos, PIN/biometría y catálogo CIE-10 precargado.

Consulta [CAMBIOS_2_8.md](CAMBIOS_2_8.md), [REVISION_NORMATIVA.md](REVISION_NORMATIVA.md) y [PC_DRIVE.md](PC_DRIVE.md).

## Descargar y actualizar

En **Actions → Generar APK Angel Medical**, abre una ejecución verde y descarga su artifact `Angel-Medical-comunidad-N`. Extrae el ZIP e instala la APK. Los artifacts se conservan 14 días.

Antes de actualizar, crea un respaldo `.ambak`, conserva su contraseña y guarda una copia fuera del teléfono. Instala la misma edición sobre la aplicación existente, sin desinstalar. Cambiar identificador o clave de firma Android produce otra instalación o impide actualizar: no regenerar la firma estable. Esquema actual 7, con evaluaciones clínicas conservadas dentro de la base y los respaldos.

## Firmar una nota

Guardar RFC propio en Perfil. Abrir una nota guardada, seleccionar **Firmar esta versión**, elegir certificado `.cer`, clave RSA `.key` DER PKCS#8 cifrada y su contraseña local. La firma se realiza sobre esa versión y conserva autor y fecha de atención originales. Una corrección identifica la firma previa como versión anterior.

Se verifica firma matemática, correspondencia clave/certificado y vigencia según reloj local. No se verifican cadena de confianza SAT, revocación ni sello de tiempo confiable. No se garantiza reconocimiento jurídico de un expediente concreto. Las pruebas automatizadas usan certificados ficticios; falta comprobación funcional con certificado SAT real, manejado exclusivamente por su titular. No subir claves privadas ni contraseñas al repositorio o al chat.

## Compilación y pruebas

GitHub Actions prepara Android con Flutter 3.47.2 y Java 17. Por defecto construye **comunidad** con la firma estable configurada en secretos. **pruebas** y **personal** son modos separados; consultar [EDICION_PARA_MEDICOS.md](EDICION_PARA_MEDICOS.md) antes de cambiar firma o identificador. Nunca publicar keystore ni secretos.

El flujo exige análisis Dart, pruebas Flutter, preservación/migración SQL, catálogo y favoritos, pruebas nativas de firma, verificación CMS independiente con OpenSSL, compilación release y comprobación de proveedores criptográficos en el DEX final. El build requiere todos los pasos aprobados antes de entregar una nueva APK.

La instalación/actualización y el uso con datos reales también requieren comprobación en el dispositivo. Mantener respaldos externos verificables y los procedimientos de confidencialidad/conservación del consultorio. La app ofrece apoyo documental; no sustituye la revisión clínica ni se presenta como sistema NOM-024 certificado.
