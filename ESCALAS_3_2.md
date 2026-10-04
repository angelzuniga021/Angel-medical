# Ampliación clínica 3.2

37 herramientas locales: 29 escalas y 8 calculadoras; además un acceso externo a PREVENT oficial. No es una integración de MDCalc ni un catálogo exhaustivo.

## Modelos añadidos

- NEWS2, RCP 2017: valores medidos RR, SpO2, PAS, pulso y temperatura; oxígeno suplementario y consciencia. Saturación escala 1 por defecto conceptual, sin respuesta seleccionada automáticamente. Escala 2 requiere confirmación explícita de hipercapnia por gasometría, objetivo prescrito 88–92% y decisión clínica documentada; EPOC por sí sola no basta. NEWS2 no se usa en menores de 16 ni embarazo. Se muestra puntaje por componente y alerta por cualquier componente de 3 puntos, aun con total <5.
- RCRI de Lee 1999: 6 factores de riesgo perioperatorio para cirugía no cardiaca; se conserva el criterio original de creatinina >2.0 mg/dL. No se asignan porcentajes de otras cohortes ni se autoriza cirugía automáticamente.
- Apgar: 5 componentes 0–2. El minuto de vida es obligatorio y no suma puntos. Cada evaluación registra el minuto y las intervenciones en observaciones. No retrasar reanimación para calcular; no diagnostica asfixia ni pronóstico neurológico individual. Comparar el mismo minuto de vida.
- Rockall completo 1996: los 5 componentes son obligatorios, incluyendo diagnóstico y estigmas endoscópicos. No es preendoscópico y no permite sustituir datos ausentes por cero. Rango 0–11; no autoriza alta por sí solo.

## Fuentes y permisos

- NEWS2: https://www.rcp.ac.uk/resources/national-early-warning-score-news-2/
- Tabla original de puntuación en color, sin modificaciones: https://www.rcp.ac.uk/media/alxev00t/news2-chart-1_the-news-scoring-system_0_0.pdf
- Implementación escala 2: https://www.rcp.ac.uk/media/umzn4ntq/news2_additional-guidance-002-_0.pdf
- RCRI original: https://pubmed.ncbi.nlm.nih.gov/10477528/
- Apgar ACOG/AAP: https://www.acog.org/clinical/clinical-guidance/committee-opinion/articles/2015/10/the-apgar-score
- Rockall original: https://pubmed.ncbi.nlm.nih.gov/8675081/
- Tabla clínica Rockall: https://www.nice.org.uk/guidance/cg141/evidence/full-guideline-pdf-186534541

El RCP permite reproducir NEWS2 conservando criterios y atribución; las tablas originales deben mantenerse en color y sin modificación. Esta aplicación emplea formularios de captura y cálculo, con vínculo al original, sin reproducir una tabla recoloreada. Se incluye en pantalla y en cada resumen el aviso de traducción exigido: “The wording of this translation has not been specifically approved by the Royal College of Physicians – please refer to the English language version before making any clinical use of this information.” Atribución: Royal College of Physicians, NEWS2, updated working party report, London, 2017.

## PREVENT

El acceso abre el sitio oficial en el navegador, con internet. No envía datos del paciente, ejecuta ecuaciones PREVENT, registra resultados ni acepta contratos. La integración sin internet sigue pendiente de que el titular revise y acepte el acuerdo AHA y obtenga acceso al código oficial; después deberán validarse resultados y condiciones de distribución.

- Calculadora: https://professional.heart.org/en/guidelines-and-statements/prevent-calculator
- Acuerdo: https://form.jotform.com/240774577352161

No incorporar código obtenido indirectamente para eludir el acuerdo. No se presenta un enlace como integración local terminada.

AUDIT, Epworth, STOP-Bang y otros cuestionarios no se añaden en esta entrega mientras no se verifique la autorización aplicable al uso y distribución de la app.

## Preservación y pruebas

Sin cambio de esquema, identificador Android, firma de actualización ni ruta de base cifrada. Los registros anteriores conservan sus resúmenes y versiones. Pruebas de valores límite NEWS2, saturación en ambas escalas con/sin oxígeno, bloqueo de escala 2 sin confirmación, alerta por componente de 3 puntos, minuto Apgar no puntuable, máximos Rockall/RCRI/Apgar, datos incompletos/no finitos, pantalla estrecha con texto ampliado, PDF con desglose y aviso de traducción. Se mantienen todas las pruebas de migraciones, respaldos, recetas y firma criptográfica.
