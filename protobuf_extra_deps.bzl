"""Loads the dependencies necessary for the external repositories defined in protobuf_deps.bzl.

The consumers should use the following WORKSPACE snippet, which loads dependencies
and sets up the repositories protobuf needs:

```
http_archive(
    name = "protobuf",
    strip_prefix = "protobuf-VERSION",
    sha256 = ...,
    url = ...,
)

load("@protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

load("@protobuf//:protobuf_extra_deps.bzl", "protobuf_extra_deps")

protobuf_extra_deps();
```
"""

load("@rules_java//java:repositories.bzl", "rules_java_dependencies", "rules_java_toolchains")

def protobuf_extra_deps():
    """Loads extra dependencies needed for the external repositories defined in protobuf_deps.bzl."""

    rules_java_dependencies()

    rules_java_toolchains()
