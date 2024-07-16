// Protocol Buffers - Google's data interchange format
// Copyright 2024 Google LLC.  All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

//! Traits that are implemeted by codegen types.

use crate::{MutProxied, MutProxy, ParseError, Proxied, SerializeError, ViewProxy};
use std::fmt::Debug;

/// A trait that all generated owned message types implement.
pub trait Message: Proxied
  // Create traits:
  + Parse + Default
  // Read traits:
  + Debug + Serialize
  // Write traits:
  // TODO: Msg should impl Clear.
  + ClearAndParse
  // Thread safety:
  + Send + Sync {}

/// A trait that all generated message views implement.
pub trait MessageView<'msg>: ViewProxy<'msg>
    // Read traits:
    + Debug + Serialize
    // Thread safety:
    + Send + Sync {}

/// A trait that all generated message muts implement.
pub trait MessageMut<'msg>: MutProxy<'msg>
    // Read traits:
    + Debug + Serialize
    // Write traits:
    // TODO: MsgMut should impl Clear and ClearAndParse.
    // Thread safety:
    + Sync
where
    <Self as ViewProxy<'msg>>::Proxied: MutProxied,
{
}

//////////////////////////////////////////////////////////////////////////////////////////
// Operations related to constructing a message. Only owned messages implement
// these traits.
//////////////////////////////////////////////////////////////////////////////////////////

pub trait Parse: Sized {
    fn parse(serialized: &[u8]) -> Result<Self, ParseError>;
}

//////////////////////////////////////////////////////////////////////////////////////////
// Operations related to reading some aspect of a message. Owned messages,
// views, and muts all implement these traits.
//////////////////////////////////////////////////////////////////////////////////////////

pub trait Serialize {
    fn serialize(&self) -> Result<Vec<u8>, SerializeError>;
}

//////////////////////////////////////////////////////////////////////////////////////////
// Operations related to mutating a message. Owned messages and muts implement
// these traits.
//////////////////////////////////////////////////////////////////////////////////////////
pub trait Clear {
    fn clear(&mut self);
}

pub trait ClearAndParse {
    fn clear_and_parse(&mut self, data: &[u8]) -> Result<(), ParseError>;
}
