# Ángel Medical 2.8.1 — diagnóstico de vigencia al firmar

El aviso genérico de certificado fuera de vigencia no permitía saber qué fecha estaba causando el bloqueo. Esta versión muestra inicio, vencimiento y reloj del teléfono con fecha/hora UTC explícita, distingue certificado vencido de uno cuyo periodo aún no inicia, y añade **Revisar vigencia del .cer** en el panel de firma. El Perfil mantiene visibles las fechas del certificado importado.

La captura de recetas añade **Guardar y revisar / firmar**, que abre la receta ya guardada y su panel de firma, sin crear una segunda copia. Se conserva la opción de impresión.

Se corrigen textos antiguos del Perfil que decían que la versión no podía firmar. Importar el certificado sólo carga datos públicos; firmar es una acción separada desde el detalle de notas/recetas guardadas.

No se modifica la vigencia, no se permite firmar con certificado vencido y no se atribuye el bloqueo a una avería confirmada del motor criptográfico. Para identificar la causa concreta se necesita comparar las fechas del certificado del titular y el reloj de su teléfono. Si renovó su e.firma, debe seleccionar el certificado vigente y su clave correspondiente. Las claves privadas y contraseñas nunca se solicitan por chat.

Pruebas de lectura DER, extremos inclusivos del periodo, equivalencia entre UTC y desplazamiento UTC-05:00, caducidad y periodo futuro. No cambian esquema de base, datos clínicos ni firmas ya guardadas.
