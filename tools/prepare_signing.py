"""Require a stable private key for signed builds. Never print credentials."""
import base64, os, json
from pathlib import Path
mode = os.environ['ANGEL_MODE']
ids = {'pruebas': 'com.drangelzuniga.angel_medical_mobile.preview',
       'comunidad': 'com.drangelzuniga.angel_medical_mobile.community',
       'personal': 'com.drangelzuniga.angel_medical_mobile'}
if mode not in ids:
    raise SystemExit('Unknown build mode')
values = {'ANGEL_APPLICATION_ID': ids[mode],
          'ANGEL_COMMUNITY': 'false' if mode == 'personal' else 'true'}
if mode != 'pruebas':
    raw = os.environ.get('ANGEL_SIGNING_JSON', '')
    if raw:
        try:
            data = json.loads(raw)
            for name in ['ANGEL_KEYSTORE_B64', 'ANGEL_STORE_PASSWORD', 'ANGEL_KEY_ALIAS', 'ANGEL_KEY_PASSWORD']:
                value = data[name]
                if not isinstance(value, str) or not value or '\n' in value or '\r' in value:
                    raise ValueError()
                os.environ[name] = value
        except (ValueError, KeyError, TypeError):
            raise SystemExit('Invalid signing JSON; credentials were not printed')
    required = ['ANGEL_KEYSTORE_B64' , 'ANGEL_STORE_PASSWORD', 'ANGEL_KEY_ALIAS', 'ANGEL_KEY_PASSWORD']
    if any(not os.environ.get(k) for k in required):
        raise SystemExit('Missing signing secrets in the selected GitHub environment; build stopped')
    for name in ['ANGEL_STORE_PASSWORD', 'ANGEL_KEY_PASSWORD']:
        print('::add-mask::' + os.environ[name])
    key = Path(os.environ['RUNNER_TEMP']) / 'angel-release.jks'
    key.write_bytes(base64.b64decode(os.environ['ANGEL_KEYSTORE_B64'], validate=True))
    key.chmod(0o600)
    values['ANGEL_KEYSTORE_PATH'] = str(key)
    for name in ['ANGEL_STORE_PASSWORD', 'ANGEL_KEY_ALIAS', 'ANGEL_KEY_PASSWORD']:
        values[name] = os.environ[name]
with open(os.environ['GITHUB_ENV'], 'a') as output:
    for key, value in values.items():
        output.write(f'{key}={value}\n')
