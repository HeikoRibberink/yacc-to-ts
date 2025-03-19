a: ($) => seq(optional($.n),optional($.f),$.g,repeat(choice(seq($.n,optional($.f),optional($.n),),seq(optional($.n),$.f,optional($.n),),seq(optional($.n),optional($.f),$.n,),)),),
n: ($) => repeat1('null'),
f: ($) => repeat1($.g),
g: ($) => repeat1('g'),
