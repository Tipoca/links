# 3 "jsonlex.mll"
 


# 6 "jsonlex.ml"
let __ocaml_lex_tables = {
  Lexing.lex_base = 
   "\000\000\255\255\254\255\253\255\252\255\251\255\250\255\000\000\
    \000\000\000\000\002\000\013\000\000\000\243\255\023\000\081\000\
    \033\000\091\000\244\255\070\000\246\255\101\000\115\000\153\000\
    \143\000\000\000\001\000\247\255\003\000\000\000\000\000\248\255\
    \005\000\002\000\249\255";
  Lexing.lex_backtrk = 
   "\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\010\000\010\000\255\255\011\000\255\255\
    \255\255\011\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255";
  Lexing.lex_default = 
   "\255\255\000\000\000\000\000\000\000\000\000\000\000\000\255\255\
    \255\255\255\255\010\000\255\255\255\255\000\000\255\255\255\255\
    \255\255\255\255\000\000\255\255\000\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\000\000\255\255\255\255\255\255\000\000\
    \255\255\255\255\000\000";
  Lexing.lex_trans = 
   "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\013\000\013\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \013\000\000\000\010\000\000\000\020\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\004\000\000\000\014\000\000\000\
    \012\000\011\000\011\000\011\000\011\000\011\000\011\000\011\000\
    \011\000\011\000\003\000\014\000\000\000\011\000\011\000\011\000\
    \011\000\011\000\011\000\011\000\011\000\011\000\011\000\014\000\
    \014\000\014\000\014\000\014\000\014\000\014\000\014\000\014\000\
    \014\000\018\000\017\000\017\000\017\000\017\000\017\000\017\000\
    \017\000\017\000\017\000\005\000\000\000\006\000\019\000\000\000\
    \000\000\028\000\000\000\000\000\000\000\031\000\008\000\034\000\
    \010\000\000\000\000\000\000\000\026\000\027\000\009\000\029\000\
    \000\000\000\000\032\000\030\000\007\000\025\000\021\000\021\000\
    \021\000\021\000\033\000\001\000\015\000\002\000\016\000\000\000\
    \000\000\018\000\017\000\017\000\017\000\017\000\017\000\017\000\
    \017\000\017\000\017\000\017\000\017\000\017\000\017\000\017\000\
    \017\000\017\000\017\000\017\000\017\000\024\000\024\000\024\000\
    \024\000\024\000\024\000\024\000\024\000\000\000\022\000\000\000\
    \000\000\000\000\010\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\023\000\023\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\000\000\000\000\000\000\000\000\022\000\010\000\
    \010\000\010\000\010\000\010\000\010\000\010\000\010\000\000\000\
    \000\000\010\000\010\000\010\000\010\000\010\000\010\000\010\000\
    \010\000\010\000\010\000\000\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\010\000\010\000\010\000\010\000\010\000\010\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\010\000\010\000\010\000\010\000\010\000\010\000\
    \000\000\000\000\255\255\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000";
  Lexing.lex_check = 
   "\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\000\000\000\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \000\000\255\255\000\000\255\255\010\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\000\000\255\255\012\000\255\255\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\011\000\255\255\011\000\011\000\011\000\
    \011\000\011\000\011\000\011\000\011\000\011\000\011\000\014\000\
    \014\000\014\000\014\000\014\000\014\000\014\000\014\000\014\000\
    \014\000\016\000\016\000\016\000\016\000\016\000\016\000\016\000\
    \016\000\016\000\016\000\000\000\255\255\000\000\010\000\255\255\
    \255\255\008\000\255\255\255\255\255\255\030\000\000\000\033\000\
    \019\000\255\255\255\255\255\255\025\000\026\000\000\000\028\000\
    \255\255\255\255\007\000\029\000\000\000\009\000\019\000\019\000\
    \019\000\019\000\032\000\000\000\014\000\000\000\015\000\255\255\
    \255\255\015\000\015\000\015\000\015\000\015\000\015\000\015\000\
    \015\000\015\000\015\000\017\000\017\000\017\000\017\000\017\000\
    \017\000\017\000\017\000\017\000\017\000\021\000\021\000\021\000\
    \021\000\021\000\021\000\021\000\021\000\255\255\019\000\255\255\
    \255\255\255\255\019\000\022\000\022\000\022\000\022\000\022\000\
    \022\000\022\000\022\000\022\000\022\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\022\000\022\000\022\000\022\000\
    \022\000\022\000\255\255\255\255\255\255\255\255\019\000\024\000\
    \024\000\024\000\024\000\024\000\024\000\024\000\024\000\255\255\
    \255\255\023\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \023\000\023\000\023\000\255\255\022\000\022\000\022\000\022\000\
    \022\000\022\000\023\000\023\000\023\000\023\000\023\000\023\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\023\000\023\000\023\000\023\000\023\000\023\000\
    \255\255\255\255\010\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255";
  Lexing.lex_base_code = 
   "";
  Lexing.lex_backtrk_code = 
   "";
  Lexing.lex_default_code = 
   "";
  Lexing.lex_trans_code = 
   "";
  Lexing.lex_check_code = 
   "";
  Lexing.lex_code = 
   "";
}

let rec jsonlex lexbuf =
    __ocaml_lex_jsonlex_rec lexbuf 0
and __ocaml_lex_jsonlex_rec lexbuf __ocaml_lex_state =
  match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 15 "jsonlex.mll"
                                         ( Jsonparse.LBRACE )
# 153 "jsonlex.ml"

  | 1 ->
# 16 "jsonlex.mll"
                                         ( Jsonparse.RBRACE )
# 158 "jsonlex.ml"

  | 2 ->
# 17 "jsonlex.mll"
                                         ( Jsonparse.COLON )
# 163 "jsonlex.ml"

  | 3 ->
# 18 "jsonlex.mll"
                                         ( Jsonparse.COMMA )
# 168 "jsonlex.ml"

  | 4 ->
# 19 "jsonlex.mll"
                                         ( Jsonparse.LBRACKET )
# 173 "jsonlex.ml"

  | 5 ->
# 20 "jsonlex.mll"
                                         ( Jsonparse.RBRACKET )
# 178 "jsonlex.ml"

  | 6 ->
# 21 "jsonlex.mll"
                                         ( Jsonparse.TRUE )
# 183 "jsonlex.ml"

  | 7 ->
# 22 "jsonlex.mll"
                                         ( Jsonparse.FALSE )
# 188 "jsonlex.ml"

  | 8 ->
# 23 "jsonlex.mll"
                                         ( Jsonparse.NULL )
# 193 "jsonlex.ml"

  | 9 ->

  let var = Lexing.sub_lexeme lexbuf (lexbuf.Lexing.lex_start_pos + 1) (lexbuf.Lexing.lex_curr_pos + -1) in
# 24 "jsonlex.mll"
                                         ( Jsonparse.STRING (Sl_utility.decode_escapes var) )
# 200 "jsonlex.ml"

  | 10 ->

  let var = Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos lexbuf.Lexing.lex_curr_pos in
# 25 "jsonlex.mll"
                                         ( Jsonparse.INT (Num.num_of_string var) )
# 207 "jsonlex.ml"

  | 11 ->

  let var = Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos lexbuf.Lexing.lex_curr_pos in
# 26 "jsonlex.mll"
                                         ( Jsonparse.FLOAT (float_of_string var) )
# 214 "jsonlex.ml"

  | 12 ->
# 27 "jsonlex.mll"
                                         ( jsonlex lexbuf )
# 219 "jsonlex.ml"

  | __ocaml_lex_state -> lexbuf.Lexing.refill_buff lexbuf; __ocaml_lex_jsonlex_rec lexbuf __ocaml_lex_state

;;

