# Ángel Medical 2.9.2

Corrige CMS no válido al integrar firmas Android. Bouncy Castle emitía BER con longitud indefinida, válido para CMS separado; el extractor PDF requiere una secuencia DER con longitud definida. El firmador nativo ahora emite DER explícito. Se mantienen intactos los documentos y firmas anteriores.

Prueba cruzada: Flutter genera un PDF provisional y su ByteRange; Java LocalSigner firma esos mismos bytes con un certificado y clave ficticios; Flutter integra el CMS nativo, lo extrae y verifica con OpenSSL. Poppler confirma la firma PDF. Se comprueba rechazo de contenido alterado y la codificación DER canónica en Java. Nunca se usa la clave real de un usuario en pruebas.
