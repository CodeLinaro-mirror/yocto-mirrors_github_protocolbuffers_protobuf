// Protocol Buffers - Google's data interchange format
// Copyright 2024 Google LLC.  All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

#ifndef GOOGLE_PROTOBUF_COMPILER_HPB_CONTEXT_H__
#define GOOGLE_PROTOBUF_COMPILER_HPB_CONTEXT_H__

#include <memory>
#include <utility>

#include "absl/strings/string_view.h"
#include "absl/types/source_location.h"
#include "absl/types/span.h"
#include "google/protobuf/io/printer.h"
#include "google/protobuf/io/zero_copy_stream.h"
namespace google::protobuf::hpb_generator {

enum class Backend { UPB, CPP };

struct Options {
  Backend backend = Backend::UPB;
};

/**
 * This Context object will be used throughout hpb generation.
 * It is a thin wrapper around an io::Printer and can be easily extended
 * to support more options.
 *
 * Expected usage is:
 * SomeGenerationFunc(..., HpbContext& context) {
 *   context.Emit({{"some_key", some_computed_val}}, R"cc(
 *   // hpb gencode ...
 *  )cc);
 * }
 */
class HpbContext final {
 public:
  HpbContext(std::unique_ptr<io::ZeroCopyOutputStream> stream,
             const Options& options)
      : stream_(std::move(stream)),
        printer_(stream_.get()),
        options_(options) {}

  void Emit(absl::Span<const io::Printer::Sub> vars, absl::string_view format,
            absl::SourceLocation loc = absl::SourceLocation::current()) {
    printer_.Emit(vars, format, loc);
  }

  void Emit(absl::string_view format,
            absl::SourceLocation loc = absl::SourceLocation::current()) {
    printer_.Emit(format, loc);
  }

  absl::string_view GetBackend() {
    switch (options_.backend) {
      case Backend::UPB:
        return "upb";
      case Backend::CPP:
        return "cpp";
    }
  }

 private:
  std::unique_ptr<io::ZeroCopyOutputStream> stream_;
  io::Printer printer_;
  const Options& options_;
};

}  // namespace protobuf
}  // namespace google::hpb_generator

#endif  // GOOGLE_PROTOBUF_COMPILER_HPB_CONTEXT_H__
