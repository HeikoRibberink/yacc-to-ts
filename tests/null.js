a: ($) => choice($.g,seq($.g,$.n,),seq($.f,$.g,),seq($.f,$.g,$.n,),seq($.n,$.g,),seq($.n,$.g,$.n,),seq($.n,$.f,$.g,),seq($.n,$.f,$.g,$.n,),seq($.n,$.g,),seq($.n,$.g,$.n,),seq($.n,$.f,$.g,),seq($.n,$.f,$.g,$.n,),seq($.n,$.n,$.g,),seq($.n,$.n,$.g,$.n,),seq($.n,$.n,$.f,$.g,),seq($.n,$.n,$.f,$.g,$.n,),$.n,$.f,seq($.f,$.n,),$.n,seq($.n,$.n,),seq($.n,$.f,),seq($.n,$.f,$.n,),$.n,seq($.n,$.n,),seq($.n,$.f,),seq($.n,$.f,$.n,),seq($.n,$.n,),seq($.n,$.n,$.n,),seq($.n,$.n,$.f,),seq($.n,$.n,$.f,$.n,),),
n: ($) => repeat1('null'),
f: ($) => repeat1($.g),
g: ($) => repeat1('g'),
