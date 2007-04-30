(** Interface to the parser.*)

type ('result, 'intermediate) grammar

(* Grammar for types *)
val datatype    :  (Types.assumption, Sugartypes.datatype) grammar
(* Grammar for interactive shell *)
val interactive : (Sugartypes.sentence', Sugartypes.sentence) grammar
(* Grammar for programs stored in files etc. *)
val program : (Syntax.untyped_program,
               (Sugartypes.phrase list * Sugartypes.phrase option)) grammar


val parse_string  : ('a,'b) grammar -> string -> 'a
val parse_file    : ('a,'b) grammar -> string -> 'a
val parse_channel : ?interactive:(unit -> unit) -> ('a,'b) grammar -> (in_channel * string) -> 'a

            
