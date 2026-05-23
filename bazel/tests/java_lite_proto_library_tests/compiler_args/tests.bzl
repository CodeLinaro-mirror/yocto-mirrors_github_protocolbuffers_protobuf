# Protocol Buffers - Google's data interchange format
# Copyright 2026 Google LLC
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file or at
# https://developers.google.com/open-source/licenses/bsd

"""Tests that we pass the correct arguments to the protocol compiler."""

load("@rules_testing//lib:truth.bzl", "matching")

def _test_lite_java_proto2_compiler_args(env, target):
    genproto = env.expect.that_target(target).action_named("GenProto")
    genproto.argv().contains("{package}/foo.proto")
    genproto.argv().contains_predicate(
        matching.any(
            matching.equals_wrapper("-I."),
            matching.equals_wrapper("--descriptor_set_in"),
        ),
    )
    genproto.argv().contains_at_least([
        "--java_out=lite:{bindir}/{package}/foo_proto-lite-src.jar",
        "{package}/foo.proto",
    ]).in_order()

TESTS = {
    ":foo_proto": [_test_lite_java_proto2_compiler_args],
}
