a: ($) => seq(choice($.g,seq($.f,$.g,),seq($.n,$.g,),seq($.n,$.f,$.g,),),repeat(choice($.f,seq($.f,$.n,),$.n,seq($.n,$.n,),seq($.n,$.f,),seq($.n,$.f,$.n,),)),),
n: ($) => repeat1('null'),
f: ($) => repeat1($.g),
g: ($) => repeat1('g'),
