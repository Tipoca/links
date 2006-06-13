exception Runtime_error of string

(** Database connectivity **)
class type otherfield
 = object method show : string end

type db_field_type =
    BoolField
  | TextField
  | IntField
  | FloatField
  | SpecialField of otherfield

type db_status = QueryOk | QueryError of string

class virtual dbresult :
  object
    method virtual error : string
    method virtual fname : int -> string
    method virtual ftype : int -> db_field_type
    method virtual get_all_lst : string list list
    method virtual nfields : int
    method virtual status : db_status
  end

class virtual database :
  object
    method virtual escape_string : string -> string
    method virtual exec : string -> dbresult
  end

type db_construtor = string -> database * string

val register_driver : string * db_construtor -> unit
val db_connect : string -> string -> database * string
val parse_db_string : string -> string * string
val reconstruct_db_string : string * string -> string


(** Values and continuations for the interpreter **)

type unop = | MkColl
            | MkVariant of string
            | MkDatabase
            | VrntSelect of
                (string * string * Syntax.expression * string option *
                   Syntax.expression option)
            | QueryOp of (Query.query * Types.datatype)
type binop =
    | EqEqOp
    | NotEqOp
    | LessEqOp
    | LessOp
    | UnionOp
    | RecExtOp of string
type xmlitem =
    | Text of string 
    | Attr of (string * string) 
    | Node of (string * xml)
and xml = xmlitem list
type basetype =
    [ `Bool of bool
    | `Char of char
    | `Database of database * string
    | `Float of float
    | `Int of Num.num
    | `XML of xmlitem ]
type contin_frame =
    | Definition of (environment * string)
    | FuncArg of (Syntax.expression * environment)
    | FuncApply of (result * environment)
    | LetCont of (environment * string * Syntax.expression)
    | BranchCont of (environment * Syntax.expression * Syntax.expression)
    | BinopRight of (environment * binop * Syntax.expression)
    | BinopApply of (environment * binop * result)
    | UnopApply of (environment * unop)
    | RecSelect of (environment * string * string * string * Syntax.expression)
    | CollExtn of
        (environment * string * Syntax.expression * result list list *
           result list)
    | StartCollExtn of (environment * string * Syntax.expression)
    | XMLCont of
        (environment * string * string option * xml *
           (string * Syntax.expression) list * Syntax.expression list)
    | Ignore of (environment * Syntax.expression)
    | Recv of environment
and result = [ basetype
| `Continuation of continuation
| `Function of string * environment * environment * Syntax.expression
| `List of result list
| `PFunction of string * result list
| `Record of (string * result) list
| `Variant of string * result ]
and continuation = contin_frame list
and binding = string * result
and environment = binding list
val expr_of_prim_val : result -> Syntax.expression option
val prim_val_of_expr : Syntax.expression -> result option
val xmlitem_of : result -> xmlitem
val bool : 'a -> [> `Bool of 'a ]
val int : 'a -> [> `Int of 'a ]
val float : 'a -> [> `Float of 'a ]
val char : 'a -> [> `Char of 'a ]
val listval : 'a -> [> `List of 'a ]
val xmlnodeval : string * xml -> [> `XML of xmlitem ]
val recfields : result -> (string * result) list
val string_as_charlist : string -> result
val links_fst : [> `Record of ('a * 'b) list ] -> 'b
val links_snd : [> `Record of ('a * 'b) list ] -> 'b
val escape : string -> string
val delay_expr : 'a -> [> `Function of string * 'b list * 'c list * 'a ]
val charlist_as_string : result -> string
val string_of_result : result -> string
val string_of_primitive : basetype -> string
val resolve_placeholders_expr : Syntax.expression list -> Syntax.expression -> Syntax.expression
val box_bool : 'a -> [> `Bool of 'a ]
val unbox_bool : result -> bool
val box_int : 'a -> [> `Int of 'a ]
val unbox_int : result -> Num.num
val box_float : 'a -> [> `Float of 'a ]
val unbox_float : result -> float
val box_char : 'a -> [> `Char of 'a ]
val unbox_char : result -> char
val box_xml : 'a -> [> `XML of 'a ]
val unbox_xml : result -> xmlitem
val box_string : string -> result
val unbox_string : result -> string
val retain : 'a list -> ('a * 'b) list -> ('a * 'b) list

val marshal_continuation : continuation -> string
val marshal_exprenv : (Syntax.expression * environment) -> string
val unmarshal_continuation : 'a -> string -> continuation
val unmarshal_exprenv : 'a -> string -> (Syntax.expression * environment)

module Pickle_result : Pickle.Pickle with type a = result
module Show_result : Show.Show with type a = result
