VC3 Builder
==========

NAME
----

**vc3-builder** - Deploy software environments in clusters without administrator priviliges

SYNOPSIS
--------

**vc3-builder** [options] --require package[:min_version[:max_version]] --require ... [-- command-and-args]

DESCRIPTION
-----------

The **vc3-builder** is a tool to manage software stacks without administrator
priviliges. Its primary application comes in deploying software dependencies in
cloud, grid, and opportunistic computing, where deployment must be performed
together with a batch job execution. 

**vc3-builder** is a self-contained program (including the repository of
dependencies recipes). If desired, it can be compiled to a truly static binary
([see below](#compiling-the-builder-as-a-static-binary)).

From the end-user perspective, **vc3-builder** is invoked as a command line
tool which states the desired dependencies.  The builder will perform whatever
work is necessary to deliver those dependencies, then start a shell with the
software activated. For example, assume the original environment is a RHEL7, but we need to run the bioinformatics tool [NCBI BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi) using RHEL6:

```
$ cat /etc/redhat-release 
Red Hat Enterprise Linux Server release 7.4 (Maipo)
$ ./vc3-builder --install ~/tmp/my-vc3 --require-os redhat6 --require ncbi-blast
OS trying:         redhat6 os-native
OS fail prereq:    redhat6 os-native
OS trying:         redhat6 singularity
..Plan:    ncbi-blast => [, ]
..Try:     ncbi-blast => v2.2.28
..Refining version: ncbi-blast v2.2.28 => [, ]
..Success: ncbi-blast v2.2.28 => [, ]
processing for ncbi-blast-v2.2.28
downloading 'ncbi-blast-2.2.28+-x64-linux.tar.gz' from http://download.virtualclusters.org/builder-files
preparing 'ncbi-blast' for x86_64/redhat6.9
details: /opt/vc3-root/x86_64/redhat6.9/ncbi-blast/v2.2.28/ncbi-blast-build-log
sh-4.1$ cat /etc/redhat-release 
CentOS release 6.9 (Final)
sh-4.1$ which blastn
/opt/vc3-root/x86_64/redhat6.9/ncbi-blast/v2.2.28/bin/blastn
sh-4.1$ exit
$ ls -d ~/tmp/my-vc3
/home/btovar/tmp/my-vc3
```

In the first stage, the builder verifies the operating system requirement.
Since the native environment is not RHEL6, it tries to fulfill the requirement
using a container image. If the native environment would not support
containers, the builder terminates indicating that the operating system
requirement cannot be fulfilled.

In the second stage, the builder checks if ncbi-blast is already installed.
Since it is not, it downloads it and sets it up accordingly. As requested, all
the installation was done in `/home/btovar/tmp/my-vc3`, a directory that was
available as `/opt/vc3-root` inside the container.

The builder installs dependencies as needed. For example, simply requiring `python` most likely will provide a python installation already in the system:

```
$ ./vc3-builder --require python                             
..Plan:    python => [, ]
..Try:     python => v2.7.5
..Refining version: python 2.7.5 => [, ]
..Success: python v2.7.5 => [, ]
processing for python-v2.7.5
sh-4.2$ which python
/bin/python
sh-4.2$ 
```

However, if we require the specific version:

```
$ ./vc3-builder --require python:2.7.12
..Plan:    python => [2.7.12, ]
..Try:     python => v2.7.5
..Incorrect version: v2.7.5 => [v2.7.12,]
..Try:     python => v2.7.12
..Refining version: python v2.7.12 => [v2.7.12, ]
....Plan:    libffi => [v3.2.1, ]
....Try:     libffi => v3.2.1
....Refining version: libffi v3.2.1 => [v3.2.1, ]
....Success: libffi v3.2.1 => [v3.2.1, ]

... etc ...

sh-4.2$ which python
/home/btovar/vc3-root/x86_64/redhat7.4/python/v2.7.12/bin/python
```

MOUNTING FILESYSTEMS
--------------------

The builder provides the `--mount` argument to optionally mount directories. It has two forms `--mount /x` and `--mount /x:/y`

#### --mount /x

If executing in the native host environment, the builder simply ensured that the directory `/x` is accessible. If not, it terminates with an error.

If providing the environment with a container, the host environment path `/x` is mounted inside the container as `/x`.

#### --mount /x:/y

If executing in the native host environment, and `/x` and `/y` are
different, the builder reports an error, otherwise it works as `--mount /x`.

When executing inside a container, the host environment path `/x` is mounted
inside the container as `/y`.

Even when the host operating system fulfills the `--require-os` argument, a
container may still be used to fulfill a `--mount` requirement:

```
$ ./vc3-builder --require-os redhat7 --mount /var/scratch/btovar:/madeuppath -- stat -t /madeuppath
OS trying:         redhat7 os-native
Mount source '/var/scratch/btovar' and target '/madeuppath' are different.
OS fail mounts:    redhat7 os-native
OS trying:         redhat7 singularity
/madeuppath 4096 8 41ed 196886 0 805 5111810 5 0 0 1520946165 1517595650 1517595650 0 4096
$
```


As another example, the builder provides support for [cvmfs](https://cernvm.cern.ch/portal/filesystem):

```
$ stat -t /cvmfs/cms.cern.ch
stat: cannot stat '/cvmfs/cms.cern.ch': No such file or directory
$ ./vc3-builder --require cvmfs
./vc3-builder --require cvmfs
..Plan:    cvmfs => [, ]
..Try:     cvmfs => v2.4.0
..Refining version: cvmfs v2.4.0 => [, ]
....Plan:    cvmfs-parrot-libcvmfs => [v2.4.0, ]
....Try:     cvmfs-parrot-libcvmfs => v2.4.0
....Refining version: cvmfs-parrot-libcvmfs v2.4.0 => [v2.4.0, ]
......Plan:    parrot-wrapper => [v6.0.0, ]
......Try:     parrot-wrapper => v6.0.0
......Refining version: parrot-wrapper v6.0.0 => [v6.0.0, ]
........Plan:    cctools => [v6.0.0, ]
........Try:     cctools => v6.2.5
........Refining version: cctools v6.2.5 => [v6.0.0, ]
..........Plan:    cctools-binary => [v6.2.5, ]

... etc ...

sh-4.1$ stat -t /cvmfs/cms.cern.ch 
/cvmfs/cms.cern.ch 4096 9 41ed 0 0 1 256 1 0 1 1409299789 1409299789 1409299789 0 65336
```

In this case, the filesystem cvmfs is not provided natively and the builder tries to fulfill the requirement using the [parrot virtual file system](http://ccl.cse.nd.edu/software/parrot).

RECIPES
-------

The **vc3-builder** includes a repository of recipes. To list the packages available for the `--require` option, use:

```
./vc3-builder --list
atlas-local-root-base-environment:v1.0
augustus:v2.4
cctools:v6.2.5
cctools-unstable:v7.0.0
charm:v6.7.1
cmake:auto
cmake:v3.10.2
... etc ...
```

For operating systems accepted by the `--require-os` option use:

```
./vc3-builder --list=os    
debian9:auto
debian9:v9.2
opensuse42:auto
opensuse42:v42.3
redhat6:auto
redhat6:v6.9
redhat7:auto
redhat7:v7.4
ubuntu16:auto
ubuntu16:v16
```

When a version appears as **auto**, it means that the builder knows how to
recognize that the correspoding requirement is already supplied by the host
system.


### WRITING RECIPES

The builder can be provided with additional package recipes using the
--database=\<catalog\> option. The option can be specified several times, with
latter package recipes overwriting previous ones. 

A recipe catalog is a JSON encoded object, in which the keys of the object are
the names of the packages. Each package is a JSON object that, among other
fields, specifies a list of versions of the package and a recipe to fulfill
that version.

As an example, we will write the recipes for `wget`. First as a generic recipe,
and then with different specific support that builder provides.

##### A generic recipe:

```json
$ cat my-wget-recipe.json
{
    "wget":{
        "versions":[
            {
                "version":"v1.19.4",
                "source":{
                    "type":"generic",
                    "files":[ "wget-1.19.4.tar.gz" ],
                    "recipe":[
                        "tar xf wget-1.19.4.tar.gz",
                        "./configure --prefix=${VC3_PREFIX} --with-zlib --with-ssl=openssl --with-libssl-prefix=${VC3_ROOT_OPENSSL} --with-libuuid",
                        "make",
                        "make install"
                    ]
                }
            }
        ],
        "dependencies":{
            "zlib":[ "v1.2" ],
            "openssl":[ "v1.0.2" ],
            "uuid":[ "v1.0" ],
            "libssh2":[ "v1.8.0" ]
        }
    }
}
```

The field `versions` inside the package definition is a list of JSON objects,
with each object providing the recipe for a version. The files listed in
`files` are automatically downloaded from the site pointed by the --repository
option. The lines in the `recipe` field are executed one by one inside a shell.

Dependencies list the name of the package and a range of acceptable versions.
If only one version is provided, it is taken as a minimum acceptable version.

During the recipe execution, several environment variables are available. For
example, VC3_PREFIX, which points to the package installation directory. Each
package is installed into its own directory. Also, for each of the
dependencies, a VC3_ROOT_dependency variable points to the dependency
installation directory.

##### A tarball recipe:

We can refine the recipe above by using the `tarball` source type, which automatically untars the first file listed in `files`:

```json
{
    "wget":{
        "versions":[
            {
                "version":"v1.19.4",
                "source":{
                    "type":"tarball",
                    "files":[ "wget-1.19.4.tar.gz" ],
                    "recipe":[
                        "./configure --prefix=${VC3_PREFIX} --with-zlib --with-ssl=openssl --with-libssl-prefix=${VC3_ROOT_OPENSSL} --with-libuuid",
                        "make",
                        "make install"
                    ]
                }
            }
        ],
 "... etc ..."
```

##### A configure recipe:

Further, we can do without the recipe using the `configure` type:

```json
{
    "wget":{
        "versions":[
            {
                "version":"v1.19.4",
                "source":{
                    "type":"configure",
                    "files":[ "wget-1.19.4.tar.gz" ],
                    "options":"--with-zlib --with-ssl=openssl --with-libssl-prefix=${VC3_ROOT_OPENSSL} --with-libuuid",
                }
            }
        ],
 "... etc ..."
```

For the `configure` type, there are also the `preface` and `postface` fields.
They are lists of shell commands (as `recipe`), that execute before and after,
respectively, of the `configure; make; make install` step.

##### Adding auto-detection:

```json
 "wget":{
        "versions":[
            {
                "version":"auto",
                "source":{
                    "type":"system",
                    "executable":"wget"
                }
            },
            {
                "version":"v1.19.4",
                "source":{
                    "type":"configure",
 "... etc ..."
```

We include the `system` version before the `configure` version as they are
tried sequentially, and we would prefer not to build `wget` if it is not
necessary. In this case, we simply provide the name of the executable to test,
and the builder will try to get the version number out of the first line of the
output from `executable --version`.

If an system executable does not provide version information in such manner,
`source` needs to provide an `auto-version` field that provides a recipe that
eventually prints to standard output a line such as:

```
VC3_VERSION_SYSTEM: xxx.yyy.zzz
```

For example, in `perl` the version information is provided by the `$^V`
variable, and the `auto-version` field would look like:

```json
...

        "auto-version":[
            "perl -e  'print(\"VC3_VERSION_SYSTEM: $^V\\n\");'"
        ],
...
```

Note that quotes and backslashes need to be escaped so that they are not
interpreted as part of the JSON structure.







OPTIONS
-------

Option                        | Description                                                      
----------------------------- | ------------
command-and-args              |  defaults to an interactive shell.
--database=\<catalog\>        |  defaults to \<internal\> if available, otherwise to `./vc3-catalog.json.` May be specified several times, with latter package recipes overwriting previous ones.
--install=\<root\>            |  Install with base \<root\>. Default is `vc3-root`.
--home=\<home\>               |  Set \${HOME} to \<root\>/\<home\> if \<home\> is a relative path, otherwise to \<home\> if it is an absolute path. Default is `vc3-home`.
--distfiles=\<dir\>           |  Directory to cache unbuilt packages locally. Default is `vc3_distfiles`
--repository=\<url\>          |  Site to fetch packages if needed. Default is the vc3 repository.
--require-os=\<name\>         |  Ensure the operating system is \<name\>. May use a container to fulfill the requirement. May be specified several times, but only the last occurance is honored. Use --list=os for a list of available operating systems.
--mount=/\<x\>                |  Ensure that path /\<x\> is exists inside the execution environment. If using --require-os with a non-native operating system, it is equivalent to --mount /\<x\>:/\<x\>
--mount=/\<x\>:/\<y\>         |  Mount path \<x\> into path \<y\> inside the execution environment. When executing in a native operating system, \<x\> and \<y\> cannot be different paths.
--force                       |  Reinstall the packages named with --require and the packages they depend on.
--make-jobs=\<n\>             |  Concurrent make jobs. Default is 4.
--sh-on-error                 |  On building error, run $shell on the partially-built environment.
--sys=package:version=\<dir\> |  Assume \<dir\> to be the installation location of package:version in the system. (e.g. --sys python:2.7=/opt/local/)
--no-sys=\<package\>          |  Do not use host system version of \<package\>. If package is 'ALL', do not use system versions at all. (Ignored if package specified with --sys.)
--var=NAME=VALUE              |  Add environment variable NAME with VALUE. May be specified several times.
--revar=PATTERN               |  All environment variables matching the regular expression PATTERN are preserved. (E.g. --revar "SGE.\*", --revar NAME is equivalent to -var NAME=\$NAME)
--interactive                 |  Treat command-and-args as an interactive terminal.
--silent                      |  Do not print dependency information.
--no-run                      |  Set up environment, but do not execute any payload.
--timeout=SECONDS             |  Terminate after SECONDS have elapased. If 0, then the timeout is not activated (default).
--env-to=\<file\>             |  Write environment script to \<file\>.{,env,payload}, but do not execute command-and-args. To execute command-and-args, run ./\<file\>.
--dot=\<file\>                |  Write a dependency graph of the requirements to \<file\>.
--parallel=\<dir\>            |  Write specifications for a parallel build to \<dir\>.
--list                        |  List general packages available.
--list=section                |  List general packages available, classified by sections.
--list=all                    |  List all the packages available, even vc3-internals.


COMPILING THE BUILDER AS A STATIC BINARY
----------------------------------------

```
git clone https://github.com/vc3-project/vc3-builder.git
cd vc3-builder
make vc3-builder-static
```

The static version will be available at **vc3-builder-static**. 
The steps above set a local [musl-libc](https://www.musl-libc.org) installation that compile **vc3-builder** into a [static perl](http://software.schmorp.de/pkg/App-Staticperl.html) interpreter.







REFERENCE
---------

Benjamin Tovar, Nicholas Hazekamp, Nathaniel Kremer-Herman, and Douglas Thain.
**Automatic Dependency Management for Scientific Applications on Clusters,**
IEEE International Conference on Cloud Engineering (IC2E), April, 2018. 

