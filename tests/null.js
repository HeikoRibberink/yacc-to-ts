a: ($) => choice(seq(optional($.n),optional($.n),optional($.f),$.g,optional($.n),),seq($.n,optional($.n),optional($.f),optional($.n),),seq(optional($.n),$.n,optional($.f),optional($.n),),seq(optional($.n),optional($.n),$.f,optional($.n),),seq(optional($.n),optional($.n),optional($.f),$.n,),),
n: ($) => repeat1('null'),
f: ($) => repeat1($.g),
g: ($) => repeat1('g'),
