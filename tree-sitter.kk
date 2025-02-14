/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

/* This module contains code intended for representing a Yacc CFG, and for
* optimizing and converting it to a valid Tree-sitter grammar. */

module tree-sitter

import std/core/undiv
import exit

// Same as `list/(==)`, but allows arbitrary effects for the `(==)` function.
// Necessary because `node/(==)` has the `div` effect. 
fun list-eq(a : list<a>, b : list<a>, ?(==) : (a, a) -> e bool) : e bool
  match (a, b)
    (Nil, Nil) -> True
    (Cons(x, xs), Cons(y, ys)) -> (x == y) && list-eq(pretend-decreasing(xs), pretend-decreasing(ys))
    _ -> False

// Production rule with an arbitrary body.
pub value struct rule
  name : string
  body : body

// Converts a rule to a tree-sitter string.
pub fun rule/show(rule : rule) : div string
  val Rule(name, body) = rule
  name ++ ": ($) => " ++ treesitter(body).show() ++ ","

// Converts a list of rules to a tree-sitter string. 
pub fun rules/show(rules : list<rule>) : div string
  rules.map(rule/show).join-end("\n")
  

// Different kinds of rule bodies.
// This is used to present a unified type for CFG and TS representations, but
// also for simplified, intermediate representations of either variant.
pub type body
  Cfg(variants : list<list<token>>)
  LeftRec(start-variants : list<list<token>>, repeat : list<token>)
  TS(node : node)

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

// A node in a tree-sitter AST.
// All the names except Token are analogous to their tree-sitter counterpart.
pub type node
  // A single token.
  Token(token : token)
  // A sequence of nodes.
  Seq(nodes : list<node>)
  // An optional node.
  Optional(node : node)
  // Zero or more repetitions of `node`.
  Repeat(node : node)
  // One or more repetitions of `node`.
  Repeat1(node : node)
  // A choice between nodes.
  Choice(nodes : list<node>)

// Convert a body to a tree-sitter node.
pub fun body/treesitter(body : body) : node
  // Depending on the type of body, we apply a different transformation.
  match body
    Cfg(variants) ->
      // The right side of a CFG production rule becomes a choice of sequences.
      Choice(variants.map fn(v) {Seq(v.map(Token))})
    LeftRec(starts, repeat) ->
      val starts_tokens = starts.map(fn(s) {Seq(s.map(Token))})
      Seq([Choice(starts_tokens), Repeat(Seq(repeat.map(Token)))])
    TS(node) -> node
  
  
// Convert a tree-sitter node to a tree-sitter string.
pub fun node/show(node : node) : div string
  match node
    Token(token) -> token.show
    Seq(nodes) -> "seq(" ++ nodes.map(show).join-end(",") ++ ")"
    Optional(node) -> "optional(" ++ node.show ++ ")"
    Repeat(node) -> "repeat(" ++ node.show ++ ")"
    Repeat1(node) -> "repeat1(" ++ node.show ++ ")"
    Choice(nodes) -> "choice(" ++ nodes.map(show).join-end(",") ++ ")"

pub fun node/(==)(n1 : node, n2 : node) : div bool
  match (n1, n2)
    (Token(a), Token(b)) -> a == b
    (Seq(a), Seq(b)) -> list-eq(a, b)
    (Optional(a), Optional(b)) -> a == b
    (Repeat(a), Repeat(b)) -> a == b
    (Repeat1(a), Repeat1(b)) -> a == b
    (Choice(a), Choice(b)) -> list-eq(a, b)
    _ -> False

// Whether `node` contains no tokens.
pub fun node/is-empty(node : node) : div bool
  match node
    Token -> False
    Seq(nodes) -> nodes.nodes/is-empty
    Optional(node) -> node.is-empty
    Repeat(node) -> node.is-empty
    Repeat1(node) -> node.is-empty
    Choice(nodes) -> nodes.nodes/is-empty

// Whether a list of nodes contains no tokens.
pub fun nodes/is-empty(nodes : list<node>) : div bool
  map(nodes, node/is-empty).foldl(True, (&&))

/* Rule-level optimizations and transformations. */

// Optimize a list of rules.
pub fun optimize(rules : list<rule>) : _ list<rule>
  val opts = [transform-leftrec, ts/transform-all, ts/transform-all]
  // We optimize rule by rule.
  rules.map fn(rule)
    // Optimize by sequentially applying each optimization.
    opts.foldl(rule) fn(rule', opt)
      // When an optimization is not applicable, return the unmodified rule.
      with final ctl exit(_) 
        rule'
      val optimized = opt(rule'.name, rule'.body)
      val new-rule = rule'(body = optimized)
      new-rule

// Transform a left recursive cfg. 
pub fun cfg/transform-leftrec(name : string, body : body) : exit<()> body
  // Only Cfg can be transformed; all others are not applicable.
  match body
    Cfg(variants) ->
      // Keep only the tails of the variants that are tail-recursive.
      val recs = variants.filter-map fn(v)
        match v
          Cons(first, tail) | first == Name(name) -> Just(tail)
          _ -> Nothing
      // Keep only those variants that are not tail-recursive.
      val nonrecs = variants.filter fn(v)
        match v
          Cons(first, _tail) -> first != Name(name)
          _ -> True
      // This transformation is currently only applicable for a single left
      // recursive variant.
      // TODO: improve this rule by allowing multiple variants in the
      // repetition, which are then converted to a Repeat(Choice(v1, ..., vN))
      match recs
        [repeat] -> LeftRec(nonrecs, repeat)
        _ -> exit(())
    _ -> exit(())

/* Tree-sitter node-level optimizations and transformation. */

// Recursively apply all transformations to the tree-sitter representation of body.
pub fun ts/transform-all(name : string, body : body) : _ body
  val root = body.treesitter
  val opts = [transform-opt, elim-empty, elim-single-choice, elim-single-seq, elim-empty, flatten-seqseq, transform-repeat1]
  fun apply-opts(node)
    opts.foldl(node) fn(node', opt)
      opt(node')
  val root' = root.map-bottom-up(apply-opts)
  TS(root')

// Bottom-up recursively apply a mapping `f` to the tree-sitter AST `node`.
fun nodes/map-bottom-up(node : node, f : node -> <div|e> node) : <div|e> node
  val node' = match node
    Token(token) -> Token(token)
    Seq(nodes) -> Seq(nodes.map fn(n) {n.map-bottom-up(f)})
    Optional(node) -> Optional(node.map-bottom-up(f))
    Repeat(node) -> Repeat(node.map-bottom-up(f))
    Repeat1(node) -> Repeat1(node.map-bottom-up(f))
    Choice(nodes) -> Choice(nodes.map fn(n) {n.map-bottom-up(f)})
  f(node')

// Transform a choice with an empty possibility to to an optional.
fun node/transform-opt(node : node) : div node
  match node
    Choice(nodes) -> 
      val filtered = nodes.filter fn(n)
        !n.is-empty
      if filtered.length < nodes.length then
        // An empty rule was filtered out, so we mark it optional
        Optional(Choice(filtered))
      else
        // Else, it should be equal and we can use it
        Choice(filtered)
    node -> node

fun node/elim-single-choice(node : node) : node
  match node
    Choice(Cons(node', Nil)) -> 
      node'
    _ -> node

fun node/elim-single-seq(node : node) : node
  match node
    Seq(Cons(node', Nil)) ->
      node'
    _ -> node

fun node/elim-empty(node : node) : div node
  match node
    Seq(nodes) -> Seq(nodes.filter fn(n) {!n.is-empty})
    _ -> node

fun node/flatten-seqseq(node : node) : div node
  match node
    Seq(seq) ->
      seq.map fn(inner-node)
        match inner-node
          Seq(inner-seq) -> inner-seq
          _ -> [inner-node]
      .concat.Seq
    _ -> node

fun node/transform-repeat1(node : node) : div node
  match node
    Seq(Cons(a, Cons(Repeat(b), Nil))) ->
      if a == b then
        Repeat1(a)
      else
        node
    _ -> node
