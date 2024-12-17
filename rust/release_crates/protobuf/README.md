The runtime of the official Google Rust Protobuf implementation.

This is currently a beta release: the API is subject to change, and there may be
some rough edges including missing documentation and features.

Usage of this crate currently requires protoc to be built from source as it
relies on changes that have not been included in the newest protoc release yet.

An example for how to use this crate can be found in the
[protobuf_example crate](http://crates.io/crates/protobuf_example)

# v4 ownership and implementation change

v4 of this crate is officially supported by the Protobuf team at Google. Prior
major versions were developed by as a community project by
[stepancheg](https://github.com/stepancheg) who generously donated the crate
name to Google.

V4 is a completely new implementation with a different API, as well as a
fundamentally different approach than prior versions of this crate. It focuses
on high quality Rust API which is backed by either a pure C implementation (upb)
or the Protobuf C++ implementation for performance, feature parity, development
velocity and security reasons. More discussion about the rationale and
design philosophy can be found at
[https://protobuf.dev/reference/rust/](https://protobuf.dev/reference/rust/).

It is not planned for the V3 pure Rust implementation to be actively extended or
maintained going forward. While it is not expected to receive significant
further development, as a stable and high quality pure Rust implementation,
many open source projects may reasonable continue to stay on the V3 API.
