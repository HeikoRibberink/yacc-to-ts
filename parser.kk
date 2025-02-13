/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

/* Yacc context-free grammar parser and tree-sitter generater. */
module parser

import std/text/parse
import std/core/undiv
import tree-sitter

/* Additional parser combinators */

// Zero or more of `p`, seperated by `sep`
fun many-seperated(sep, p)
  optional([])
    many1-seperated(sep, p)

// One or more of `p`, seperated by `sep`
fun many1-seperated(sep, p)
  Cons(p(),
    many
      sep()
      p()
  )

// A character in a C identifier.
fun c-id-char()
  chars-are("c-id-char") fn(c)
    is-alpha-num(c) || c == '_'

/* Helper functions */

/* Parse tree types and functions */

// A single token identifier.
// This is defined to be the same as a C identifier. For simplicity, we also
// allow starting with numbers here.
fun id()
  Name(string(c-id-char()))
  
// A raw string token.
fun rawstring()
  char('\'')
  val r = none-of-many1("\'")
  char('\'')
  Raw(r)

// A token in a variant.
fun token()
  choose([id,rawstring])

fun code(slice : sslice, balance : int, acc) : (sslice, bool, list<char>)
  if balance == 0 then
    (slice, True, acc.reverse)
  else match slice.next
    Just((c, rest)) -> match c
      '{' -> code(pretend-decreasing(rest), balance + 1, Cons(c, acc))
      '}' -> code(pretend-decreasing(rest), balance - 1, Cons(c, acc))
      c -> code(pretend-decreasing(rest), balance, Cons(c, acc)) 
    Nothing -> (slice, balance == 0, acc.reverse)
          
      
// A single block of semantic code.
// Just like in Yacc, as long as the braces are balanced, a code block may
// contain an arbitrary string.
fun code-block()
  char('{')
  satisfy-fail("code block") fn(slice)
    match code(slice, 1, ['{'])
      (slice', True, str) -> Just((str, slice'))
      _ -> Nothing

// The parts in a variant.
// This is necessary because semantic code blocks may be placed anywhere inside of a
// rule.
fun variant-part() : _ maybe<token>
  fun token-maybe()
    Just(token())
  fun code-block-maybe()
    code-block()
    Nothing
  choose([
    token-maybe,
    code-block-maybe,
  ])

// A variant of a production rule.
fun variant() : _ list<token>
  val maybe-variants = many-seperated(whitespace, variant-part)
  val result = maybe-variants.concat-maybe
  result

// The right side of a production rule.
fun variants() : _ list<list<token>>
  fun sep()
    whitespace0()
    char('|')
    whitespace0()
  many1-seperated(sep, variant)

// A single production rule.
fun prod() : _ rule
  val Name(id) = id()
  whitespace0()
  char(':')
  whitespace0()
  val variants = variants()
  whitespace0()
  char(';')
  Rule(id, Cfg(variants))

// Multiple production rules.
pub fun prods() : _ list<rule>
  whitespace0()
  many
    val p = prod()
    whitespace0()
    p
