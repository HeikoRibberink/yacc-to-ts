/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

/* This module provides a base model for representing grammars. */

module repr
import util

// Production rule with an arbitrary body.
pub value struct rule
  name : string
  body : body

// Different kinds of rule bodies.
// This is used to present a unified type for CFG and TS representations, but
// also for simplified, intermediate representations of either variant.
pub open type body
  Cfg(variants : list<list<token>>)

// A terminal or nonterminal.
pub value type token
  // A named terminal or nonterminal token.
  Name(name : string)
  // A raw terminal token.
  Raw(str : string)

// Converts a token to a tree-sitter string.
pub fun token/show(token : token) : string
  match token
    Name(name) -> "$." ++ name
    Raw(str) -> "\'" ++ str ++ "\'" 

pub fun token/(==)(a : token, b : token) : bool
  match (a, b)
    (Name(n1), Name(n2)) -> n1 == n2
    (Raw(n1), Raw(n2)) -> n1 == n2
    _ -> False
