module tree-sitter

import std/core/undiv
import exit

fun is-suffix(xs : list<a>, suff : list<a>, ?(==) : (a, a) -> bool) : bool
  if xs == suff then
    True
  else match xs
    Nil -> False
    Cons(_, tail) -> is-suffix(tail, suff)

fun remove-suffix(xs : list<a>, suff : list<a>, ?(==) : (a, a) -> bool) : list<a>
  if xs == suff then
    Nil
  else match xs
    Nil -> Nil
    Cons(x, tail) -> Cons(x, remove-suffix(tail, suff))

fun list-eq(a : list<a>, b : list<a>, ?(==) : (a, a) -> e bool) : e bool
  match (a, b)
    (Nil, Nil) -> True
    (Cons(x, xs), Cons(y, ys)) -> (x == y) && list-eq(pretend-decreasing(xs), pretend-decreasing(ys))
    _ -> False

pub value struct rule
  name : string
  body : body

// The different kinds of bodies we can have
pub type body
  Cfg(variants : list<list<string>>)
  LeftRec(start-variants : list<list<string>>, repeat : list<string>)
  TS(node : node)

// A treesitter node
pub type node
  Name(name : string)
  Raw(str : string)
  Seq(nodes : list<node>)
  Optional(node : node)
  Repeat(node : node)
  Repeat1(node : node)
  Choice(nodes : list<node>)
  

pub fun strings/treesitter(strings : list<string>) : list<node>
  strings.map(Name)

pub fun body/treesitter(body : body) : node
  match body
    Cfg(variants) ->
      Choice(variants.map fn(v) {v.treesitter.Seq})
    LeftRec(starts, repeat) ->
      Choice(
        starts.map(treesitter).map fn(variant)
          val nodes = variant ++ [Repeat(Seq(treesitter(repeat)))]
          Seq(nodes)
      )
    TS(node) -> node
        
  
pub fun node/show(node : node) : div string
  with pretend-no-div
  match node
    Name(name) -> "$." ++ name
    Raw(str) -> "\"" ++ str ++ "\""
    Seq(nodes) -> "seq(" ++ nodes.map(show).join-end(", ") ++ ")"
    Optional(node) -> "optional(" ++ node.show ++ ")"
    Repeat(node) -> "repeat(" ++ node.show ++ ")"
    Repeat1(node) -> "repeat1(" ++ node.show ++ ")"
    Choice(nodes) -> "choice(" ++ nodes.map(show).join-end(", ") ++ ")"

pub fun node/(==)(n1 : node, n2 : node) : _ bool
  match (n1, n2)
    (Name(a), Name(b)) -> a == b
    (Seq(a), Seq(b)) -> list-eq(a, b)
    (Optional(a), Optional(b)) -> a == b
    (Repeat(a), Repeat(b)) -> a == b
    (Repeat1(a), Repeat1(b)) -> a == b
    (Choice(a), Choice(b)) -> list-eq(a, b)
    _ -> False

pub fun nodes/is-empty(nodes : list<node>) : div bool
  match nodes
    Nil -> True
    nodes -> map(nodes, node/is-empty).foldl(True, (&&))
  

pub fun node/is-empty(node : node) : div bool
  match node
    Name -> False
    Raw -> False
    Seq(nodes) -> nodes.nodes/is-empty
    Optional(node) -> node.is-empty
    Repeat(node) -> node.is-empty
    Repeat1(node) -> node.is-empty
    Choice(nodes) -> nodes.nodes/is-empty

// Optimizations

// Transform a left recursive cfg 
pub fun cfg/transform-leftrec(name : string, body : body) : exit<()> body
  match body
    Cfg(variants) ->
      val recs = variants.filter-map fn(v)
        match v
          Cons(first, tail) | first == name -> Just(tail)
          _ -> Nothing
      val nonrecs = variants.filter fn(v)
        match v
          Cons(first, _tail) -> first != name
          _ -> True
      match recs
        [repeat] -> LeftRec(nonrecs, repeat)
        _ -> exit(())
    _ -> exit(())

fun ts/transform-opt(node : node) : div node
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

pub fun node/transform-opt(name : string, body : body) : <exit<()>,div> body
  match body
    TS(node) -> TS(ts/transform-opt(node))
    _ -> exit(())
