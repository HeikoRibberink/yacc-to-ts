/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

/* This module provides functions and types to convert to and transform
* tree-sitter grammars. */

module tree-sitter

import exit
import repr
import cfg
import util

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

// Whether `node` may match empty.
pub fun node/matches-empty(node : node) : div bool
  match node
    Token -> False
    Seq(nodes) -> map(nodes, node/matches-empty).foldl(True, (&&))
    Optional -> True
    Repeat -> True
    Repeat1(node) -> node.matches-empty
    Choice(nodes) -> nodes.find(matches-empty).is-just

pub extend type body
  TS(node : node)

fun variant/completely-nullable(variant : list<token>, nullables : list<string>) : bool
  variant.all fn(v)
    match v
      Name(t) -> nullables.contains(t)
      Raw -> False

fun variant/treesitter(variant : list<token>)
  val nullables = implicit-nullables
  if variant.completely-nullable(nullables) then
    variant.map-indexed fn(i, token)
      val (left, Cons(cur, right)) = variant.list/split(i)
      Seq(left.map(Optional.o(Token)) ++ [Token(cur)] ++ right.map(Optional.o(Token)))
  else
    [Seq(
      variant.map fn(token)
        match token
          t as Name(tname) | nullables.contains(tname) ->
            Optional(Token(t))
          t -> Token(t)
    )]

fun variants/treesitter(variants : list<list<token>>) : _ node
  Choice(
    variants.map fn(variant)
      variant.variant/treesitter
    .concat
  )

pub effect val implicit-nullables : list<string>

// Convert a body to a tree-sitter node.
pub fun body/treesitter(rule : rule) : _ node
  // Depending on the type of body, we apply a different transformation.
  match rule.body
    Cfg(variants) ->
      // The right side of a CFG production rule becomes a choice of sequences.
      variants.variants/treesitter
    LeftRec(starts, repeats) ->
      // Whenever the rule is completely nullable, we must add all variants
      // obtained by removing the rule.
      val starts-choice = if implicit-nullables.contains(rule.name) then
        (starts ++ repeats).treesitter
      else
        starts.treesitter
      val repeats-choice = repeats.treesitter
      Seq([starts-choice, Repeat(repeats-choice)])
    RightRec(repeats, ends) ->
      val repeats-choice = repeats.treesitter
      val ends-choice = if implicit-nullables.contains(rule.name) then
        (ends ++ repeats).treesitter
      else
        ends.treesitter
      Seq([Repeat(repeats-choice), ends-choice])
    TS(node) -> node

// Show a rule by converting it to a tree-sitter string.
pub fun rule/show(rule : rule) : _ string
  rule.name ++ ": ($) => " ++ rule.treesitter.show() ++ ","

// Converts a list of rules to a tree-sitter string. 
pub fun rules/show(rules : list<rule>) : _ string
  rules.map(rule/show).join-end("\n")

// Recursively apply all transformations to the tree-sitter representation of body.
pub fun ts/transform-all(name : string, body : body) : _ body
  val root = Rule(name, body).treesitter
  val opts = [
    choice-dedup, elim-empty, transform-opt, elim-single-choice, elim-single-seq, flatten-seqseq, transform-repeat1, elim-opt
  ]
  // Sequentially apply the optimizations at every node.
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
    n -> n

// Remove duplicates inside a Choice.
fun node/choice-dedup(node : node) : div node
  match node
    Choice(nodes) -> Choice(nodes.dedup) 
    n -> n

// Transform a single choice into its inner node.
fun node/elim-single-choice(node : node) : node
  match node
    Choice([inner]) -> 
      inner
    n -> n

// Transform a unit sequence into its inner node.
fun node/elim-single-seq(node : node) : node
  match node
    Seq([inner]) ->
      inner
    n -> n

// Remove empty nodes from a sequence.
// NOTE: does nothing after `cfg/without-nullables`.
fun node/elim-empty(node : node) : div node
  match node
    Seq(nodes) -> Seq(nodes.filter fn(n) {!n.is-empty})
    n -> n

// Flatten a Seq inside another Seq into the outer sequence.
fun node/flatten-seqseq(node : node) : div node
  match node
    Seq(seq) ->
      seq.map fn(inner-node)
        match inner-node
          Seq(inner-seq) -> inner-seq
          _ -> [inner-node]
      .concat.Seq
    n -> n

// Transform Seq(a, Repeat(a)) to Repeat1(a)
fun node/transform-repeat1(node : node) : div node
  match node
    Seq([a, Repeat(b)]) ->
      if a == b then
        Repeat1(a)
      else
        node
    n -> n

// If e already matches empty, transforms `Optional(e)` to just `e`.
// NOTE: does nothing after `cfg/without-nullables`.
fun node/elim-opt(node : node) : div node
  match node
    Optional(e) -> if e.matches-empty then
        e
      else
        Optional(e)
    n -> n


// Return the names of the rules that match empty.
pub fun ts/find-empties(rules : list<rule>) : _ list<string>
  rules.filter-map fn(rule)
    val root = rule.treesitter
    if root.matches-empty then
      Just(rule.name)
    else
      Nothing
