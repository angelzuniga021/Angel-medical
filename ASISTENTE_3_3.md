# Asistente de consulta · Android 3.3.0 / PC 1.1.0

Abra una consulta, urgencia o evolución SOAP y pulse el icono de destellos de la barra superior.

- Redactar: capture un resumen, use dictado o coloque texto manualmente sin IA. En Android el dictado depende del reconocimiento en español del sistema, permiso de micrófono y puede usar internet; no es grabación continua. En Windows use el campo de texto con Windows+H (requiere reconocimiento de voz habilitado).
- IA opcional: configure URL completa de un servicio Chat Completions compatible, modelo y clave en el engrane. No se incluye suscripción ni modelo. Clave/configuración se guardan mediante almacenamiento seguro por equipo; no se incluyen en `.ambak`. No use su e.firma como credencial de IA.
- Antes de cada petición se presenta todo el contenido editable que se enviará y el destino. No se añade automáticamente el perfil/historial. El texto libre puede contener identificadores: revíselo. El servicio elegido tiene sus propias condiciones y costos.
- Solo HTTPS remoto. PC admite Ollama en localhost; requiere instalar motor y descargar un modelo previamente. El servidor se configura con URL completa `http://localhost:11434/v1/chat/completions` y nombre de modelo instalado. No hay instalación silenciosa de modelos.
- La salida es un borrador, nunca una indicación automática. Cada campo se selecciona, edita y confirma. Aplicar reemplaza los campos seleccionados previa confirmación y regresa al editor habitual; allí se conserva el flujo de guardar/revisar/firmar. La IA no puede rellenar mediciones ni identificadores mediante su respuesta estructurada.
- CIE-10: búsqueda precargada con el diagnóstico documentado, selección local de catálogo; no diagnóstico automático.
- Expediente: resumen documental local del perfil y las últimas 20 consultas anteriores a la fecha actual; cada consulta conserva fecha y número de referencia. Alcance indicado explícitamente; no incluye hospitalizaciones, documentos ni adjuntos.
- Comparación: consulta anterior frente al borrador actual, cambios numéricos y mapas corporales. Campos vacíos no significan normalidad ni mejoría. Propuestas pendientes de aplicar no se incluyen en comparación.
- Mapa corporal: función existente integrada al asistente; lateralidad del paciente, vista anterior/posterior e intensidad.

## Validación y límites
Pruebas automatizadas de restricción de campos, transporte HTTP con servidor ficticio, errores, minimización de contexto y comparación. El funcionamiento con un proveedor real depende de sus credenciales, modelo y servicio; no se han usado expedientes reales para pruebas. El modelo puede equivocarse aunque respete el formato; revisión médica obligatoria.

No se cambia el esquema 7 ni el formato `.ambak`, las rutas de base ni las claves de cifrado. Restaurar continúa reemplazando la base; no combina ediciones entre dispositivos. El asistente no certifica cumplimiento NOM ni firma por cuenta del médico.
