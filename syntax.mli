type location = [ `Client | `Native | `Server | `Unknown ]
type comparison = [`Less | `LessEq | `Equal | `NotEq]
type label
type 'a expression' =
    Define of (string * 'a expression' * location * 'a)
  | TypeDecl of (string * int list * Types.datatype * 'a)
  | Boolean of (bool * 'a)
  | Integer of (Num.num * 'a)
  | Char of (char * 'a)
  | String of (string * 'a)
  | Float of (float * 'a)
  | Variable of (string * 'a)
  | Apply of ('a expression' * 'a expression' * 'a)
  | Condition of ('a expression' * 'a expression' * 'a expression' * 'a)
  | Comparison of ('a expression' * comparison * 'a expression' * 'a)
  | Abstr of (string * 'a expression' * 'a)
  | Let of (string * 'a expression' * 'a expression' * 'a)
  | Rec of ((string * 'a expression' * Types.datatype option) list * 'a expression' * 'a)
  | Xml_node of (string * (string * 'a expression') list * 'a expression' list * 'a)
  | Record_empty of 'a
  | Record_extension of (string * 'a expression' * 'a expression' * 'a)
  | Record_selection of (string * string * string * 'a expression' * 'a expression' * 'a)
  | Record_selection_empty of ('a expression' * 'a expression' * 'a)
  | Variant_injection of (string * 'a expression' * 'a)
  | Variant_selection of ('a expression' * string * string * 'a expression' * 
                            string * 'a expression' * 'a)
  | Variant_selection_empty of ('a expression' * 'a)
  | Nil of 'a
  | List_of of ('a expression' * 'a)
  | Concat of ('a expression' * 'a expression' * 'a)
  | For of ('a expression' * string * 'a expression' * 'a)
  | Database of ('a expression' * 'a)
  | TableQuery of ((string * 'a expression') list * Query.query * 'a)
  | TableHandle of ('a expression' * 'a expression' * Types.row * 'a)
  | SortBy of ('a expression' * 'a expression' * 'a)
  | Escape of (string * 'a expression' * 'a)
  | Wrong of 'a
  | HasType of ('a expression' * Types.datatype * 'a)
  | Alien of (string * string * Types.assumption * 'a)
  | Placeholder of (label * 'a)
type position = Lexing.position * string * string
type untyped_data = [`U of position]
type typed_data = [`T of (position * Types.datatype * label option)]
type expression = [`T of (position * Types.datatype * label option)] expression'
type untyped_expression = untyped_data expression'
type stripped_expression = unit expression'

exception ASTSyntaxError of position * string

val list_expr : 'a -> 'a expression' list -> 'a expression'

val is_define : 'a expression' -> bool
val is_value : 'a expression' -> bool

val string_of_expression : 'a expression' -> string

val stringlit_value : 'a expression' -> string

val freevars : 'a expression' -> string list
(** {0 Variable-substitution functions} 
    TBD: gen'ize these for typed & other exprs as well *)
val subst_free : string -> untyped_expression -> untyped_expression -> untyped_expression
val rename_free : string -> string -> untyped_expression -> untyped_expression
val subst_fast : string -> expression -> expression -> expression
val rename_fast : string -> string -> expression -> expression

val reduce_expression : (('a expression' -> 'b) -> 'a expression' -> 'b) -> 
  ('a expression' * 'b list -> 'b) -> 'a expression' -> 'b

val expression_data : 'a expression' -> 'a
val strip_data : 'a expression' -> stripped_expression
val node_datatype : expression -> Types.datatype

type data = [untyped_data | typed_data]

val data_position : [<data] -> position
val position : [<data] expression' -> position

type unknown_data = private [<data]
type perhaps_typed_expression = unknown_data expression'

val erase : expression -> untyped_expression
val labelize : expression -> expression

val dummy_position : position
val no_expr_data : typed_data

module Show_expression : Show.Show with type a = expression
module Show_label : Show.Show with type a = label
module Show_stripped_expression : Show.Show with type a = stripped_expression

module Pickle_label : Pickle.Pickle with type a = label
module Pickle_expression : Pickle.Pickle with type a = expression
module RewriteUntypedExpression : Rewrite.Rewrite with type t = untyped_expression
module RewriteSyntax : Rewrite.Rewrite with type t = expression

module Functor_expression' : Functor.Functor with type 'a f = 'a expression'
module Show_comparison : Show.Show with type a = comparison
module Pickle_comparison : Pickle.Pickle with type a = comparison
