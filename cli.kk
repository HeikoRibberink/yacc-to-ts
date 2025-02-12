module cli

import std/os/path

pub struct arguments
  input : path
  output : path
  options : options

pub struct options
  remove-left-recursion : bool

pub fun arguments/show(Arguments(input, output, _options) : arguments) : string
  "Arguments" ++ show((input, output))

pub extend type exception-info
  ExnArgs

pub fun usage() : string
  "Usage: yacc-to-ts [OPTION]... INFILE OUTFILE\n"

pub fun help() : string
  usage()
  ++ "Convert a Yacc grammar in INFILE to a tree-sitter grammar in OUTFILE\n"
  ++ "\nOptions:\n"
  ++ "  -l\t\tEliminate simple left recursion.\n"

// Show usage on exception
pub fun usage-on-exn(action : () -> <exn,console|e> a) : <exn,console|e> a
  with override final ctl throw-exn(e)
    val Exception(msg, info) = e
    match info
      ExnArgs ->
        throw(msg ++ "\n\n" ++ help())
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
  .foldl(Options(False)) fn(option, arg)
    arg.foldl(option) fn(opt, c)
      match c
        'l' -> opt(remove-left-recursion = True)
        c -> throw("Invalid flag `" ++ string(c) ++ "`", ExnArgs)
  // Now we filter out all the boolean flags to keep just the paths.
  val paths = args
  .filter fn(arg)
    arg.starts-with("-").is-nothing
  match paths
    [input, output] -> Arguments(path(input), path(output), options)
    _ -> throw("Expected exactly two paths.", ExnArgs)
