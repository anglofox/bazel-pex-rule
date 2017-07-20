python_file_types = FileType(['.py', '.pyc'])
proto_file_types = FileType(['.proto'])


def collect_transitive_srcs(ctx):
    transitive_srcs = depset(order="compile")
    for dep in ctx.attr.deps:
        transitive_srcs += dep.transitive_srcs
    transitive_srcs += python_file_types.filter(ctx.files.srcs)
    return transitive_srcs


def collect_transitive_gens(ctx):
    transitive_gens = depset(order="compile")
    for dep in ctx.attr.deps:
        transitive_gens += dep.transitive_gens
    transitive_gens += proto_file_types.filter(ctx.files.srcs)
    return transitive_gens


def collect_transitive_data(ctx):
    transitive_data = depset(order="compile")
    for dep in ctx.attr.deps:
        transitive_data += dep.transitive_data
    for datum in ctx.attr.data:
        transitive_data += datum.files
    return transitive_data


def collect_transitive_reqs(ctx):
    transitive_reqs = depset(order="compile")
    for dep in ctx.attr.deps:
        transitive_reqs += dep.transitive_reqs
    if ctx.attr.reqs != None:
        for req in ctx.attr.reqs:
            transitive_reqs += req.files
    return transitive_reqs


def collect_transitive_deps(ctx):
    transitive_deps = depset(order="compile")
    for dep in ctx.attr.deps:
        transitive_deps += dep.transitive_deps
    return transitive_deps


def collect_transitive_builds(ctx):
    transitive_builds = depset(order="compile")
    for dep in ctx.attr.deps:
        transitive_builds += dep.transitive_builds
    return transitive_builds


def collect_protobuf_gens(ctx, transitive_gens):
    proto_gens = depset(order="compile")
    proto_gens += python_file_types.filter(transitive_gens)
    sources = proto_file_types.filter(transitive_gens)
    for source in sources:
        localpath = source.path.split('/')
        localpath[-1] = ''.join([source.basename.split('.')[0], '_pb2.py'])
        localpath = localpath[len(ctx.build_file_path.split('/')[:-1]):]
        output = ctx.new_file(ctx.genfiles_dir, '/'.join(localpath))
        proto_gens += depset([output])

        command = 'external/proto/bin/protoc ' + \
                  '-I=%s ' % source.dirname + \
                  '--python_out=%s ' % output.dirname + \
                  '%s' % source.path

        ctx.action(
            mnemonic='ProtoCompile',
            inputs=list(depset(sources) + ctx.attr._protoc.files),
            command=command,
            outputs=[output],
            env={
                'PATH': '/bin:/usr/bin:/usr/local/bin',
                'LANG': 'en_US.UTF-8'
            }
        )

    return proto_gens


def pex_library_impl(ctx):
    build_path = '/'.join(ctx.build_file_path.split('/')[:-1])
    transitive_srcs = collect_transitive_srcs(ctx)
    transitive_gens = collect_transitive_gens(ctx)
    transitive_gens = collect_protobuf_gens(ctx, transitive_gens)
    transitive_data = collect_transitive_data(ctx)
    transitive_reqs = collect_transitive_reqs(ctx)
    transitive_deps = collect_transitive_deps(ctx)
    transitive_deps += depset([build_path])

    return struct(
        files=depset(),
        transitive_srcs=transitive_srcs,
        transitive_gens=transitive_gens,
        transitive_data=transitive_data,
        transitive_reqs=transitive_reqs,
        transitive_deps=transitive_deps
    )


def pex_library_test_impl(ctx):
    build_path = '/'.join(ctx.build_file_path.split('/')[:-1])
    transitive_srcs = collect_transitive_srcs(ctx)
    transitive_gens = collect_transitive_gens(ctx)
    transitive_gens = collect_protobuf_gens(ctx, transitive_gens)
    transitive_data = collect_transitive_data(ctx)
    transitive_reqs = collect_transitive_reqs(ctx)
    transitive_deps = collect_transitive_deps(ctx)
    transitive_deps += depset([build_path])

    bdist_wheel = ctx.new_file(ctx.genfiles_dir, 'bdist_wheel')
    command = ['export PATH=$PATH:`pwd`/external/pip/']
    command += ['export PYTHONPATH=`pwd`/external/pip/site-packages']
    command += ['cd %s' % build_path]
    command += ['python3.6 setup.py --quiet bdist_wheel &> /dev/null']
    command += ['cd - > /dev/null']
    command += ['ls %s/dist > %s' % (build_path, bdist_wheel.path)]

    ctx.action(
        mnemonic='WheelFilenameCompile',
        inputs=list(
            transitive_srcs +
            transitive_gens +
            transitive_data
        ),
        command=' && '.join(command),
        outputs=[bdist_wheel],
        env={
            'PATH': '/bin:/usr/bin:/usr/local/bin',
            'LANG': 'en_US.UTF-8'
        }
    )

    transitive_builds = collect_transitive_builds(ctx)
    transitive_builds += depset([bdist_wheel])

    return struct(
        files=depset(),
        transitive_srcs=transitive_srcs,
        transitive_gens=transitive_gens,
        transitive_data=transitive_data,
        transitive_reqs=transitive_reqs,
        transitive_deps=transitive_deps,
        transitive_builds=transitive_builds
    )


def pex_binary_impl(ctx):
    build_path = '/'.join(ctx.build_file_path.split('/')[:-1])
    transitive_srcs = collect_transitive_srcs(ctx)
    transitive_gens = collect_transitive_gens(ctx)
    transitive_gens = collect_protobuf_gens(ctx, transitive_gens)
    transitive_data = collect_transitive_data(ctx)
    transitive_reqs = collect_transitive_reqs(ctx)
    transitive_deps = collect_transitive_deps(ctx)
    transitive_deps += depset([build_path])

    runfiles = ctx.runfiles(
        collect_default=True,
        transitive_files=(
            transitive_srcs +
            transitive_gens +
            transitive_data
        )
    )

    command = []
    command += ['export PATH=$PATH:`pwd`/external/pip/']
    command += ['export PYTHONPATH=`pwd`/external/pip/site-packages']
    for genfile in transitive_gens:
        dest = genfile.path.replace('%s/' % ctx.genfiles_dir.path, '')
        command += [' '.join(['cp', genfile.path, dest])]

    link_paths = depset([file.dirname for file in transitive_reqs])
    manifests = ' '.join(['%s/MANIFEST' % path for path in link_paths])
    command += ['REQS=$(awk "{print}" ORS=" " %s)' % manifests]

    command += [' '.join([
        'external/pip/bin/pex',
        '%s $REQS' % ' '.join([f for f in transitive_deps]),
        ' '.join(['-f %s' % path for path in link_paths]),
        '-v -v -v' if ctx.attr.verbose else '-v',
        '--entry-point=%s' % ctx.attr.entry_point,
        '--output-file=%s' % ctx.outputs.executable.path,
        '--python=%s' % ctx.attr.interpreter,
        '--no-index'
    ])]

    pip_tools = depset(order="compile")
    for target in ctx.attr._pip:
        pip_tools += depset([file for file in target.files])

    ctx.action(
        mnemonic='PexCompile',
        inputs=list(
            pip_tools +
            transitive_srcs +
            transitive_gens +
            transitive_data +
            transitive_reqs
        ),
        command=' && '.join(command),
        outputs=[ctx.outputs.executable],
        env={
            'PATH': '/bin:/usr/bin:/usr/local/bin',
            'LANG': 'en_US.UTF-8',
            'PEX_ROOT': ctx.attr._root
        }
    )

    return struct(
        files=depset([ctx.outputs.executable]),
        runfiles=runfiles,
        transitive_srcs=transitive_srcs,
        transitive_gens=transitive_gens,
        transitive_data=transitive_data,
        transitive_reqs=transitive_reqs,
        transitive_deps=transitive_deps
    )


def pex_test_impl(ctx):
    build_path = '/'.join(ctx.build_file_path.split('/')[:-1])
    transitive_srcs = collect_transitive_srcs(ctx)
    transitive_gens = collect_transitive_gens(ctx)
    transitive_gens = collect_protobuf_gens(ctx, transitive_gens)
    transitive_data = collect_transitive_data(ctx)
    transitive_reqs = collect_transitive_reqs(ctx)
    transitive_deps = collect_transitive_deps(ctx)
    transitive_deps += depset([build_path, ctx.attr._tester.label.package])

    bdist_wheel = ctx.new_file(ctx.genfiles_dir, 'bdist_wheel')
    command = ['export PATH=$PATH:`pwd`/external/pip/']
    command += ['export PYTHONPATH=`pwd`/external/pip/site-packages']
    command += ['cd %s' % build_path]
    command += ['python3.6 setup.py --quiet bdist_wheel &> /dev/null']
    command += ['cd - > /dev/null']
    command += ['ls %s/dist > %s' % (build_path, bdist_wheel.path)]

    ctx.action(
        mnemonic='WheelFilenameCompile',
        inputs=list(
            transitive_srcs +
            transitive_gens +
            transitive_data
        ),
        command=' && '.join(command),
        outputs=[bdist_wheel],
        env={
            'PATH': '/bin:/usr/bin:/usr/local/bin',
            'LANG': 'en_US.UTF-8'
        }
    )

    transitive_builds = collect_transitive_builds(ctx)
    transitive_builds += depset([bdist_wheel])

    runfiles = ctx.runfiles(
        collect_default=True,
        transitive_files=(
            transitive_srcs +
            transitive_gens +
            transitive_data
        )
    )

    command = []
    command += ['export PATH=$PATH:`pwd`/external/pip/']
    command += ['export PYTHONPATH=`pwd`/external/pip/site-packages']
    for genfile in transitive_gens:
        dest = genfile.path.replace('%s/' % ctx.genfiles_dir.path, '')
        command += [' '.join(['cp', genfile.path, dest])]

    packages = '%s/tester/packages.dat' % ctx.attr._tester.label.package
    for build in transitive_builds:
        command += ['cat %s >> %s' % (build.path, packages)]

    link_paths = depset([file.dirname for file in transitive_reqs])
    manifests = ' '.join(['%s/MANIFEST' % path for path in link_paths])
    command += ['REQS=$(awk "{print}" ORS=" " %s)' % manifests]

    command += [' '.join([
        'external/pip/bin/pex',
        '%s $REQS' % ' '.join([f for f in transitive_deps]),
        ' '.join(['-f %s' % path for path in link_paths]),
        '-v -v -v' if ctx.attr.verbose else '-v',
        '--entry-point=%s' % ctx.attr._tester.label.name,
        '--output-file=%s' % ctx.outputs.executable.path,
        '--python=%s' % ctx.attr.interpreter,
        '--no-index'
    ])]

    pip_tools = depset(order="compile")
    for target in ctx.attr._pip:
        pip_tools += depset([file for file in target.files])

    ctx.action(
        mnemonic='PexCompile',
        inputs=list(
            pip_tools +
            transitive_srcs +
            transitive_gens +
            transitive_data +
            transitive_reqs +
            transitive_builds +
            ctx.attr._tester.files
        ),
        command=' && '.join(command),
        outputs=[ctx.outputs.executable],
        env={
            'PATH': '/bin:/usr/bin:/usr/local/bin',
            'LANG': 'en_US.UTF-8',
            'PEX_ROOT': ctx.attr._root
        }
    )

    return struct(
        files=depset([ctx.outputs.executable]),
        runfiles=runfiles,
        transitive_srcs=transitive_srcs,
        transitive_gens=transitive_gens,
        transitive_data=transitive_data,
        transitive_reqs=transitive_reqs,
        transitive_deps=transitive_deps,
        transitive_builds=transitive_builds
    )


pex_attrs = {
    '_protoc': attr.label(default=Label('@proto//:tools')),
    'srcs': attr.label_list(allow_files=True),
    'data': attr.label_list(allow_files=True, allow_empty=True, cfg='data'),
    'reqs': attr.label_list(allow_empty=True)
}

pex_deps_attrs = {
    'deps': attr.label_list(
        providers=[
            'transitive_srcs',
            'transitive_gens',
            'transitive_data',
            'transitive_reqs',
            'transitive_deps'
        ],
        allow_files=False
    )
}

pex_deps_test_attrs = {
    'deps': attr.label_list(
        providers=[
            'transitive_srcs',
            'transitive_gens',
            'transitive_data',
            'transitive_reqs',
            'transitive_deps',
            'transitive_builds'
        ],
        allow_files=False
    )
}

pex_build_attrs = {
    '_pip': attr.label_list(
        default=[Label('@pip//:tools'), Label('@pip//bin')]),
    '_root': attr.string(default='.pex'),
    'interpreter': attr.string(default='python3.6'),
    'verbose': attr.bool(default=False)
}

pex_entry_attrs = {
    'entry_point': attr.string(mandatory=True)
}

pex_tester_attrs = {
    '_tester': attr.label(default=Label('//tools/python/tester'))
}

_pex_library = rule(
    pex_library_impl,
    attrs=pex_attrs + pex_deps_attrs
)

_pex_test_library = rule(
    pex_library_test_impl,
    attrs=pex_attrs + pex_deps_test_attrs
)

_pex_binary = rule(
    pex_binary_impl,
    attrs=pex_attrs + pex_deps_attrs + pex_build_attrs + pex_entry_attrs,
    executable=True
)

_pex_test = rule(
    pex_test_impl,
    attrs=pex_attrs + pex_deps_test_attrs + pex_build_attrs + pex_tester_attrs,
    executable=True,
    test=True
)


def pex_library(name, srcs, data=None, reqs=None, deps=None):
    _pex_library(
        name=name,
        srcs=srcs,
        data=data,
        reqs=reqs,
        deps=deps,
        visibility=['//visibility:public']
    )


def pex_test_library(name, srcs, data=None, reqs=None, deps=None):
    _pex_test_library(
        name=name,
        srcs=srcs,
        data=data,
        reqs=reqs,
        deps=deps,
        visibility=['//visibility:public']
    )


def pex_binary(name, srcs, entry_point, data=None, reqs=None, deps=None,
               interpreter=None, verbose=None):
    _pex_binary(
        name=name,
        srcs=srcs,
        data=data,
        reqs=reqs,
        deps=deps,
        entry_point=entry_point,
        interpreter=interpreter,
        verbose=verbose,
        visibility=['//visibility:public']
    )


def pex_test(name, size, srcs, data=None, reqs=None, deps=None,
             interpreter=None, verbose=None):
    _pex_test(
        name=name,
        size=size,
        srcs=srcs,
        data=data,
        reqs=reqs,
        deps=deps,
        interpreter=interpreter,
        verbose=verbose,
        visibility=['//visibility:public']
    )
