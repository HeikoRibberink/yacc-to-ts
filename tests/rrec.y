Code
Then there comes a right-recursive rule.
%%
/* First, a simple one */
rr : a '|' rr
   | end
   ;
// Then, a more complex one.
media : phone ',' media
      | text ',' media
      | sms ',' media
      | etc
      | etcetera
      | and others
      ;
%%
More code
