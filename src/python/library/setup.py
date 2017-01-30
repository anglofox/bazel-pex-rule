from setuptools import setup, find_packages

setup(
    name='library',
    version='0.0.1',
    description='Library application',
    long_description='This is the library application.',
    url='https://github.com/findmine/bazel-pex-rule',
    license='Apache-2.0',
    author='Konstantin Itskov',
    author_email='konstantin.itskov@findmine.com',
    classifiers=[
        'License :: OSI Approved :: Apache Software License',
        'Intended Audience :: Developers',
        'Programming Language :: Python',
        'Topic :: Internet :: WWW/HTTP'
    ],
    install_requires=[],
    packages=find_packages()
)
