#ifndef GOOGLE_PROTOBUF_COMPILER_RUST_ACCESSORS_WITH_PRESENCE_ACCESSORS_HELPER_H__
#define GOOGLE_PROTOBUF_COMPILER_RUST_ACCESSORS_WITH_PRESENCE_ACCESSORS_HELPER_H__

#include "google/protobuf/compiler/rust/accessors/accessor_case.h"
#include "google/protobuf/compiler/rust/context.h"
#include "google/protobuf/descriptor.h"

namespace google {
namespace protobuf {
namespace compiler {
namespace rust {

void WithPresenceAccessorsInMsgImpl(Context& ctx, const FieldDescriptor& field,
                                    AccessorCase accessor_case);

void WithPresenceAccessorsInExternC(Context& ctx, const FieldDescriptor& field);

void WithPresenceAccessorsInThunkCc(Context& ctx, const FieldDescriptor& field);

}  // namespace rust
}  // namespace compiler
}  // namespace protobuf
}  // namespace google

#endif  // GOOGLE_PROTOBUF_COMPILER_RUST_ACCESSORS_WITH_PRESENCE_ACCESSORS_HELPER_H__
