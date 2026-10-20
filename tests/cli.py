"""Development-only CLI/PTY regression suite. Never signals real processes."""
import errno
import os
from pathlib import Path
import pty
import select
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
count = 0
with tempfile.TemporaryDirectory(prefix='orphan cli ') as tmp:
    env = dict(os.environ, HOME=tmp, LOGFILE=tmp + '/cleanup.log', SIGNAL_RECORDER=tmp + '/signals')
    recorder = Path(env['SIGNAL_RECORDER'])

    def run(args, code=0, signals='', scenario='', terminal=False, reply=b'yes\n'):
        global count
        recorder.write_text('')
        Path(str(recorder) + '.change').unlink(missing_ok=True)
        command = ['/bin/bash', str(ROOT / 'tests/cli_fixture.sh'), *args]
        e = dict(env, SCENARIO=scenario)
        if terminal:
            master, slave = pty.openpty()
            p = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=e)
            os.close(slave)
            output = b''
            sent = False
            deadline = time.monotonic() + 10
            try:
                while True:
                    if time.monotonic() > deadline:
                        p.kill()
                        raise AssertionError('PTY timeout')
                    if select.select([master], [], [], .1)[0]:
                        try:
                            data = os.read(master, 65536)
                        except OSError as ex:
                            if ex.errno == errno.EIO:
                                break
                            raise
                        if not data:
                            break
                        output += data
                        if b"Type exactly 'yes':" in output and not sent:
                            if scenario == 'prompt_change':
                                Path(str(recorder) + '.change').touch()
                            os.write(master, reply)
                            sent = True
                    elif p.poll() is not None:
                        break
                rc = p.wait(timeout=2)
            finally:
                os.close(master)
                if p.poll() is None:
                    p.kill()
                    p.wait()
            text = output.decode(errors='replace')
        else:
            result = subprocess.run(command, input='yes\n', text=True, capture_output=True, env=e, timeout=10)
            rc, text = result.returncode, result.stdout + result.stderr
        assert rc == code, (args, scenario, rc, code, text)
        assert recorder.read_text() == signals, (args, 'unexpected signals', recorder.read_text())
        count += 1
        return text

    for args in ([], ['scan'], ['-n'], ['--dry-run'], ['--help'], ['--version']):
        run(args)
    assert not Path(env['LOGFILE']).exists()
    normal = run(['scan'])
    assert 'SECRET_TOKEN' not in normal and 'STATUS' in normal and 'ambiguous_command' in normal
    assert 'SECRET_TOKEN' in run(['scan', '--verbose'])
    assert 'headless-chrome' not in run(['scan', '--profile', 'godot-mcp'])
    assert 'No matches found.' in run(['scan'], scenario='empty')
    header = 'PID\tPROFILE\tAGE\tRSS_KiB\tPPID\tSTATUS\tREASON\n'
    rows = ''.join(f'{pid}\tgodot-mcp\t03:00:00\t1024\t1\treview\teligible\n' for pid in (100, 101))
    chrome = '102\theadless-chrome\t03:00:00\t2048\t1\tkeep\tambiguous_command\n'
    def footer(n, rss):
        return f'Candidates: {n}; estimated candidate RSS: {rss} KiB (not measured RAM freed).\nNo processes terminated.\n'
    assert normal == header + rows + chrome + footer(2, 2048)
    assert run(['scan', '--profile', 'godot-mcp']) == header + rows + footer(2, 2048)
    assert run(['scan'], scenario='empty') == header + 'No matches found.\n' + footer(0, 0)
    verbose = header
    for pid in (100, 101):
        verbose += f'{pid}\tgodot-mcp\t03:00:00\t1024\t1\treview\teligible\n  command: /usr/bin/node /tmp/godot-mcp/build/index.js\n'
    verbose += chrome + '  command: /Applications/Google Chrome --headless=new SECRET_TOKEN\n' + footer(2, 2048)
    assert run(['scan', '--verbose']) == verbose + 'Warning: full command lines may contain secrets.\n'
    clean = ['clean', '--profile', 'godot-mcp', '--pid', '100']
    for args in ([*clean, '--yes'], [*clean, '--pid', '101', '--yes']):
        output = run(args, signals='100\n' + ('101\n' if '101' in args else ''))
        assert output.index('Selected cleanup preview') < output.index('confirmed_exit')
    run(clean, code=2)  # Piped 'yes' is not terminal consent.
    for reply in (b'no\n', b'\n', b'YES\n', b'\x04'):
        assert 'Cancelled.' in run(clean, terminal=True, reply=reply)
    run(clean, terminal=True, signals='100\n')
    run([*clean, '--pid', '101'], code=1, scenario='prompt_change', terminal=True)
    run([*clean, '--yes'], code=1, scenario='changed')
    run([*clean, '--yes'], code=2, scenario='root')
    run([*clean, '--yes'], code=1, scenario='collection_error')
    run([*clean, '--pid', '999', '--yes'], code=1)
    run([*clean, '--pid', '102', '--yes'], code=1)
    run(['clean', '--profile', 'godot-mcp', '--pid', '102', '--pid', '100', '--yes'], code=1)
    run(['clean', '--profile', 'headless-chrome', '--pid', '102', '--yes'], code=1)
    run(['clean', '--profile', 'godot-mcp', '--pid', '102', '--yes'], code=1)
    bad = [
        ['3'], ['clean'], ['--pid', '100'], ['--yes'], ['scan', 'clean'],
        [*clean, '-n'], [*clean, '--verbose'], [*clean, '--pid', '00100'],
        ['--profile', 'unity-batch'], ['--profile', 'bad'], ['--profile'],
        ['--min-age-hours'], ['--min-age-hours', '0'], ['--min-age-hours', '-1'],
        ['--min-age-hours', '1.2'], ['--min-age-hours', '8761'],
        ['--min-age-hours', '3', '--min-age-hours', '4'], ['--bad'],
        [*clean, '--pid', '1'], [*clean, '--pid', 'abc'], [*clean, '--pid'],
        ['clean', '--profile', 'unity-batch', '--pid', '100', '--yes'],
    ]
    for args in bad:
        run(args, code=2)
    for age in ('1', '0003', '8760'):
        run(['--min-age-hours', age])
    # Both real entrypoints, including a checkout path containing spaces. Only
    # safe invocations execute here; fixture harness covers destructive flows.
    import shutil
    copy = Path(tmp) / 'checkout with spaces'
    copy.mkdir()
    shutil.copytree(ROOT / 'lib', copy / 'lib')
    for name in ('orphan-cleanup', 'cleanup_orphan_processes.sh'):
        shutil.copy2(ROOT / name, copy / name)
    for name in ('orphan-cleanup', 'cleanup_orphan_processes.sh'):
        for args, expected in ((['--help'], 0), (['--version'], 0), (['3'], 2), (['clean'], 2)):
            r = subprocess.run(['/bin/bash', str(copy / name), *args], env=env, capture_output=True, timeout=10)
            assert r.returncode == expected, (name, args, r.stderr)
            count += 1
    # Real entrypoint parity with synthetic OS collection. Selected fake PIDs
    # disappear during preflight, so production kill is never reached.
    fakebin = Path(tmp) / 'bin'
    fakebin.mkdir()
    programs = {
        'id': '#!/bin/sh\necho 501\n',
        'uname': '#!/bin/sh\necho Darwin\n',
        'ps': """#!/bin/sh
if [ "$1" = -p ]; then echo 1; exit 0; fi
if [ -e "$PS_MARKER" ]; then exit 0; fi
touch "$PS_MARKER"
printf '%s\n' '999999991 501 1 Mon Oct 19 12:00:00 2026 03:00:00 1024 /usr/bin/node /usr/bin/node /tmp/godot-mcp/build/index.js'
""",
    }
    for name, content in programs.items():
        target = fakebin / name
        target.write_text(content)
        target.chmod(0o755)
    e = dict(env, PATH=str(fakebin) + ':' + env['PATH'], PS_MARKER=tmp + '/ps-marker')
    for name in ('orphan-cleanup', 'cleanup_orphan_processes.sh'):
        for args in ([], ['scan'], ['--dry-run'], ['-n'],
                     ['clean', '--profile', 'godot-mcp', '--pid', '999999991', '--yes']):
            Path(e['PS_MARKER']).unlink(missing_ok=True)
            r = subprocess.run(['/bin/bash', str(copy / name), *args], env=e, capture_output=True, text=True, timeout=10)
            assert r.returncode == 0, (name, args, r.stdout, r.stderr)
            assert ('disappeared_before_signal' if 'clean' in args else 'Candidates: 1') in r.stdout
            count += 1
    assert 'SECRET_TOKEN' not in Path(env['LOGFILE']).read_text()
print(f'PASS: {count} CLI/PTY cases; synthetic data and recorded signals only.')
