import argparse
import inspect
import os
import pkgutil
import sys
import unittest
from importlib.util import spec_from_file_location, module_from_spec
from os.path import expanduser
from pathlib import Path

from multidict import MultiDict

tester = os.path.dirname(os.path.abspath(__file__))
data_file = Path(tester) / 'packages.dat'
if not data_file.exists():
    print('packages data file not found', file=sys.stderr)
    exit(1)

parser = argparse.ArgumentParser(
    add_help=False,
    formatter_class=argparse.RawTextHelpFormatter
)
parser.add_argument('--help', action='help', help=argparse.SUPPRESS)
parser.add_argument(
    'packages',
    metavar='PACKAGE',
    nargs='*',
    default=[],
    help='run unittest of the specified package.'
)
args = parser.parse_args()

with open(str(data_file), 'r') as file:
    packages = file.read().splitlines()

if 'TEST_WORKSPACE' in os.environ:
    home = Path(os.environ.get('PWD')) / '.pex'
else:
    home = os.environ.get('PEX_ROOT', Path(expanduser('~')) / '.pex')
root = Path(home) / 'install'


def walk_packages(path=None, prefix='', onerror=None):
    for finder, name, ispkg in pkgutil.iter_modules(path, prefix):
        yield finder, name, ispkg

        if ispkg:
            try:
                spec = finder.find_spec(name, [path])
            except ImportError:
                if onerror is not None:
                    onerror(name)
            except Exception:
                if onerror is not None:
                    onerror(name)
                else:
                    raise
            else:
                path = spec.submodule_search_locations
                yield from walk_packages(path, name + '.', onerror)


routes = MultiDict()
for source_path in sys.path:
    sub_path = Path(source_path)
    if root in sub_path.parents:
        if sub_path.name in packages:
            tests = sub_path / 'tests'
            if not tests.exists():
                continue

            for pkg in walk_packages([str(tests)], 'tests.'):
                _finder, _name, _ispkg = pkg
                routes.add(_name, dict(
                    path=_finder.path,
                    mod=_name,
                    cls=None,
                    file=None,
                    func=None
                ))
                if _name in sys.modules:
                    del sys.modules[_name]
                mod = _finder.find_module(_name).load_module()
                for cls_name, cls in mod.__dict__.items():
                    if not inspect.isclass(cls):
                        continue

                    if issubclass(cls, unittest.TestCase):
                        cls_qname = '.'.join([_name, cls_name])
                        _file = inspect.getsourcefile(cls)
                        routes.add(cls_qname, dict(
                            path=_finder.path,
                            mod=_name,
                            cls=cls_name,
                            file=_file,
                            func=None
                        ))
                        for func_name, func in cls.__dict__.items():
                            if not func_name.startswith('test_'):
                                continue

                            var_qname = '.'.join([cls_qname, func_name])
                            routes.add(var_qname, dict(
                                path=_finder.path,
                                mod=_name,
                                cls=cls_name,
                                file=_file,
                                func=func_name
                            ))


def _(x):
    return x['mod'], x['path'], x['cls'], x['func']


tests = list()
if len(args.packages) != 0:
    dedup = dict()
    for pkg in args.packages:
        finds = routes.getall('tests.' + pkg, None)
        if finds is None:
            continue

        for found in finds:
            if found['cls'] is not None and found['func'] is not None:
                dkey = ':'.join([found['file'], found['cls'], found['func']])
                dedup[dkey] = found
                continue
            elif found['cls'] is not None and found['func'] is None:
                for key, val in routes.items():
                    if found['mod'] == val['mod'] \
                            and found['cls'] == val['cls'] \
                            and val['func'] is not None:

                        dkey = ':'.join([val['file'], val['cls'], val['func']])
                        dval = dedup.get(dkey, None)
                        if dval is None or len(dval['mod']) > len(val['mod']):
                            dedup[dkey] = val
            else:
                for key, val in routes.items():
                    if found['mod'] == val['mod'] and val['func'] is not None:
                        dkey = ':'.join([val['file'], val['cls'], val['func']])
                        dval = dedup.get(dkey, None)
                        if dval is None or len(dval['mod']) > len(val['mod']):
                            dedup[dkey] = val

    tests = sorted(dedup.values(), key=_)

else:
    dedup = dict()
    for key, val in routes.items():
        if val['func'] is not None:
            dkey = ':'.join([val['file'], val['cls'], val['func']])
            dval = dedup.get(dkey, None)
            if dval is None or len(dval['mod']) > len(val['mod']):
                dedup[dkey] = val

    tests = sorted(dedup.values(), key=_)

suite = unittest.TestSuite()
for test in tests:
    _spec = spec_from_file_location(test['mod'], test['file'])
    mod = module_from_spec(_spec)
    _spec.loader.exec_module(mod)
    TestClass = getattr(mod, test['cls'])
    suite.addTest(TestClass(test['func']))

unittest.TextTestRunner(verbosity=3).run(suite)
