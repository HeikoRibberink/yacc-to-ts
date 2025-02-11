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

// Appends `sep` to each string in `xs` and joins them into a single string.
fun join-append(xs : list<string>, sep : string) : string
  xs.foldl("") fn(s, x) s ++ x ++ sep

/* Parse tree types and functions */

// A token in the right side of a production rule.
pub value type token
  // Raw token, delimited by single quotes.
  Raw(s : string)
  // A named (non-)terminal.
  Name(name : string)

// Show a `token`.
pub fun token/show(t : token) : string
  match t
    Raw(s) -> "Raw(" ++ s ++ ")"
    Name(n) -> "Name(" ++ n ++ ")"

// Convert a `token` to a treesitter representation.
pub fun token/treesitter(t : token) : string
  match t
    Raw(s) -> "\"" ++ s ++ "\""
    Name(n) -> "$." ++ n

// A variant of a production rule.
pub value struct variant
  tokens : list<token>

// Show a `variant`.
pub fun variant/show(v : variant) : string
  v.tokens.show

// Convert a `variant` to a treesitter representation.
pub fun variant/treesitter(variant : variant) : string
  match variant.tokens
    [t] -> t.treesitter
    ts -> 
      "seq(" ++ ts.map(treesitter).join-append(", ") ++ ")"
    

// A production rule.
pub value struct production
  name : string
  variants : list<variant>

// Show a `production`.
pub fun production/show(p : production) : string
  "Production(" ++ p.name ++ ", " ++ p.variants.show ++ ")"

// Convert a `production` to a treesitter representation.
pub fun production/treesitter(p : production) : string
  // Whether there is an empty variant in the production.
  var has-empty : bool := False
  // The non-empty variants.
  val variants = 
    p.variants.filter fn(v)
      if v.tokens.is-empty then 
        has-empty := True
        False
      else
        True
  // Used to make the rule optional when necessary
  val (optional-start, optional-end) = 
    if has-empty then 
      ("optional(", ")") 
    else 
      ("", "")
  // The final tree-sitter rule.
  val body = 
    match variants
      [v] -> v.treesitter
      v ->
        "choice(\n" 
        ++ v.map(treesitter).map fn(s)
          "  " ++ s
        .join-append(",\n") 
        ++ ")"
  p.name ++ ": ($) => " ++ optional-start ++ body ++ optional-end

// Convert a `list<production>` to a treesitter representation.
// Use this to generate a full list of grammar rules from a successfull parse.
pub fun productions/treesitter(ps : list<production>) : string
  ps.map(treesitter).join-append(",\n")

/* Parser rules */

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
fun variant() : _ variant
  val maybe-variants = many-seperated(whitespace, variant-part)
  val result = Variant(maybe-variants.concat-maybe)
  result

// The right side of a production rule.
fun variants() : _ list<variant>
  fun sep()
    whitespace0()
    char('|')
    whitespace0()
  many1-seperated(sep, variant)

// A single production rule.
fun prod() : _ production
  val Name(id) = id()
  whitespace0()
  char(':')
  whitespace0()
  val vs = variants()
  whitespace0()
  char(';')
  Production(id, vs)

// Multiple production rules.
pub fun prods() : _ list<production>
  whitespace0()
  many
    val p = prod()
    whitespace0()
    p
