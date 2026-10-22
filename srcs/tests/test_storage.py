"""Offline tests for the VM storage gate; no Docker daemon required."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('check_storage', Path(__file__).resolve().parents[1] / 'tools/check_storage.py')
storage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(storage)


class StorageTests(unittest.TestCase):
    def run_gate(self, data_root='/home/learner/data', domain='learner.42.fr', bind=False, bad_mount=False, compose_opts=False):
        config = {'services': {'nginx': {'environment': {'DOMAIN_NAME': domain}}},
                  'volumes': {'mariadb_data': {}, 'wordpress_data': {}}}
        if compose_opts:
            config['volumes']['mariadb_data']['driver_opts'] = {'o': 'bind'}
        def reply(args, **kwargs):
            if args[-1] == '--environment':
                return 'LOGIN=learner\nDATA_PATH=/home/learner/data\n'
            if args[-2:] == ['--format', 'json']:
                return json.dumps(config)
            if args[1] == 'info':
                return data_root
            if args[1:3] == ['volume', 'ls']:
                return 'mariadb_data\n'
            if args[1:3] == ['volume', 'inspect']:
                return json.dumps([{'Driver': 'local', 'Options': {'o': 'bind'} if bind else None,
                    'Mountpoint': '/var/lib/docker/volumes/mariadb_data/_data' if bad_mount else '/home/learner/data/volumes/mariadb_data/_data'}])
            raise AssertionError(args)
        with patch.object(storage.subprocess, 'check_output', side_effect=reply):
            storage.check('docker')

    def test_native_volumes_accepted(self):
        self.run_gate()

    def test_wrong_engine_root_rejected(self):
        with self.assertRaisesRegex(ValueError, 'data-root'):
            self.run_gate(data_root='/var/lib/docker')

    def test_wrong_domain_rejected(self):
        with self.assertRaisesRegex(ValueError, 'DOMAIN_NAME'):
            self.run_gate(domain='other.42.fr')

    def test_old_bind_volume_rejected(self):
        with self.assertRaisesRegex(ValueError, 'incompatible storage'):
            self.run_gate(bind=True)

    def test_volume_outside_required_path_rejected(self):
        with self.assertRaisesRegex(ValueError, 'incompatible storage'):
            self.run_gate(bad_mount=True)

    def test_compose_bind_options_rejected(self):
        with self.assertRaisesRegex(ValueError, 'options are forbidden'):
            self.run_gate(compose_opts=True)


if __name__ == '__main__':
    unittest.main()
