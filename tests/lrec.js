a1: ($) => seq(choice(seq($.a,$.b,),seq($.b,$.a,),),repeat(seq(',',$.a,)),),
mult: ($) => seq(choice($.var,seq($.var,'.',$.prop,),),repeat(choice(seq('*',$.var,),seq('.',$.prop,'*=',$.var,),seq('mul',$.var,'->',$.var,),)),),
