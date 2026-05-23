# Protocol Buffers - Google's data interchange format
# Copyright 2026 Google LLC
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file or at
# https://developers.google.com/open-source/licenses/bsd

"""Tests for same version compiler arguments."""

load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_testing//lib:truth.bzl", "matching")

def _test_same_version_compiler_arguments(env, target):
    genproto = env.expect.that_target(target).action_named("GenProto")
    genproto.argv().contains("{package}/baz.proto")
    genproto.argv().contains_predicate(
        matching.any(
            matching.equals_wrapper("-I."),
            matching.equals_wrapper("--descriptor_set_in"),
        ),
    )
    genproto.argv().contains_at_least([
        "--java_out={bindir}/{package}/baz_proto-speed-src.jar",
        "{package}/baz.proto",
    ]).in_order()
    genproto.argv().not_contains("--java_out=shared,immutable:{bindir}/{package}/foo_proto-speed-src.jar")
    java_info = env.expect.that_target(target).provider(JavaInfo)
    java_info.transitive_runtime_jars().contains_at_least([
        "{package}/libbaz_proto-speed.jar",
        "java/core/libcore.jar",
    ])

TESTS = {
    ":baz_proto": [_test_same_version_compiler_arguments],
}
