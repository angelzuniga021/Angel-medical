import 'dart:convert';
import 'dart:typed_data';

class DerNode {
  final int tag;
  final Uint8List data;
  DerNode(this.tag, this.data);
  List<DerNode> get children {
    final out = <DerNode>[];
    var offset = 0;
    while (offset < data.length) {
      final tag = data[offset++];
      if ((tag & 31) == 31 || offset >= data.length)
        throw const FormatException('DER inválido');
      var length = data[offset++];
      if (length & 128 != 0) {
        final count = length & 127;
        if (count == 0 || count > 4 || offset + count > data.length)
          throw const FormatException('Longitud DER inválida');
        length = 0;
        for (var i = 0; i < count; i++) {
          length = length * 256 + data[offset++];
        }
      }
      if (length > data.length - offset)
        throw const FormatException('Certificado truncado');
      out.add(
        DerNode(tag, Uint8List.sublistView(data, offset, offset + length)),
      );
      offset += length;
      if (out.length > 1000)
        throw const FormatException('Certificado demasiado complejo');
    }
    return out;
  }

  String get stringValue {
    if (tag == 12) return utf8.decode(data);
    if ([19, 20, 22].contains(tag)) return latin1.decode(data);
    if (tag == 30 && data.length.isEven) {
      return String.fromCharCodes([
        for (var i = 0; i < data.length; i += 2) data[i] * 256 + data[i + 1],
      ]);
    }
    throw const FormatException('Texto del certificado no compatible');
  }
}

class CertificateProfile {
  final String name, rfc, issuer, serial;
  final DateTime notBefore, notAfter;
  final Uint8List bytes;
  CertificateProfile(
    this.name,
    this.rfc,
    this.issuer,
    this.serial,
    this.notBefore,
    this.notAfter,
    this.bytes,
  );
  bool validAt(DateTime now) =>
      !now.toUtc().isBefore(notBefore) && !now.toUtc().isAfter(notAfter);
}

String certificateDateDisplay(DateTime value) {
  final d = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)} UTC';
}

String certificateDateStatus(DateTime start, DateTime end, DateTime now) {
  if (now.toUtc().isBefore(start.toUtc())) return 'La vigencia aún no inicia';
  if (now.toUtc().isAfter(end.toUtc())) return 'Certificado vencido';
  return 'Dentro del periodo de vigencia';
}

String certificateValidityDetails(DateTime start, DateTime end, DateTime now) =>
    '${certificateDateStatus(start, end, now)}\n'
    'Inicio: ${certificateDateDisplay(start)}\n'
    'Vencimiento: ${certificateDateDisplay(end)}\n'
    'Reloj del teléfono: ${certificateDateDisplay(now)}\n\n'
    'Todas las fechas se muestran en UTC para compararlas. Si el reloj está incorrecto, activa fecha y hora automáticas en Ajustes del teléfono. '
    'Si el reloj es correcto y el certificado venció, selecciona el .cer vigente y su .key correspondiente. '
    'Si no tienes un certificado vigente, debes renovarlo ante el SAT. No cambies la fecha para eludir la vigencia. '
    'Este diagnóstico revisa fechas; no verifica confianza SAT ni revocación.';

Map<int, String> _name(DerNode node) {
  if (node.tag != 48) throw const FormatException('Nombre X.509 inválido');
  final out = <int, String>{};
  for (final set in node.children) {
    if (set.tag != 49) throw const FormatException('Atributo X.509 inválido');
    for (final attribute in set.children) {
      final pair = attribute.children;
      if (attribute.tag != 48 || pair.length != 2 || pair[0].tag != 6)
        throw const FormatException('Atributo X.509 inválido');
      final oid = pair[0].data;
      if (oid.length == 3 && oid[0] == 85 && oid[1] == 4)
        out[oid[2]] = pair[1].stringValue.trim();
    }
  }
  return out;
}

DateTime _time(DerNode node) {
  final text = ascii.decode(node.data);
  final isUtc = node.tag == 23;
  if ((!isUtc && node.tag != 24) ||
      !RegExp(isUtc ? r'^\d{12}Z$' : r'^\d{14}Z$').hasMatch(text))
    throw const FormatException('Vigencia X.509 no compatible');
  final offset = isUtc ? 2 : 4;
  var year = int.parse(text.substring(0, offset));
  if (isUtc) year += year >= 50 ? 1900 : 2000;
  final values = [
    for (var i = offset; i < text.length - 1; i += 2)
      int.parse(text.substring(i, i + 2)),
  ];
  final d = DateTime.utc(
    year,
    values[0],
    values[1],
    values[2],
    values[3],
    values[4],
  );
  if (d.year != year ||
      d.month != values[0] ||
      d.day != values[1] ||
      d.hour != values[2] ||
      d.minute != values[3] ||
      d.second != values[4])
    throw const FormatException('Vigencia inválida');
  return d;
}

CertificateProfile readCertificate(Uint8List input) {
  if (input.isEmpty || input.length > 128 * 1024)
    throw const FormatException('Usa un certificado .cer de hasta 128 KB');
  var bytes = input;
  if (input[0] == 45) {
    final pem = ascii.decode(input).trim();
    final match = RegExp(
      r'^-----BEGIN CERTIFICATE-----\s+([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----$',
    ).firstMatch(pem);
    if (match == null)
      throw const FormatException('PEM de certificado inválido');
    bytes = base64Decode(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
  }
  final roots = DerNode(0, bytes).children;
  if (roots.length != 1 || roots.single.tag != 48)
    throw const FormatException('El archivo no es un certificado X.509');
  final cert = roots.single.children;
  if (cert.length != 3 ||
      cert[0].tag != 48 ||
      cert[1].tag != 48 ||
      cert[2].tag != 3 ||
      cert[2].data.isEmpty)
    throw const FormatException('Estructura de certificado inválida');
  final tbs = cert[0].children;
  final offset = tbs.isNotEmpty && tbs[0].tag == 160 ? 1 : 0;
  if (tbs.length < offset + 6 ||
      tbs[offset].tag != 2 ||
      tbs[offset + 1].tag != 48 ||
      tbs[offset + 3].tag != 48 ||
      tbs[offset + 5].tag != 48)
    throw const FormatException('Contenido de certificado inválido');
  final issuer = _name(tbs[offset + 2]);
  final subject = _name(tbs[offset + 4]);
  final validity = tbs[offset + 3].children;
  if (validity.length != 2) throw const FormatException('Vigencia inválida');
  final start = _time(validity[0]), end = _time(validity[1]);
  if (end.isBefore(start)) throw const FormatException('Vigencia inválida');
  final rfc =
      RegExp(r'(?:^|[\s/])([A-ZÑ&]{3,4}\d{6}[A-Z0-9]{3})(?:$|[\s/])')
          .firstMatch('${subject[45] ?? ''}'.toUpperCase())
          ?.group(1) ??
      '';
  final name = subject[41] ?? subject[3] ?? '';
  if (name.isEmpty)
    throw const FormatException('No se encontró nombre del titular');
  return CertificateProfile(
    name,
    rfc,
    issuer[3] ?? issuer[10] ?? '',
    tbs[offset].data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase(),
    start,
    end,
    bytes,
  );
}
