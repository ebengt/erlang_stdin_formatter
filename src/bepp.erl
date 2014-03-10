%% =====================================================================
%% Format Erlang code from stdin
%%
%% Copyright (C) 2005 Bengt Kleberg
%%
%% This library is free software; you can redistribute it and/or modify
%% it under the terms of the BSD License.
%%
%% You should have received a copy of the BSD
%% License along with this library; if not, contact the author.
%%
%% Author contact: bengt.kleberg@ericsson.com
%%
%% ===============================================================%%
%% @doc Format Erlang code from stdin.
%%
%%%		<p>This module makes it possible to format partial Erlang code snippets read from stdin.
%%%		It uses the module <code>string_io</code> which is not part of Erlang/OTP.
%%%		It is at github.com/ebengt/erlang_string_io.git</p>

-module(bepp).

-export([
	main/1,
	stdin/0,
	string/1
	]).


main( [_Prog|Files] ) ->
	pp( Files ),
	init:stop().


stdin() ->
	Reversed_Term = stdin_reversed_line_order( ),
	PP = pp_reversed_term( Reversed_Term ),
	io:put_chars( PP ).

string( String ) ->
	Reversed_Term = string_reversed_line_order( String ),
	pp_reversed_term( Reversed_Term ).
	

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% input
%	list() of string(), not reversed
%
% output
%	string()
%
% build the function head by accumulating
% characters until the end of the first balanced () pair.
% this will get fooled by () inside comments in the function head
% and by () in arguments
% surely there is a better way?
function_head( [First|T] ) ->
	case is_comment_or_empty( First ) of
	true ->
		function_head( T );
	false ->
		function_head( First, T, [])
	end.

function_head( [$(|Current], Rest, Result ) ->
	function_head( Current, Rest, [$(|Result], 1 );
function_head( [Char|Current], Rest, Result ) ->
	function_head( Current, Rest, [Char|Result] ).

function_head( _Current, _Rest, Result, 0 ) ->
	lists:reverse( Result );
function_head( [], [Next|T], Result, N ) ->
	function_head( Next, T, Result, N );
% Skip character after $, could be $(
function_head( [$$, Char|T], Rest, Result, N ) ->
	function_head( T, Rest, [Char, $$|Result], N );
function_head( [$(|Current], Rest, Result, N ) ->
	function_head( Current, Rest, [$(|Result], N+1 );
function_head( [$)|Current], Rest, Result, N ) ->
	function_head( Current, Rest, [$)|Result], N-1 );
function_head( [Char|Current], Rest, Result, N ) ->
	function_head( Current, Rest, [Char|Result], N ).


is_comment_or_empty( Last ) ->
	case lists:dropwhile( fun is_whitespace/1, Last ) of
	[] ->
		true;
	[$%|_Rest] ->
		true;
	_Else ->
		false
	end.


% special case where we only had comments or white space
is_complete_term( [] ) ->
	false;
% since term is reversed here, the last line is first
% remove all last lines that are comment or empty
% then check if the remaining line(s) are complete
is_complete_term( Reversed_Term ) ->
	is_complete_term_line(
		lists:dropwhile( fun is_comment_or_empty/1, Reversed_Term ) ).

% special case where we only had comments or white space
is_complete_term_line( [] ) ->
	true;
% since term is reversed here, the last line is first
% a complete term has '.' at the end of the last term line.
% surely there is a better way?
is_complete_term_line( [Last|_Rest] ) ->
	case is_complete_term_line_last_interesting_char( Last ) of
	$. ->
		true;
	_Else ->
		false
	end.

is_complete_term_line_last_interesting_char( [Char|T] ) ->
	is_complete_term_line_last_interesting_char( T, Char ).
is_complete_term_line_last_interesting_char( [], Char ) ->
	Char;
is_complete_term_line_last_interesting_char( [$%|_T], Char ) ->
	Char;
is_complete_term_line_last_interesting_char( [$.|T], _Char ) ->
	is_complete_term_line_last_interesting_char( T, $. );
is_complete_term_line_last_interesting_char( [_|T], Char ) ->
	is_complete_term_line_last_interesting_char( T, Char ).


is_whitespace( $\s ) ->
	true;
is_whitespace( $\t ) ->
	true;
is_whitespace( $\n ) ->
	true;
is_whitespace( $\r ) ->
	true;
is_whitespace( _Ch ) ->
	false.


pp( [] ) ->
	stdin().


pp_reversed_term( Reversed_Term ) ->
	{Term, Added} = term_from_reversed( Reversed_Term ),
	PP_Term = pp_string( Term ),
	case Added of
	[] ->
		% add \n, if not present, at end of PP_Term
		case erlang:length( PP_Term ) =:= string:rchr( PP_Term, $\n ) of
		true -> PP_Term;
		false -> lists:append( PP_Term, "\n" )
		end;
	Added ->
		PP_added = pp_string( Added ),
		% remove PP_added from end of PP_Term
		string:substr( PP_Term, 1, string:rstr( PP_Term, PP_added ) - 1 )
	end.


pp_string( String ) ->
	Syntaxtree = string_to_syntaxtree( String ),
	erl_prettypr:format(Syntaxtree, [{ribbon, 80}]).


stdin_reversed_line_order( ) ->
	stdin_reversed_line_order( io:get_line(''), [] ).
% building Result backwards line-by-line => reversed line order
stdin_reversed_line_order( eof, Result ) ->
	Result;
stdin_reversed_line_order( Line, Result ) ->
	stdin_reversed_line_order( io:get_line(''), [Line|Result] ).


%%% this will remove all \n from string
string_reversed_line_order( String ) ->
	string_reversed_line_order( String, string:chr(String, $\n), [] ).
string_reversed_line_order( String, 0, Result ) ->
	[String|Result];
string_reversed_line_order( String, N, Result ) ->
	Line = string:substr( String, 1, N ),
	Rest = string:substr( String, N+1),
	string_reversed_line_order( Rest, string:chr(Rest, $\n), [Line|Result]).


string_to_syntaxtree( String ) ->
	{ok, IO} = string_io:open( String, [read] ),
	{ok, Forms} = epp_dodger:parse(IO),
	string_io:close( IO ),
	Comments = erl_comment_scan:string(String),
	erl_recomment:recomment_forms(Forms, Comments).


term_from_reversed( Reversed_Term ) ->
	case is_complete_term( Reversed_Term ) of
	true ->
		{lists:flatten( lists:reverse( Reversed_Term ) ), []};
	false ->
		% make input complete by adding
		% function head + body + .
		Term = lists:reverse( Reversed_Term ),
		Final = lists:append( function_head( Term ), "-> added." ),
		{lists:flatten( lists:append( Term, Final ) ), Final}
	end.
