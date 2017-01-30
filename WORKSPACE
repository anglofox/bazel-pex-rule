workspace(name='bazel_pex_rule')

load(
    '//tools/build_rules:tools_rules.bzl',
    'proto_dependencies',
    'pip_dependencies',
    'pex_requirements'
)

proto_dependencies()
pip_dependencies()
pex_requirements('binary', packages=[])
pex_requirements('library', packages=[
    'pyyaml==3.12'
])
