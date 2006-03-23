open Kind
open Sql
open Result

class virtual db_args : string -> object 
  val strval : string
  method virtual from_string : string -> unit
end

val execute_select : (kind -> string -> database -> result)