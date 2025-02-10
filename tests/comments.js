this: ($) => choice(
  seq($.is, $.a, $.TEST, ),
  $.ABOUT,
),
but: ($) => choice(
  seq($.this, $.is, ),
  $.not,
),
