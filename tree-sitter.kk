module tree-sitter

import std/core/undiv
import exit

fun list-eq(a : list<a>, b : list<a>, ?(==) : (a, a) -> e bool) : e bool
  match (a, b)
    (Nil, Nil) -> True
    (Cons(x, xs), Cons(y, ys)) -> (x == y) && list-eq(pretend-decreasing(xs), pretend-decreasing(ys))
    _ -> False

pub value struct rule
  name : string
  body : body

pub fun rule/show(rule : rule) : div string
  val Rule(name, body) = rule
  name ++ ": ($) => " ++ treesitter(body).show() ++ ","

pub fun rules/show(rules : list<rule>) : div string
  
  rules.map(rule/show).join-end("\n")
  

// The different kinds of bodies we can have
pub type body
  Cfg(variants : list<list<token>>)
  LeftRec(start-variants : list<list<token>>, repeat : list<token>)
  TS(node : node)

pub value type token
  Name(name : string)
  Raw(str : string)

pub fun token/show(token : token) : string
  match token
    Name(name) -> "$." ++ name
    Raw(str) -> "\'" ++ str ++ "\'" 

pub fun token/(==)(a : token, b : token) : bool
  match (a, b)
    (Name(n1), Name(n2)) -> n1 == n2
    (Raw(n1), Raw(n2)) -> n1 == n2
    _ -> False

// A treesitter node
pub type node
  Token(token : token)
  Seq(nodes : list<node>)
  Optional(node : node)
  Repeat(node : node)
  Repeat1(node : node)
  Choice(nodes : list<node>)

pub fun body/treesitter(body : body) : node
  match body
    Cfg(variants) ->
      Choice(variants.map fn(v) {v.map(Token).Seq})
    LeftRec(starts, repeat) ->
      val starts_tokens = starts.map(fn(s) {s.map(Token).Seq})
      Seq([Choice(starts_tokens), Repeat(Seq(repeat.map(Token)))])
    TS(node) -> node
  
  
pub fun node/show(node : node) : div string
  match node
    Token(token) -> token.show
    Seq(nodes) -> "seq(" ++ nodes.map(show).join-end(",") ++ ")"
    Optional(node) -> "optional(" ++ node.show ++ ")"
    Repeat(node) -> "repeat(" ++ node.show ++ ")"
    Repeat1(node) -> "repeat1(" ++ node.show ++ ")"
    Choice(nodes) -> "choice(" ++ nodes.map(show).join-end(",") ++ ")"

pub fun node/(==)(n1 : node, n2 : node) : _ bool
  match (n1, n2)
    (Token(a), Token(b)) -> a == b
    (Seq(a), Seq(b)) -> list-eq(a, b)
    (Optional(a), Optional(b)) -> a == b
    (Repeat(a), Repeat(b)) -> a == b
    (Repeat1(a), Repeat1(b)) -> a == b
    (Choice(a), Choice(b)) -> list-eq(a, b)

pub fun nodes/is-empty(nodes : list<node>) : div bool
  match nodes
    Nil -> True
    nodes -> map(nodes, node/is-empty).foldl(True, (&&))
  

pub fun node/is-empty(node : node) : div bool
  match node
    Token -> False
    Seq(nodes) -> nodes.nodes/is-empty
    Optional(node) -> node.is-empty
    Repeat(node) -> node.is-empty
    Repeat1(node) -> node.is-empty
    Choice(nodes) -> nodes.nodes/is-empty

// Rule-level optimizations and transformations.

// Optimize a rule
pub fun optimize(rules : list<rule>) : _ list<rule>
  val opts = [transform-leftrec, ts/transform-all]
  rules.map fn(rule)
    opts.foldl(rule) fn(rule', opt)
      with final ctl exit(_) 
        rule'
      val optimized = opt(rule'.name, rule'.body)
      val new-rule = rule'(body = optimized)
      new-rule

// Transform a left recursive cfg 
pub fun cfg/transform-leftrec(name : string, body : body) : exit<()> body
  match body
    Cfg(variants) ->
      val recs = variants.filter-map fn(v)
        match v
          Cons(first, tail) | first == Name(name) -> Just(tail)
          _ -> Nothing
      val nonrecs = variants.filter fn(v)
        match v
          Cons(first, _tail) -> first != Name(name)
          _ -> True
      match recs
        [repeat] -> LeftRec(nonrecs, repeat)
        _ -> exit(())
    _ -> exit(())

// Tree-sitter node-level optimizations and transformation.

pub fun ts/transform-all(name : string, body : body) : _ body
  val root = body.treesitter
  val opts = [transform-opt, elim-empty, elim-single-choice, elim-single-seq, elim-empty]
  fun apply-opts(node)
    opts.foldl(node) fn(node', opt)
      opt(node')
  val root' = root.map-bottom-up(apply-opts)
  TS(root')

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
