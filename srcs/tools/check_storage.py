#!/usr/bin/env python3
"""Refuse a VM whose volumes would violate the subject's storage requirements."""
import json
from pathlib import Path
import re
import subprocess
import sys


def check(docker):
    root = Path(__file__).resolve().parents[2]
    compose = [docker, 'compose', '--env-file', 'srcs/.env', '-f', 'srcs/docker-compose.yml']
    def output(args):
        return subprocess.check_output(args, cwd=root, text=True).strip()
    env = dict(line.split('=', 1) for line in output(compose + ['config', '--environment']).splitlines() if '=' in line)
    login = env.get('LOGIN', '')
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', login):
        raise ValueError('Set LOGIN to your actual learner username in srcs/.env')
    expected = f'/home/{login}/data'
    if env.get('DATA_PATH') != expected:
        raise ValueError(f'DATA_PATH must be {expected}')
    config = json.loads(output(compose + ['config', '--format', 'json']))
    if config['services']['nginx']['environment']['DOMAIN_NAME'] != f'{login}.42.fr':
        raise ValueError('DOMAIN_NAME must be LOGIN.42.fr')
    actual = output([docker, 'info', '--format', '{{.DockerRootDir}}'])
    if actual.rstrip('/') != expected:
        raise ValueError(f'Docker data-root is {actual}; configure {expected} on the dedicated VM (DEV_DOC.md)')
    existing = output([docker, 'volume', 'ls', '--format', '{{.Name}}']).splitlines()
    for name in config['volumes']:
        if config['volumes'][name].get('driver_opts'):
            raise ValueError('Volume driver options are forbidden: use native named volumes')
        if name in existing:
            volume = json.loads(output([docker, 'volume', 'inspect', name]))[0]
            mount = volume['Mountpoint']
            if volume['Driver'] != 'local' or volume.get('Options') or not mount.startswith(expected + '/volumes/'):
                raise ValueError(f'{name} has incompatible storage: back it up and migrate it before starting')
    print(f'Storage preflight passed: native named volumes under {expected}/volumes/')


if __name__ == '__main__':
    try:
        check(sys.argv[1] if len(sys.argv) > 1 else 'docker')
    except (ValueError, subprocess.CalledProcessError, FileNotFoundError) as exc:
        sys.exit(f'Storage preflight failed: {exc}')
