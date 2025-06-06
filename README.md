# Yacc to tree-sitter converter

A tool that generates tree-sitter grammar rules from a valid Yacc grammar file.

Written in [Koka](https://github.com/koka-lang/koka) v3.1.2 by [Heiko Ribberink](https://github.com/heikoribberink)

# Usage
```sh
./yacc-to-ts <input-file> <output-file>
```

# Features
- Removes comments, directives and semantic code blocks. See Limitations for more info.
- Transforms direct right and left recursive rules to `repeat`. E.g.
```yacc
%%
a1 : a1 ',' a
   | a b
   | b a
   ;
%%
```
becomes
```js
a1: ($) => seq(choice(seq($.a, $.b), seq($.b, $.a)), repeat(seq(",", $.a))),
```
- Correctly handles empty productions:
    - Transforms rules that match empty into non-empty rules.
    - Makes usage of any of the previous rules `optional`.
```yacc
a : n n f g n
  | n n f n
  ;
n : n 'null'
  |
  ;
f : f g
  |
  ;
g : g 'g'
  | 'g'
  ;

```
becomes (after formatting)
```js
a: ($) =>
choice(
  seq(optional($.n), optional($.n), optional($.f), $.g, optional($.n)),
  seq($.n, optional($.n), optional($.f), optional($.n)),
  seq(optional($.n), $.n, optional($.f), optional($.n)),
  seq(optional($.n), optional($.n), $.f, optional($.n)),
  seq(optional($.n), optional($.n), optional($.f), $.n),
),
n: ($) => repeat1("null"),
f: ($) => repeat1($.g),
g: ($) => repeat1("g"),
```
- Simplifies empty or single sequences and choices, flattens nested sequences and automatically transforms `seq(a, repeat(a))` to `repeat1(a)` where possible.

For examples of these improvements, see the `tests` folder.

# Limitations
- This tool does not generate a full tree-sitter `grammar.js` file, only the rules. You must perform some work yourself to complete the grammar, such as filling in the grammar name and applying precedences and conflicts. See [getting started](https://tree-sitter.github.io/tree-sitter/creating-parsers/1-getting-started.html) in the tree-sitter manual.
- Directives must be placed at the end of a line. Any `%` and all the characters following it in the same line are removed before parsing. A consequence is that, for example any precedence directives (`%prec`) are removed and must be added manually to the tree-sitter grammar.
- The output is not formatted. You must do this with a formatter such as Prettier yourself.

# Building from source
1. Install [the most recent Koka compiler](https://koka-lang.github.io/koka/doc/index.html#install), or build it from source.
2. Run `make build` in the project root, or execute `koka -o yacc-to-ts yacc-to-ts.kk`.

# Troubleshooting
- `Segmentation fault (core dumped)` This is probably a stack overflow exception, and occurs when you have a very large Yacc grammar. You can rebuild the program with a larger stack by passing `--stack=<stack size>` to Koka, for example `koka --stack=1G -o yacc-to-ts yacc-to-ts.kk`. It is related to [this Koka issue](https://github.com/koka-lang/koka/issues/679)

If you encounter any other problems, please create an issue on GitHub.

# Contributing
Anyone can contribute to `yacc-to-ts` by testing it! Find any Yacc grammar you like (such as for your favourite programming language), and use this tool to translate it to a Tree-sitter grammar, and test that grammar for correctness. If you encounter any problems, please create an issue on GitHub.
