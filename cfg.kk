/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

/* This module provides functions for analyzing and improving CFGs. */

module cfg
import exit
import repr
import util

pub extend type body
  LeftRec(start-variants : list<list<token>>, repeat-variants : list<list<token>>)
  RightRec(repeat-variants: list<list<token>>, end-variants: list<list<token>>)

/* Whole-grammar level transformations. */

fun cfg/is-nullable(rule : rule, nullable-tokens : list<string>) : bool
  match rule.body
    Cfg(variants) -> variants.contains([]) ||
      variants.find fn(variant)
        variant.all fn(token)
          match token
            Raw -> False
            Name(tname) -> nullable-tokens.contains(tname)
      .is-just
    _ -> False

fun cfg/nullables(rules : list<rule>) : div list<string>
  var remaining := rules
  var nullables := []
  with early-exit
  while {True}
    val (new-nullables, remaining') = remaining.partition fn(rule)
      rule.is-nullable(nullables)
    remaining := remaining'
    nullables := new-nullables.map(name) ++ nullables
    if new-nullables.is-nil then
      exit(nullables)
  []

pub fun cfg/without-nullables(rules : list<rule>) : _ list<rule>
  // Find the nullable variables.
  val nullables : list<string> = rules.nullables

  rules.filter-map fn(Rule(name, body))
    val updated-variants = match body
      // Only works on CFG's, and throws an exception otherwise.
      Cfg(variants) ->
        variants.map fn(variant)
          // For each variant, we add every production obtained by removing one
          // or more nullable tokens.
          with choice-all
          variant.filter-map fn(token)
            match token
              Name(tname) | nullables.contains(tname) ->
                // We let choice decide if we add it, such that `choice-all`
                // can iterate every option.
                if choice() then
                  Just(Name(tname))
                else
                  Nothing
              _ -> Just(token)
        .concat
    val variants' = updated-variants.filter fn(variant)
      // We remove all empty variants, and all self-producing unit variants.
      match variant
        [] -> False
        [Name(tname)] | name == tname -> False
        _ -> True
    if variants'.is-empty then
      Nothing
    else
      Just(Rule(name, Cfg(variants')))


/* Rule-level transformations. */

// Improve a list of rules.
pub fun rule/optimize(rules : list<rule>, opts: list<(string, body) -> <exit<()>|e> body>) : e list<rule>
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

