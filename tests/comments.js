this: ($) => choice(
  seq($.is, $.a, $.TEST, ),
  seq($.ABOUT, ),
),
but: ($) => choice(
  seq($.this, $.is, ),
  seq($.not, ),
),
