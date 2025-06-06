/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

/* Module containing early-exit constructs. */

module exit

pub effect exit<a>
  final ctl exit(res : a) : b
  
// Allows exiting with an early result using `exit(result)`.
pub fun early-exit(action)
  with handler
    final ctl exit(res) res
  action()

// If `exit` is called, `Nothing` is returned, otherwise the result is wrapped in `Just`.
pub fun exit-nothing(action)
  with handler
    final ctl exit(_) Nothing
  action().Just

pub fun else-exit-with(x : maybe<a>, other : b) : exit<b> a
  match x
    Just(x) -> x
    Nothing ->
      exit(other)

pub fun else-exit(x : maybe<a>) : exit<()> a
  x.else-exit-with(())

// If `action` returns `False`, exit
pub fun assert(action : () -> e bool) : <exit<()>|e> ()
  val b = mask<exit<()>> {action()}
  if b then
    ()
  else
    exit(())
  
