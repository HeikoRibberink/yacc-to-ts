this_is: ($) => choice($.and_SOMETHING,$.or,),
another: ($) => $.rule,
but_there: ($) => choice(seq($.is,$.another,),seq($.AND,$.code,),),
