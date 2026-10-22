#!/usr/bin/env python3
"""Create local configuration/secrets without replacing existing values."""
from pathlib import Path
import os
import secrets
root = Path(__file__).resolve().parents[2]
os.chdir(root)
env = root / 'srcs/.env'
if not env.exists():
    env.write_text((root / 'srcs/.env.example').read_text())
folder = root / 'secrets'
folder.mkdir(exist_ok=True, mode=0o700)
for name, count in [('db_password', 1), ('db_root_password', 1), ('credentials', 2)]:
    path = folder / (name + '.txt')
    try:
        with open(path, 'x', opener=lambda p, f: os.open(p, f, 0o600)) as f:
            f.write(''.join(secrets.token_hex(32) + '\n' for _ in range(count)))
    except FileExistsError:
        pass
print('Configuration prête. Adapter srcs/.env, puis configurer le data-root Docker selon DEV_DOC.md sur la VM Linux.')
