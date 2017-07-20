# Bazel Pex Rule Tutorial
This entire project is a tutorial designed to introduce a bazel based python 
development setup which, unlike the standard bazel python rules found 
[HERE](https://docs.bazel.build/versions/master/be/python.html), introduces
the use of [pex](https://github.com/pantsbuild/pex) into the bazel rule set. 
Pex is a tool for generating complety encapsulated python executable files 
that bundle python packages into a single executable file included with all 
the external dependencies.

> Before begining this tutorial please make sure you have bazel and python3.6 
installed on your system. This tutorial was created on ubuntu linux sorry if 
it only helps partially.

## Preparation
### Installing Bazel
https://docs.bazel.build/versions/master/install-ubuntu.html

### Installing Python3.6
```bash
sudo add-apt-repository -y ppa:fkrull/deadsnakes
sudo apt-get update
sudo apt-get install -y python3.6 python3.6-dev python3.6-doc python3.6-gdbm
cd /tmp
wget https://bootstrap.pypa.io/get-pip.py
sudo python3.6 /tmp/get-pip.py
```

## Tutorial
### Quick Example
```bash
git clone https://github.com/findmine/bazel-pex-rule.git
cd bazel-pex-rule
bazel build src/python/binary:binary
cd /bazel-bin/src/python/binary
./binary
```

### Explanation
The vast majority of what bazel does and how it does it can really be found
on https://bazel.build/ which, by the way, is a sick domain for the project.
However the rule specific information we built is found pertaining to pex and
packaging is located in `tools/build_rules/pex_rules.bzl` and 
`tools/build_rules/tools_rules.bzl` the `BUILD` and `WORKSPACE` files of the 
individual proejcts and the workspace load pex rules from these files.

TODO more about what is built and how it happens to come

## Pex Rule Interface
```
pex_binary
pex_library
pex_test
pex_test_library
```

TODO details expanation in the style of bazel docs about the actual functions