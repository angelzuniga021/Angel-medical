"""Ensure R8 preserves actual JCA provider implementations in the release DEX."""
from pathlib import Path
import struct
import zipfile

def u32(data, offset):
    return struct.unpack_from('<I', data, offset)[0]

def classes(data):
    if not data.startswith(b'dex\n'):
        raise ValueError('Unsupported DEX format')
    strings_off = u32(data, 60)
    types_off = u32(data, 68)
    count, offset = u32(data, 96), u32(data, 100)
    for index in range(count):
        class_type = u32(data, offset + index * 32)
        descriptor_index = u32(data, types_off + class_type * 4)
        start = u32(data, strings_off + descriptor_index * 4)
        while data[start] & 128:
            start += 1
        start += 1  # skip ULEB128 UTF-16 length; descriptors below are ASCII
        end = data.index(0, start)
        yield data[start:end].decode('utf-8')

apk = Path('build/app/outputs/flutter-apk/app-release.apk')
with zipfile.ZipFile(apk) as archive:
    present = set()
    for name in archive.namelist():
        if name.startswith('classes') and name.endswith('.dex'):
            present.update(classes(archive.read(name)))
required = {
    'Lorg/bouncycastle/jcajce/provider/asymmetric/RSA$Mappings;',
    'Lorg/bouncycastle/jcajce/provider/asymmetric/rsa/DigestSignatureSpi$SHA256;',
    'Lorg/bouncycastle/jcajce/provider/asymmetric/rsa/KeyFactorySpi;',
    'Lorg/bouncycastle/jcajce/provider/symmetric/AES$Mappings;',
    'Lorg/bouncycastle/jcajce/provider/symmetric/PBEPBKDF2$Mappings;',
}
missing = required - present
assert not missing, f'JCA implementations absent or renamed by R8: {sorted(missing)}'
print('PASS: release DEX retains JCA RSA/SHA-256, AES and PBKDF2 provider classes.')
