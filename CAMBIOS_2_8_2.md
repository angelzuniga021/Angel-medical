# Ángel Medical 2.8.2 — resultado y diagnóstico de firma

Las capturas del usuario muestran certificado dentro de vigencia y varias firmas de la misma receta con integridad verificada. No demuestran qué falló en el último intento. Esta versión conserva todas esas firmas y permite exportar la versión ya verificada sin repetir la firma. Añadir otra firma sigue disponible como acción explícita.

- El diálogo posee y dispone su propio controlador de contraseña; el proceso de firma ya no modifica un controlador de una ruta cerrada.
- La limpieza de recursos es de mejor esfuerzo y no sustituye el resultado de una operación confirmada. Los buffers de clave usados por cada llamada son independientes del selector y se limpian después.
- Errores con etapa y código estable: apertura/descifrado de clave, fechas del certificado, correspondencia clave/certificado, firma del PDF/manifiesto, verificación y almacenamiento. No se muestran excepciones internas con contenido privado. KEY_DECRYPT_FAILED identifica fallo de descifrado, no prueba por sí solo contraseña incorrecta.
- La impresión utiliza los bytes del PDF firmado cuando existe una firma actual verificada; antes de imprimir comprueba nuevamente la firma y la versión del registro. La exportación conserva PDF y .p7s juntos.
- Se confirma una firma guardada y verificada y se recarga su estado después de un intento fallido. Si no se verifica una firma, no se presenta como válida.

Pruebas de controlador al aceptar/cancelar repetidamente, limpieza fallida tras éxito o fallo, mensajes sin contenido privado, errores nativos de contraseña/clave ajena/caducidad y comprobaciones existentes de CMS/DEX. No cambia esquema ni elimina firmas o registros. Sigue pendiente confirmar en el dispositivo la causa exacta de un intento fallido con el nuevo diagnóstico.
