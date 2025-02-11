Some unrelated code before
the grammar
      starts
%%
this_is: { some code /* with a comment */ ;| } and_SOMETHING | {| else with code } or { more code !|!|!|! };
another: rule;
but_there: is another {nested {block {of {code}!}!}!;} |
           AND {{more} {nested}} code;
%%
