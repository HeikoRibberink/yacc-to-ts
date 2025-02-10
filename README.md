# Yacc to tree-sitter converter

A tool that generates tree-sitter rules from a valid Yacc grammar file.

Written in [Koka](https://github.com/koka-lang/koka) v3.1.2 by [Heiko Ribberink](https://github.com/heikoribberink)

# Usage
```sh
./yacc-to-ts <input-file> <output-file>
```

# Note
This tool does not generate a full tree-sitter `grammar.js` file, only the rules. You must perform some work yourself to complete the grammar, such as filling in the grammar name. See [getting started](https://tree-sitter.github.io/tree-sitter/creating-parsers/1-getting-started.html) in the tree-sitter manual.

# Building from source
1. Install [the most recent Koka compiler](https://koka-lang.github.io/koka/doc/index.html#install), or build it from source.
2. Run `make build` in the project root, or execute `koka -o yacc-to-ts yacc-to-ts.kk`.
