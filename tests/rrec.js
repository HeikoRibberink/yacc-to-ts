rr: ($) => seq(repeat(seq($.a,'|',)),$.end,),
media: ($) => seq(repeat(choice(seq($.phone,',',),seq($.text,',',),seq($.sms,',',),)),choice($.etc,$.etcetera,seq($.and,$.others,),),),
