# Ángel Medical 2.9.0

Receta unificada para impresión, firma e historial. Encabezado con logo del médico y logo del establecimiento, datos profesionales, paciente, fecha de nacimiento, fecha de emisión, medicamentos e indicaciones. Formato carta con paginación para tratamientos largos. No incluye signos vitales de consultas anteriores.

Recetas nuevas: CMS integrado en campo de firma PDF /adbe.pkcs7.detached, con ByteRange que cubre todo el archivo salvo la reserva criptográfica. Verificación local de firma integrada y de la firma separada del paquete. Botón Compartir PDF firmado. QR con folio y huellas de registro/certificado: identifica referencias, no contiene nombre, diagnóstico ni tratamiento y no apunta a una página pública. El lector PDF debe soportar firmas digitales; un visor móvil simple puede no mostrarlas. Sin validación SAT, revocación, sello de tiempo confiable ni certificación NOM-024/PAdES-LT.

Los PDF ya firmados no se reconstruyen ni modifican. Para aplicar nuevo diseño a un documento existente hay que firmar nuevamente su versión: se conserva el original. El encabezado usa el perfil de la atención; para registros previos sin perfil se usa el perfil actual con aviso explícito. Los medicamentos estructurados se conservan en nom_json, sin migrar esquema. Tras corrección de texto que invalide esos datos, prevalece el contenido clínico corregido.

Pruebas: PDF simple y 30 medicamentos, CMS integrado real con certificado ficticio/OpenSSL, alteración rechazada, QR sin datos clínicos. Mantiene base y firma estable de instalación.
