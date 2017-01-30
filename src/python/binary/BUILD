load('//tools/build_rules:pex_rules.bzl', 'pex_binary')

pex_binary(
    name='binary',
    srcs=glob(['**']),
    deps=['//src/python/library'],
    reqs=['@binary//:requirements'],
    entry_point='binary'
)
