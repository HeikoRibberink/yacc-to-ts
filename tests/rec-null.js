eimports: ($) => seq(repeat1(seq($.IMPORT_EXTERN,$.externimpbody,$.semis1,)),optional($.declarations),),
declarations: ($) => seq(repeat1(seq($.fixitydecl,$.semis1,)),optional($.topdecls),),
topdecls: ($) => $.topdecls1,
