-module( bepp_tests ).

-include_lib( "eunit/include/eunit.hrl" ).

-define( TEST_MODULE, bepp).


comment_test() ->
	S =  "% a comment",
	R = lists:append( S, "\n" ),
	?assertEqual( R, ?TEST_MODULE:string(S) ).

complete_test() ->
	S =  "a()->\n\tb.",
	R = "a() -> b.\n",
	?assertEqual( R, ?TEST_MODULE:string(S) ).

incomplete_test() ->
	S =  "a()->\n\tb;",
	R = "a() -> b;\n",
	?assertEqual( R, ?TEST_MODULE:string(S) ).
