import std/text/parse

// Zero or more of `p`, seperated by `sep`
fun many-seperated(sep, p)
  optional([])
    many1-seperated(sep, p)

// One or more of `p`, seperated by `sep`
fun many1-seperated(sep, p)
  Cons(p(),
    many
      sep()
      p()
  )

fun join-append(xs : list<string>, sep : string) : string
  xs.foldl("") fn(s, x) s ++ x ++ sep

// A token in the right side of a production rule.
value type token
  Raw(s : string)
  Name(name : string)

fun token/show(t : token) : string
  match t
    Raw(s) -> "Raw(" ++ s ++ ")"
    Name(n) -> "Name(" ++ n ++ ")"

// Convert a `token` to a treesitter representation.
fun token/treesitter(t : token) : string
  match t
    Raw(s) -> "\"" ++ s ++ "\""
    Name(n) -> "$." ++ n

// A variant of a production rule.
value struct variant
  tokens : list<token>

fun variant/show(v : variant) : string
  v.tokens.show

// Convert a `variant` to a treesitter representation.
fun variant/treesitter(v : variant) : string
  "seq(" ++ v.tokens.map(treesitter).join-append(", ") ++ ")"
    

// A production rule.
value struct production
  name : string
  variants : list<variant>

fun production/show(p : production) : string
  "Production(" ++ p.name ++ ", " ++ p.variants.show ++ ")"

// Convert a `production` to a treesitter representation.
fun production/treesitter(p : production) : string
  var has-empty : bool := False
  val variants = 
    p.variants.filter fn(v)
      if v.tokens.is-empty then 
        has-empty := True
        False
      else
        True
  val (optional-start, optional-end) = 
    if has-empty then 
      ("optional(", ")") 
    else 
      ("", "")
  p.name ++ ": ($) => " ++ optional-start ++ "choice(\n" 
  ++ variants.map(treesitter).map fn(s)
    "  " ++ s
  .join-append(",\n") 
  ++ ")" ++ optional-end

// Convert a `list<production>` to a treesitter representation.
// Use this to generate a full list of grammar rules from a successfull parse.
fun productions/treesitter(ps : list<production>) : string
  ps.map(treesitter).join-append(",\n")

// Token id
fun rid()
  Name(
    string(
      many1
        choose([
          alpha-num,
          fn()
            one-of("_")
        ])
    )
  )
    
  
// A raw string token
fun rawstring()
  char('\'')
  val c = none-of("\'")
  char('\'')
  Raw(c.string)

fun token()
  choose([rid,rawstring])

// A block of semantic code.
fun code-block() : _ ()
  char('{')
  many
    none-of("{}")
  char('}')
  ()

fun variant() : _ variant
  val res = Variant(many-seperated(whitespace, token))
  optional(())
    whitespace0()
    code-block()
  res
  

fun variants() : _ list<variant>
  fun sep()
    whitespace0()
    char('|')
    whitespace0()
  many1-seperated(sep, variant)

// Production rule
fun prod() : _ production
  val Name(id) = rid()
  whitespace0()
  char(':')
  whitespace0()
  val vs = variants()
  whitespace0()
  char(';')
  Production(id, vs)

// Production rules
fun prods() : _ list<production>
  whitespace0()
  many
    val p = prod()
    whitespace0()
    p
  
  
fun lower-alpha()
  char-is("lower-alpha") fn(c)
    is-lower(c) && is-alpha(c)

fun lower-alpha-num()
  char-is("lower-alpha-num") fn(c)
    (is-lower(c) && is-alpha(c)) || is-digit(c)

fun upper-alpha()
  char-is("upper-alpha") fn(c)
    is-upper(c) && is-alpha(c)

fun upper-alpha-num()
  char-is("upper-alpha-num") fn(c)
    (is-upper(c) && is-alpha(c)) || is-digit(c)
