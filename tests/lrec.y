Code
%%
/* A single left recursive rule with multiple terminating variants. */
a1 : a1 ',' a
   | a b
   | b a
   ;

/* A complex left-recursive rule. */
mult : mult '*' var
     | mult '.' prop '*=' var
     | mult 'mul' var '->' var
     | var
     | var '.' prop
     ;
%%
