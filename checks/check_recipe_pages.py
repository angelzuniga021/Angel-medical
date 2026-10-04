"""Independent rendered-PDF check: medication and its directions stay together."""
import re
import subprocess
text = subprocess.check_output(['pdftotext', '-layout', 'recipe-fixture/long.pdf', '-'], text=True)
pages = text.split('\f')
for i in range(1, 31):
    marker = f'{i}. Medicamento de prueba {i}'
    matches = [p for p in pages if re.search(rf'(?m)^\s*{re.escape(marker)}\s*$', p)]
    assert len(matches) == 1, f'Missing/duplicated medication {i}'
    block = matches[0].split(marker, 1)[1].split('Medicamento de prueba', 1)[0]
    assert 'Dosis: Una unidad' in block and 'Texto de prueba sin validez' in block, f'Medication {i} split across pages'
print('PASS: 30 medications retain their dose and directions on the same page.')
