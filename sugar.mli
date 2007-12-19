(** Converts the tree returned by the parser into our internal
    representation *)
module LAttrs : sig
  val has_lattrs : Sugartypes.phrasenode -> bool
  val replace_lattrs : Sugartypes.phrase -> Sugartypes.phrase
end

val desugar_expression : (Sugartypes.position -> Syntax.position) -> Sugartypes.phrase -> Syntax.untyped_expression
val desugar_definitions : (Sugartypes.position -> Syntax.position) -> Sugartypes.binding list -> Syntax.untyped_definition list
val desugar_datatype : Sugartypes.datatype -> Types.datatype
val desugar_datatype' : (Types.meta_type_var Utility.StringMap.t *
                           Types.meta_row_var Utility.StringMap.t) -> Sugartypes.datatype -> Types.datatype
val fresh_type_variable : unit -> Sugartypes.datatype
val make_write_row : Sugartypes.row -> (string * Sugartypes.fieldconstraint list) list -> Sugartypes.row
val generate_var_mapping : Sugartypes.quantifier list -> (Types.quantifier list * 
                                                            (Types.meta_type_var Utility.StringMap.t *
                                                               Types.meta_row_var Utility.StringMap.t))
val get_type_vars : Sugartypes.binding -> Sugartypes.quantifier list
