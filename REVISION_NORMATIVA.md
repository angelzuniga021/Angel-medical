# Revisión técnica normativa — 2.8

Revisión del 4 de octubre de 2026. La aplicación muestra apoyos de captura y trazabilidad; no se presenta como certificada ni garantiza cumplimiento por instalarla. La práctica, infraestructura y documentación del consultorio también requieren revisión.

| Referencia | Implementación y límites |
|---|---|
| NOM-004, 5.2, 5.10 y apartados de notas | Campos de paciente/establecimiento/autor, fecha y requisitos según tipo. Datos incompletos bloquean finalización en flujos guiados; registros históricos no se atribuyen artificialmente. |
| NOM-004, 5.4–5.7 | Base y respaldos cifrados, bloqueo local y conservación del historial. Conservación mínima de cinco años desde el último acto médico requiere política y operación del titular. Confidencialidad no se resuelve sólo con cifrado. |
| NOM-004, 5.10–5.12 | Firma CMS local opcional sobre PDF exacto y manifiesto de versión. Autor original y fecha de atención se conservan. Falta validación completa de confianza y revocación para afirmar firma avanzada confiable. |
| NOM-024, 5 y 6.6 | Integridad y exportación cifrada parciales. Pendientes: autorización por roles, auditoría de accesos completa, políticas y pruebas de disponibilidad, controles de interoperabilidad. |
| NOM-024, 6.1–6.6 y 7 | AMX no es una implementación certificada de intercambio. Deben implementarse guías DGIS aplicables y completar evaluación externa y proceso de certificación. |

Fuentes oficiales consultadas:
- NOM-004-SSA3-2012: https://sidof.segob.gob.mx/notas/docFuente/5272787
- NOM-024-SSA3-2012: https://sidof.segob.gob.mx/notas/docFuente/5280847
- DGIS, certificación: https://www.dgis.salud.gob.mx/contenidos/intercambio/certificacion-nom-024-ssa3-2012.html

Antes de ofrecerla como sistema certificado, resolver controles pendientes, comprobar requisitos aplicables al uso previsto y tramitar evaluación correspondiente. Este documento es revisión técnica del producto, no un dictamen.
