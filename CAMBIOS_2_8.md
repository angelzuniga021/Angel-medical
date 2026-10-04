# Angel Medical 2.8.0

- Mapa corporal anterior/posterior en consultas, urgencias, hospitalización y evolución. Permite varias regiones, intensidad opcional 0–10 y descripción. La lateralidad es la del paciente. Sin selección no equivale a dolor negado. Se conserva en `nom_json`, aparece como texto en revisión/PDF y como mapa en el detalle. No propone diagnósticos.
- Firma criptográfica local del PDF con certificado `.cer` y clave RSA `.key` DER PKCS#8 cifrada (mínimo 2048 bits). RFC del certificado debe coincidir con el perfil. Verifica correspondencia clave/certificado, fechas locales y firma matemática. Dos firmas CMS separadas protegen el PDF y el manifiesto que lo vincula a la versión de la nota. No es una firma PAdES incrustada en el PDF.
- La firma se guarda como adjunto en la base cifrada y entra en respaldos existentes. No cambia autor ni fecha original. Una corrección conserva la firma previa y la identifica como versión anterior. La fecha de firma usa el reloj del dispositivo.
- Revisión normativa con alcance y pendientes explícitos: no constituye certificación, dictamen jurídico ni validación completa de NOM-024.
- Exportación lógica cifrada `.amx` para preparar un futuro lector en PC. Se comparte con el selector del sistema, incluido Drive cuando esté disponible. No existe todavía app de PC ni sincronización automática. El respaldo restaurable sigue siendo `.ambak`.

## Uso

1. Antes de actualizar, generar un respaldo `.ambak` y guardarlo fuera del teléfono. Instalar la misma edición comunidad encima de la existente, sin desinstalar.
2. En una nota, seleccionar **Marcar dolor en el cuerpo**, señalar regiones y guardar el mapa antes de finalizar.
3. Para firmar: guardar RFC propio en Perfil; abrir detalle de una nota y **Firmar esta versión**. Seleccionar `.cer`, `.key` cifrada y contraseña local. Nunca subir clave ni contraseña a GitHub, chats o Drive como parte de una exportación.
4. **Exportar PDF y firmas** entrega ZIP con PDF exacto, firmas `.p7s`, manifiesto y certificado público. Conservar el conjunto, no modificar el PDF.
5. En Herramientas revisar **Revisión normativa** y **Preparar PC y Drive**.

## Límites de la firma

No verifica cadena de confianza SAT, revocación OCSP/CRL ni sello de tiempo confiable. No garantiza reconocimiento jurídico de un expediente concreto. El certificado debe ser el de firma y no un certificado de sello digital. La app no valida todavía todos los perfiles de certificado SAT. Se probaron certificados ficticios generados en CI; falta prueba funcional con un certificado SAT real manejado exclusivamente por su titular.

La app no persiste la clave privada ni contraseña en la base. Borra buffers controlados y solicita limpieza de caché del selector, con mejor esfuerzo. El puente de plataforma, cadenas en memoria y cachés del sistema impiden prometer eliminación absoluta de toda copia temporal. No se registran datos de la clave en logs.

## Validación

Pruebas de migración aditiva, conservación de datos y adjuntos, catálogo/favoritos, mapa/lateralidad, interfaz estrecha con texto ampliado, huella de versión y exportación binaria. Pruebas Java: firma correcta, datos alterados, contraseña incorrecta, clave ajena y certificado caducado. OpenSSL verifica de forma independiente CMS y rechaza contenido alterado; `-noverify` no comprueba confianza de certificado.
