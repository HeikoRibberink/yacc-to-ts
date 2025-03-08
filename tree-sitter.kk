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

// Returns whether `ex` in `xs`.
fbip fun contains(xs : list<a>, ex : a, ^?(==) : (a, a) -> bool) : bool
  match xs
    Cons(x, _) | ex == x -> True
    Cons(_, xs) -> xs.contains(ex)
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
  LeftRec(start-variants : list<list<token>>, repeat-variants : list<list<token>>)
  RightRec(repeat-variants: list<list<token>>, end-variants: list<list<token>>)
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
    LeftRec(starts, repeats) ->
      val starts-tokens = starts.map(fn(s) {Seq(s.map(Token))})
      val repeats-tokens = repeats.map(fn(s) {Seq(s.map(Token))})
      Seq([Choice(starts-tokens), Repeat(Choice(repeats-tokens))])
    RightRec(repeats, ends) ->
      val repeats-tokens = repeats.map(fn(s) {Seq(s.map(Token))})
      val ends-tokens = ends.map(fn(s) {Seq(s.map(Token))})
      Seq([Repeat(Choice(repeats-tokens)), Choice(ends-tokens)])
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

// Whether `node` may match empty.
pub fun node/matches-empty(node : node) : div bool
  match node
    Token -> False
    Seq(nodes) -> map(nodes, node/matches-empty).foldl(True, (&&))
    Optional -> True
    Repeat -> True
    Repeat1(node) -> node.matches-empty
    Choice(nodes) -> nodes.find(matches-empty).is-just

/* Rule-level optimizations and transformations. */

// Optimize a list of rules.
pub fun optimize(rules : list<rule>) : _ list<rule>
  // The optimizations. Note that we apply the tree-sitter transformations twice.
  val opts = [transform-leftrec, transform-rightrec, ts/transform-all, ts/transform-all]
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
pub fun cfg/transform-leftrec(name : string, body : body) : _ body
  // Only Cfg can be transformed; all others are not applicable.
  match body
    Cfg(variants) ->
      // Categorize the rules:
      val categorized = variants.map fn(v)
        match v
          // Recursive rules have their self-reference removed, and are put right.
          Cons(first, tail) | first == Name(name) -> (Nothing, Just(tail))
          // Non-recursive rules are put left.
          _ -> (Just(v), Nothing)
      // Due to the (maybe, maybe)-tuple, we can simply unzip and concat-maybe.
      val (nonrecs, recs) = categorized.unzip.map(concat-maybe)
      if is-nil(recs) then exit(())
      LeftRec(nonrecs, recs)
    _ -> exit(())

// Transform a right recursive cfg. 
pub fun cfg/transform-rightrec(name : string, body : body) : _ body
  // Only Cfg can be transformed; all others are not applicable.
  match body
    Cfg(variants) ->
      // Categorize the rules:
      val categorized = variants.map fn(v)
        match v.split(length(v) - 1)
          // Recursive rules have their self-reference removed, and are put right.
          (front, Cons(last, Nil)) | last == Name(name) -> (Nothing, Just(front))
          // Non-recursive rules are put left.
          _ -> (Just(v), Nothing)
      // Due to the (maybe, maybe)-tuple, we can simply unzip and concat-maybe.
      val (nonrecs, recs) = categorized.unzip.map(concat-maybe)
      if is-nil(recs) then exit(())
      RightRec(recs, nonrecs)
    _ -> exit(())

/* Tree-sitter node-level optimizations and transformation. */

// Recursively apply all transformations to the tree-sitter representation of body.
pub fun ts/transform-all(name : string, body : body) : _ body
  val root = body.treesitter
  val opts = [transform-opt, elim-empty, elim-single-choice, elim-single-seq, elim-empty, flatten-seqseq, transform-repeat1, elim-opt]
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

fun node/elim-opt(node : node) : div node
  match node
    Optional(e) -> if e.matches-empty then
        e
      else
        Optional(e)
    _ -> node
    

// Transforms `node` such that it does not match empty. More specifically:
// Let `n` be an arbitrary node, then
// 1. `make-nonempty(n)` does not match empty, and
// 2. if `n` does not match empty, then 
//      `make-nonempty(n) == n`, 
//    else 
//      `n` matches empty, and `Optional(make-nonempty(n)) == n`
fun node/make-nonempty(node : node) : _ node
  // Notes:
  // Let a == b mean that a and b match exactly the same language.
  // Let n be a node that matches empty.
  // We wish to define a function f such that:
  // f(n) does not match empty, and
  // Optional(f(n)) == n
  
  // Let n, n1, ..., nk, ..., nl be arbitrary nodes, and,
  // Let e, e1, ..., ek, ..., el be arbitrary nodes that match empty, and,
  // Let m, m1, ..., mk, ..., ml be arbitrary nodes that do not match empty.
  // We can define f as follows:
  // 1. f(m) == m
  // Rule 1 catches all cases except:
  // 2. f(Seq(e1, e2, ..., ek)) == Seq(f(e1), e2, ..., ek)
  // 3. f(Optional(n)) == f(n)
  // 4. f(Repeat(n)) == Repeat1(f(n))
  // 5. f(Repeat1(e)) == Repeat1(f(e))
  // 6. f(Choice(n1, ..., nk)) == Choice(f(n1), ..., f(nk))
  if !node.matches-empty then
    node // Rule 1
  else match node
    // Rule 2; `nodes` must be nonempty, and every element must match empty.
    Seq(Cons(e, es)) -> Seq(Cons(make-nonempty(e), es))
    Optional(n) -> make-nonempty(n)
    Repeat(n) -> Repeat1(make-nonempty(n))
    Repeat1(e) -> Repeat1(make-nonempty(e))
    Choice(choices) -> Choice(choices.map(make-nonempty))
    _ -> throw("This should be impossible due to the previous if statement.")

/* Whole grammar-level optimizations. */

// Return the names of the rules that match empty.
fun find-empties(rules : list<rule>) : div list<string>
  rules.filter-map fn(Rule(name, body))
    val root = body.treesitter
    if root.matches-empty then
      Just(name)
    else
      Nothing

// Find all empty rules, transform them such that they are non-empty, and make
// each reference to them optional.
pub fun transform-empties(rules : list<rule>) : _ list<rule>
  // First, find which rules match empty.
  val prev-empties = find-empties(rules)
  // Then, we transform every token referencing an empty rule to Optional(token)
  rules.map fn(Rule(name, body))
    val root = body.treesitter.make-nonempty
    val empties-replaced = root.map-bottom-up fn(node)
      match node
        tok as Token(Name(refname)) ->
          if prev-empties.contains(refname) then
            Optional(Token(Name(refname)))
          else
            tok
        n -> n
    Rule(name, TS(empties-replaced))

// Transform rules until no empty rules exist.
pub fun remove-empties(rules : list<rule>) : _ list<rule>
  var modified := rules
  while {modified.find-empties.is-cons}
    modified := modified.transform-empties
  modified
