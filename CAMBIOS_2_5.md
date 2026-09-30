# Cambios 2.5

- Fecha de nacimiento: entrada DD/MM/AAAA y calendario que abre directamente la selección de año. Se conserva el formato ISO en la base y se rechazan fechas imposibles o futuras. Aplica a creación y edición de paciente.
- Importación de certificado público .cer DER/PEM al perfil: lectura de nombre, RFC disponible, emisor, número de serie, fechas y huella SHA-256. Confirmación antes de sustituir campos, guardado al confirmar perfil. La cédula, especialidad y establecimiento siguen siendo captura aparte.
- No se solicita ni almacena clave privada o contraseña. Este módulo no firma notas ni PDF, no verifica cadena de confianza, revocación ni identidad del titular. Las fechas se comparan únicamente con el reloj del dispositivo. Firmar electrónicamente documentos sigue pendiente de desarrollo y validación.
- Quitar certificado elimina sus metadatos del perfil al guardar; nombre y RFC importados permanecen editables. Las notas anteriores conservan su instantánea.
- Actualización compatible con la edición comunidad 2.4 y su firma estable. Respaldar antes de instalar.
