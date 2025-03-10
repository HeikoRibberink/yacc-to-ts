Code
%%
eimports    : IMPORT_EXTERN externimpbody semis1 eimports
            | declarations
            ;
declarations: fixitydecl semis1 declarations
            | topdecls
            ;
topdecls    : topdecls1
            | /* empty */
            ;
%%
