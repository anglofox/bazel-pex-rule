_PACKAGES = {
    "Linux": struct(
        url='https://deps.findmine.com/protobuf/protoc-3.3.0-linux-x86_64.zip',
        sha256='feb112bbc11ea4e2f7ef89a359b5e1c04428ba6cfa5ee628c410eccbfe0b64c3',
    ),
    "Darwin": struct(
        url='https://deps.findmine.com/protobuf/protoc-3.3.0-osx-x86_64.zip',
        sha256='d752ba0ea67239e327a48b2f23da0e673928a9ff06ee530319fc62200c0aff89',
    ),
    "Windows": struct(
        url='https://deps.findmine.com/protobuf/protoc-3.3.0-win32.zip',
        sha256='19ec3d3853c1181912dc442840b3a76bfe0607ecc67d0854b323fdd1fdd8ab77',
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
    command = ['python3.6']
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

    command = ['python3.6', str(getpip)]
    command += list(ctx.attr.packages)
    command += ['--target', str(packages)]
    command += ['--install-option', '--install-scripts=%s' % bin]
    command += ['--no-cache-dir']
    result = ctx.execute(command)

    if result.return_code != 0:
        print('stderr:', result.stderr)
        print('try:', ' '.join(command))

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
            print('try:', ' '.join(command))

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
            'pex==1.2.8',
            'setuptools==33.1.1',
            'protobuf==3.3.0',
            'wheel==0.29.0',
            'requests==2.18.1'
        ]
    )


def pex_requirements(name, packages=None, extra_index=None):
    _pex_reqs(
        name=name,
        packages=packages,
        extra_index=extra_index,
        visibility=['//visibility:public']
    )
