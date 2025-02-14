/*------------------------------------------------------------------------------
  Copyright 2025, Heiko Ribberink.

  This is free software; you can redistribute it and/or modify it under the
  terms of the MIT License. A copy of the License can be found in the LICENSE
  file at the root of this distribution.
------------------------------------------------------------------------------*/

/* Command-line interface */

module cli

import std/os/path

// Structure of valid program arguments.
pub struct arguments
  // The path to the input Yacc grammar.
  input : path
  // The path where the resulting Tree-sitter grammar should be written out to.
  output : path
  // Additional options.
  options : options

// Additional program options.
pub struct options
  // Whether to improve the resulting grammar.
  improve : bool

pub fun arguments/show(Arguments(input, output, _options) : arguments) : string
  "Arguments" ++ show((input, output))

pub extend type exception-info
  // Exception for invalid program arguments.
  ExnArgs

// Basic usage message.
val usage = "Usage: yacc-to-ts [OPTION]... INFILE OUTFILE\n"

// Full help message.
val help = 
  usage
  ++ "Convert a Yacc grammar in INFILE to a tree-sitter grammar in OUTFILE\n"
  ++ "\nOptions:\n"
  ++ "  -n\t\tDo not improve the resulting grammar to a more ideomatic version.\n"

// Show usage on argument exception.
pub fun usage-on-exn(action : () -> <exn,console|e> a) : <exn,console|e> a
  with override final ctl throw-exn(e)
    val Exception(msg, info) = e
    match info
      ExnArgs ->
        throw(msg ++ "\n\n" ++ help)
      _ -> 
        throw-exn(e)
  action()

// Parse the arguments.
pub fun parse(args: list<string>) : exn arguments
  fun is-flag(arg : string)
    match list(arg)
      Cons('-', tail) -> Just(tail)
      _ -> Nothing
  // Read and parse all the boolean flags.
  val options = args
  // Filter out all the arguments starting with `-`
  .filter-map(is-flag)
  // Then update the options accordingly
  .foldl(Options(True)) fn(option, arg)
    arg.foldl(option) fn(opt, c)
      match c
        'n' -> opt(improve = True)
        c -> throw("Invalid flag `" ++ string(c) ++ "`", ExnArgs)
  // Now we filter out all the boolean flags to keep just the paths.
  val paths = args
  .filter fn(arg)
    arg.starts-with("-").is-nothing
  match paths
    [input, output] -> Arguments(path(input), path(output), options)
    _ -> throw("Expected exactly two paths.", ExnArgs)
