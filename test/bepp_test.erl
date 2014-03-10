-module( bepp_test ).

-export( [main/1, all/0] ).


-define( TEST_MODULE, bepp).

main(_B) ->
	all(),
	init:stop().

all() ->
	comment(),
	complete(),
	incomplete().


comment() ->
	S =  "% a comment",
	R = lists:append( S, "\n" ),
	R = ?TEST_MODULE:string( S ).

complete() ->
	S =  "a()->\n\tb.",
	R = "a() -> b.\n",
	R = ?TEST_MODULE:string( S ).

incomplete() ->
	S =  "a()->\n\tb;",
	R = "a() -> b;\n",
	R = ?TEST_MODULE:string( S ).
