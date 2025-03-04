% Code
%%
empty_a : a 
        | %empty
        ;
use_a   : use_a empty_a empty_a
        | %empty
        ;
%%
More code %
