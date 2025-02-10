/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

/* Main file of the Yacc to tree-sitter converter. */

import std/os/env
import std/os/file
import std/os/path
import std/text/parse
import indexed
import parser

val usage = "Yacc to tree-sitter converter\nVersion 1.0.0\nUsage:\n  yacc-to-ts <input-file> <output-file>"

val left-comment = "/*"
val right-comment = "*/"

// Finds the delimited grammar.
fun find-grammar(text)
  match text.split("%%")
    [_before, grammar, _after] -> grammar
    _ -> throw("Input file doesn't correctly mark the start and end of the grammar.")

// Remove all `text` between each occurrence of `left` and `right`
fun trim-between(text, left, right)
  // We split on the left seperator and the right seperator
  val split = text
    .split(left)
    .map fn(s) 
      val split = s.split(right)
      split
    .concat()
  // Now split is a sequence of code, comment, code, comment, ...
  // Therefore, we remove every second element of split, and join it into a
  // single string
  with index-in(split)
  split
  .filter fn(_)
    with i <- loop-increment
    is-even(i)
  .join

fun trim-line-comments(text)
  // Split the text by lines, and remove everything after and including the
  // line comment token, then join the text back together.
  text
  .lines
  .map fn(l : string)
    val s : list<string> = l.split(string(['/', '/']))
    s[0].unjust
  .join("\n")
  
// Trim `grammar` by removing all comments and semantic code blocks
fun trim-grammar(grammar)
  grammar
  .trim-between(left-comment, right-comment)
  .trim-line-comments

fun parse-rules(grammar)
  match parse(grammar.slice, prods)
    ParseOk(res, _tail) ->
      Just(res)
    ParseError(msg, tail) ->
      println("Parsing failed with `" ++ msg ++ "`, with the following left to parse: \n\n" ++ string(tail))
      Nothing

  
fun main()
  // Get and check the arguments.
  val args = get-args()
  assert(
    "Expected exactly 2 arguments, but " ++ length(args).show 
    ++ " were provided\n" ++ usage,
    length(args) == 2
  )
  val in-path = args[0].unjust.path
  val out-path = args[1].unjust.path
  
  // Read the file.
  val in-file = in-path.read-text-file
  // Trim all unrelated parts.
  val grammar = in-file.find-grammar
  val trimmed = grammar.trim-grammar
  // Parse the file.
  val parsed = trimmed.parse-rules.unjust
  // Convert and write the tree-sitter grammar.
  val treesitter = parsed.treesitter
  out-path.write-text-file(treesitter)
