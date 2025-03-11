/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

module util
import std/core/undiv

// Same as `list/(==)`, but allows arbitrary effects for the `(==)` function.
// Necessary because `node/(==)` has the `div` effect. 
pub fun list-eq(a : list<a>, b : list<a>, ?(==) : (a, a) -> e bool) : e bool
  match (a, b)
    (Nil, Nil) -> True
    (Cons(x, xs), Cons(y, ys)) -> (x == y) && list-eq(pretend-decreasing(xs), pretend-decreasing(ys))
    _ -> False

// Returns whether `ex` in `xs`.
pub fun contains(xs : list<a>, ex : a, ^?(==) : (a, a) -> e bool) : e bool
  match xs
    Cons(x, xs) -> if ex == x then True else xs.contains(ex)
    _ -> False

// Returns a list with all duplicate elements removed.
pub fun dedup(xs : list<a>, ^?(==) : (a, a) -> e bool) : e list<a>
  match xs
    Nil -> Nil
    Cons(x, xs) -> if xs.contains(x) then
      xs
    else
      Cons(x, xs)

pub effect choice
  ctl choice() : bool

pub fun choice-all(action)
  with handler
    ctl choice() resume(False) ++ resume(True)
    return(x) [x]
  action()
