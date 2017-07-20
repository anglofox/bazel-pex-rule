from setuptools import setup, find_packages

setup(
    name='tester',
    version='0.0.1',
    description='tester description',
    long_description='tester long description',
    license='Proprietary',
    author='Konstantin Itskov',
    author_email='konstantin.itskov@findmine.com',
    classifiers=[
        'License :: Other/Proprietary License',
        'Intended Audience :: Developers',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.5',
        'Operating System :: POSIX :: Linux'
    ],
    packages=find_packages(),
    package_data={
        '': ['*.dat'],
    }
)
