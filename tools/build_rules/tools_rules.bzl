_PACKAGES = {
    "Linux": struct(
        url='https://deps.findmine.com/protobuf/protoc-3.1.0-linux-x86_64.zip',
        sha256='7c98f9e8a3d77e49a072861b7a9b18ffb22c98e37d2a80650264661bfaad5b3a',
    ),
    "Darwin": struct(
        url='https://deps.findmine.com/protobuf/protoc-3.1.0-osx-x86_64.zip',
        sha256='2cea7b1acb86671362f7aa554a21b907d18de70b15ad1f68e72ad2b50502920e',
    ),
    "Windows": struct(
        url='https://deps.findmine.com/protobuf/protoc-3.1.0-win32.zip',
        sha256='e46b3b7c5c99361bbdd1bbda93c67e5cbf2873b7098482d85ff8e587ff596b23',
    ),
}

_PROTO_BUILD_FILE = """
filegroup(
    name='tools',
    srcs=glob(['bin/**/*', 'include/**/*']),
    visibility=['//visibility:public']
)
"""

_PIP_BUILD_FILE = """
filegroup(
    name='tools',
    srcs=glob(
        include=['bin/*', 'site-packages/**/*'],
        exclude=[
            # Illegal as Bazel labels but are not required by pip.
            "site-packages/setuptools/command/launcher manifest.xml",
            "site-packages/setuptools/*.tmpl",
        ]
    ),
    visibility=['//visibility:public']
)
"""

_PIP_BIN_BUILD_FILE = """
filegroup(
    name='bin',
    srcs=glob(['*']),
    visibility=['//visibility:public']
)
"""

_PEX_BUILD_FILE = """
filegroup(
    name='requirements',
    srcs=glob(['downloads/**/*', 'MANIFEST']),
    visibility=['//visibility:public']
)
"""


def _proto_tools_impl(ctx):
    command = ['python3']
    command += ['-c']
    command += ['import platform; print(platform.system(), end="")']
    platform = ctx.execute(command)
    ctx.download_and_extract(
        _PACKAGES[platform.stdout].url, ctx.path(''),
        sha256=_PACKAGES[platform.stdout].sha256,
        type='zip'
    )

    ctx.file('BUILD', _PROTO_BUILD_FILE, False)


def _pip_tools_impl(ctx):
    getpip = ctx.path(ctx.attr._getpip)
    bin = ctx.path('bin')
    packages = ctx.path('site-packages')

    command = ['python3', str(getpip)]
    command += list(ctx.attr.packages)
    command += ['--target', str(packages)]
    command += ['--install-option', '--install-scripts=%s' % bin]
    command += ['--no-cache-dir']
    result = ctx.execute(command)

    if result.return_code != 0:
        print('stderr:', result.stderr)

    ctx.file('%s/BUILD' % bin, _PIP_BIN_BUILD_FILE, False)
    ctx.file('BUILD', _PIP_BUILD_FILE, False)


def _pex_reqs_impl(ctx):
    pip = ctx.path(ctx.attr._pip)
    downloads = ctx.path('downloads')

    ctx.execute(['mkdir', '-p', downloads])
    for package in ctx.attr.packages:
        command = [str(pip), 'download']
        command += ['--only-binary', ':all:']
        command += [package]

        for link in ctx.attr.extra_index:
            command += ['--extra-index-url', link]
            command += ['--trusted-host', link.split('//')[1].split('/')[0]]

        command += ['-v']
        command += ['--dest', str(downloads)]
        result = ctx.execute(command)

        if result.return_code != 0:
            print('stderr:', result.stderr)

    result = ctx.execute(['ls', '%s' % downloads])
    filenames = result.stdout.strip().split('\n')
    renamed = [e.replace('manylinux1', 'linux') for e in filenames]

    for i in range(len(filenames)):
        old = '%s/%s' % (downloads, filenames[i])
        new = '%s/%s' % (downloads, renamed[i])
        ctx.execute(['mv', old, new])

    for filename in renamed:
        filepath = '%s/%s' % (downloads, filename)
        ctx.execute([str(pip), 'wheel', filepath, '-w', downloads])

    ctx.file('%s/MANIFEST' % downloads, ' '.join(ctx.attr.packages), False)
    ctx.file('BUILD', _PEX_BUILD_FILE, False)


_proto_tools = repository_rule(_proto_tools_impl)

_pip_tools = repository_rule(
    _pip_tools_impl,
    attrs={
        'packages': attr.string_list(),
        '_getpip': attr.label(
            default=Label('@getpip//file:get-pip.py'),
            allow_single_file=True,
            executable=True,
            cfg='host'
        )
    }
)

_pex_reqs = repository_rule(
    _pex_reqs_impl,
    attrs={
        'packages': attr.string_list(default=[], allow_empty=True),
        'extra_index': attr.string_list(
            default=['https://deps.findmine.com/pypi/'],
            allow_empty=True
        ),
        '_getpip': attr.label(
            default=Label('@getpip//file:get-pip.py'),
            allow_single_file=True,
            executable=True,
            cfg='host'
        ),
        '_pip': attr.label(
            default=Label('@pip//bin:pip3'),
            executable=True,
            cfg='host'
        )
    }
)


def proto_dependencies():
    _proto_tools(
        name="proto",
        visibility=['//visibility:public']
    )


def pip_dependencies():
    if native.existing_rule('getpip') == None:
        native.http_file(
            name="getpip",
            url="https://bootstrap.pypa.io/get-pip.py",
            sha256="19dae841a150c86e2a09d475b5eb0602861f2a5b7761ec268049a662dbd2bd0c"
        )

    _pip_tools(
        name="pip",
        visibility=['//visibility:public'],
        packages=[
            'pex==1.2.1',
            'protobuf==3.1.0.post1',
            'wheel==0.29.0'
        ]
    )


def pex_requirements(name, packages=None, extra_index=None):
    _pex_reqs(
        name=name,
        packages=packages,
        extra_index=extra_index,
        visibility=['//visibility:public']
    )
