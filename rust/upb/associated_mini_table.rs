// Protocol Buffers - Google's data interchange format
// Copyright 2024 Google LLC.  All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

use super::upb_MiniTable;

/// A trait for types which have a constant associated MiniTable (e.g.
/// generated messages, and their mut and view proxy types).
///
/// SAFETY:
/// - The MiniTable pointer must be a const object, valid for 'static lifetime.
pub unsafe trait AssociatedMiniTable {
    const MINI_TABLE: *const upb_MiniTable;
}
