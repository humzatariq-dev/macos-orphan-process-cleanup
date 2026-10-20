#!/usr/bin/env python3
"""Generate synthetic launch assets; no live collection or cleanup, no packages."""
import html
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='orphan-demo-') as tmp:
    env = dict(os.environ, HOME=tmp, LOGFILE=tmp + '/cleanup.log',
               SIGNAL_RECORDER=tmp + '/signals', SCENARIO='')
    Path(env['SIGNAL_RECORDER']).write_text('')
    result = subprocess.run(['/bin/bash', str(ROOT / 'tests/cli_fixture.sh'), 'scan'],
                            env=env, text=True, capture_output=True, check=True)
    assert not Path(env['SIGNAL_RECORDER']).read_text()
    assert not Path(env['LOGFILE']).exists()
    assert 'SECRET_TOKEN' not in result.stdout
output = result.stdout
lines = ['SYNTHETIC DEMO | no live processes | scan only', '', '$ ./orphan-cleanup scan']
lines.extend(output.replace('\t', '  ').splitlines())
lines.extend(['', 'A match is not proof of inactivity. Chrome stays report-only.'])
assets = ROOT / 'docs/assets'
assets.mkdir(exist_ok=True)
svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="340" viewBox="0 0 1100 340" role="img" aria-labelledby="title desc">',
       '<title id="title">Synthetic read-only process scan</title>',
       '<desc id="desc">Two synthetic Godot candidates for review and one report-only Chrome match. No processes terminated. RSS is not measured RAM freed.</desc>',
       '<rect width="1100" height="340" rx="12" fill="#111827"/>',
       '<g font-family="monospace" font-size="14" fill="#e5e7eb">']
for i, line in enumerate(lines):
    svg.append(f'<text x="24" y="{32 + i * 24}">{html.escape(line)}</text>')
svg.extend(['</g>', '</svg>'])
(assets / 'scan-demo.svg').write_text('\n'.join(svg) + '\n')
header = {'version': 2, 'width': 120, 'height': 16, 'title': 'Synthetic read-only scan — no live processes',
          'env': {'TERM': 'xterm-256color'}}
events = [[0.0, 'o', 'SYNTHETIC DEMO | no live processes | scan only\r\n\r\n$ '],
          [0.8, 'o', './orphan-cleanup scan'], [2.0, 'o', '\r\n'],
          [2.3, 'o', output.replace('\n', '\r\n')],
          [6.0, 'o', '\r\nA match is not proof of inactivity. Chrome stays report-only.\r\n'],
          [9.0, 'o', '\r\n$ ']]
(assets / 'scan-demo.cast').write_text('\n'.join(json.dumps(item, ensure_ascii=False) for item in [header, *events]) + '\n')
print('Generated synthetic SVG preview and asciicast v2 recording; no signals/logs.')
