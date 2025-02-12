Code
%%
a0 : a1
   | %empty
   ;
a1 : a1 ',' a
   | a
   ;

%%
