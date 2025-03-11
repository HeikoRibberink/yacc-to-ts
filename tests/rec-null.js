rules = {
  eimports: ($) =>
    seq(
      repeat(seq($.IMPORT_EXTERN, $.externimpbody, $.semis1)),
      choice(seq($.IMPORT_EXTERN, $.externimpbody, $.semis1), $.declarations),
    ),
  declarations: ($) => seq(repeat(seq($.fixitydecl, $.semis1)), $.topdecls),
  topdecls: ($) => $.topdecls1,
};
