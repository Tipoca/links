(*pp deriving *)
open Utility
open Sugartypes

let constrain_absence_types = Settings.add_bool ("constrain_absence_types", 
                                                 false, `User)

let check_top_level_purity =
  Settings.add_bool ("check_top_level_purity", false, `User)

type var_env =
    Types.meta_type_var StringMap.t *
      Types.meta_row_var StringMap.t 
      deriving (Show)

module Env = Env.String

module Utils : sig
  val unify : Types.datatype * Types.datatype -> unit
  val instantiate : Types.environment -> string -> 
                    (Types.type_arg list * Types.datatype)
  val generalise : Types.environment -> Types.datatype -> 
                   ((Types.quantifier list*Types.type_arg list) * Types.datatype)

  val is_pure : phrase -> bool
  val is_pure_binding : binding -> bool
  val is_generalisable : phrase -> bool
end =
struct
  let unify = Unify.datatypes
  let instantiate = Instantiate.var
  let generalise = Generalise.generalise

  let rec opt_generalisable o = opt_app is_pure true o
  and is_pure (p, _) = match p with
    | `Constant _
    | `Var _
    | `FunLit _
    | `DatabaseLit _
    | `TableLit _
    | `TextNode _
    | `Section _ -> true

    | `ListLit (ps, _)
    | `TupleLit ps -> List.for_all is_pure ps
    | `RangeLit (e1, e2) -> is_pure e1 && is_pure e2
    | `TAbstr (_, p)
    | `TAppl (p, _)
    | `Projection (p, _)
    | `TypeAnnotation (p, _)
    | `Upcast (p, _, _)
    | `Escape (_, p) -> is_pure p
    | `ConstructorLit (_, p, _) -> opt_generalisable p
    | `RecordLit (fields, p) ->
        List.for_all (snd ->- is_pure) fields && opt_generalisable p
    | `With (p, fields) ->
        List.for_all (snd ->- is_pure) fields && is_pure p
    | `Block (bindings, e) -> 
        List.for_all is_pure_binding bindings && is_pure e
    | `Conditional (p1, p2, p3) ->
        is_pure p1 
     && is_pure p2
     && is_pure p3 
    | `Xml (_, attrs, attrexp, children) -> 
        List.for_all (snd ->- List.for_all is_pure) attrs
     && opt_generalisable attrexp
     && List.for_all (is_pure) children
    | `Formlet (p1, p2) ->
        is_pure p1 && is_pure p2
    | `Regex r -> is_pure_regex r
    | `Iteration _ (* could do a little better in some of these cases *)
    | `Page _
    | `FormletPlacement _
    | `PagePlacement _
    | `UnaryAppl _
    | `FormBinding _
    | `InfixAppl _
    | `Spawn _
    | `SpawnWait _
    | `Query _
    | `FnAppl _
    | `Switch _
    | `Receive _
    | `DBDelete _
    | `DBInsert _
    | `DBUpdate _ -> false
  and is_pure_binding (bind, _ : binding) = match bind with
      (* need to check that pattern matching cannot fail *) 
    | `Fun _
    | `Funs _
    | `Infix
    | `Type _
    | `Include _
    | `Foreign _ -> true
    | `Exp p -> is_pure p
    | `Val (_, pat, rhs, _, _) ->
        is_safe_pattern pat && is_pure rhs
  and is_safe_pattern (pat, _) = match pat with
      (* safe patterns cannot fail *)
    | `Nil 
    | `Cons _
    | `List _ 
    | `Constant _ -> false
    (* NOTE: variant assigment is typed such that it must always succeed *)
    | `Variant (_, None) -> true
    | `Variant (_, Some p) -> is_safe_pattern p
    | `Negative _ -> true
    | `Any
    | `Variable _ -> true
    | `Record (ps, None) -> List.for_all (snd ->- is_safe_pattern) ps
    | `Record (ps, Some p) -> List.for_all (snd ->- is_safe_pattern) ps && is_safe_pattern p
    | `Tuple ps -> List.for_all is_safe_pattern ps
    | `HasType (p, _)
    | `As (_, p) -> is_safe_pattern p
  and is_pure_regex = function 
      (* don't check whether it can fail; just check whether it
         contains non-generilisable sub-expressions *)
    | `Range _
    | `Simply _
    | `Any
    | `StartAnchor
    | `EndAnchor -> true
    | `Group r
    | `Repeat (_, r)
    | `Quote r -> is_pure_regex r
    | `Seq rs -> List.for_all is_pure_regex rs
    | `Alternate (r1, r2) -> is_pure_regex r1 && is_pure_regex r2
    | `Splice p -> is_pure p
    | `Replace (r, `Literal _) -> is_pure_regex r
    | `Replace (r, `Splice p) -> is_pure_regex r && is_pure p

  let is_generalisable = is_pure
end

module Gripers :
sig
  type griper = 
      pos:SourceCode.pos ->
  t1:(string * Types.datatype) ->
  t2:(string * Types.datatype) ->
  error:Unify.error ->
  unit

  val die : SourceCode.pos -> string -> 'a

  val if_condition : griper
  val if_branches  : griper

  val switch_pattern : griper
  val switch_patterns : griper
  val switch_branches : griper

  val extend_record : griper
  val record_with : griper

  val list_lit : griper

  val table_name : griper
  val table_db : griper

  val delete_table : griper
  val delete_pattern : griper
  val delete_where : griper
  val delete_outer : griper

  val insert_table : griper
  val insert_values : griper
  val insert_read : griper
  val insert_write : griper
  val insert_needed : griper
  val insert_outer : griper

  val insert_id : griper
  val update_table : griper
  val update_pattern : griper
  val update_where : griper
  val update_read : griper
  val update_write : griper
  val update_needed : griper
  val update_outer : griper

  val range_bound : griper

  val spawn_outer : griper
  val spawn_wait_outer : griper

  val query_outer : griper
  val query_base_row : griper

  val receive_mailbox : griper
  val receive_patterns : griper

  val unary_apply : griper
  val infix_apply : griper
  val fun_apply : griper

  val xml_attribute : griper
  val xml_attributes : griper
  val xml_child : griper

  val formlet_body : griper
  val page_body : griper

  val render_formlet : griper
  val render_handler : griper
  val render_attributes : griper

  val page_placement : griper

  val form_binding_body : griper
  val form_binding_pattern : griper

  val iteration_list_body : griper
  val iteration_list_pattern : griper
  val iteration_table_body : griper
  val iteration_table_pattern : griper
  val iteration_body : griper
  val iteration_where : griper
  val iteration_base_order : griper
  val iteration_base_body : griper

  val escape : griper
  val escape_outer : griper

  val projection : griper

  val upcast_source : griper
  val upcast_subtype : SourceCode.pos -> Types.datatype -> Types.datatype -> 'a
 
  val value_restriction : SourceCode.pos -> Types.datatype -> 'a

  val toplevel_purity_restriction : SourceCode.pos -> Sugartypes.binding -> 'a

  val duplicate_names_in_pattern : SourceCode.pos -> 'a

  val type_annotation : griper

  val bind_val : griper
  val bind_val_annotation : griper

  val bind_fun_annotation : griper
  val bind_fun_return : griper

  val bind_rec_annotation : griper
  val bind_rec_rec : griper

  val bind_exp : griper

  val list_pattern : griper
  val cons_pattern : griper
  val record_pattern : griper
  val pattern_annotation : griper

  val splice_exp : griper
end
  = struct
    type griper = 
        pos:SourceCode.pos ->
      t1:(string * Types.datatype) ->
      t2:(string * Types.datatype) ->
      error:Unify.error ->
      unit

    let wm () = Settings.get_value Basicsettings.web_mode

    let code s =
      if wm() then
        "<code>" ^ s ^ "</code>"
      else
        match getenv "TERM" with
(*           | Some ("rxvt"|"aterm"|"gnome-terminal"|"xterm") -> *)
(*               "`\x1b[1;31m" ^ s ^ "\x1b[0m'" *)
          | _ -> ("`"^ s ^ "'" )
      
    let nl () =
      if wm() then
        "<br />\n"
      else
        "\n"

    let tab () =
      if wm() then
        "&nbsp;&nbsp;&nbsp;&nbsp;"
      else
        "    "

    let show_type = Types.string_of_datatype
    let show_row = Types.string_of_row

    let die pos msg = raise (Errors.Type_error (pos, msg))

    let but (expr, t) =
", but the expression" ^ nl() ^
tab() ^ code expr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type t) ^ "."

    let but2things (lthing, (lexpr, lt)) (rthing, (rexpr, rt)) =
", but the " ^ lthing ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"while the " ^ rthing ^ nl() ^
tab() ^ code rexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type rt) ^ "."

    let but2 l r = but2things ("expression", l) ("expression", r)

    let with_but pos s et =
      die pos (s ^ but et)

    let with_but2 pos s l r =
      die pos (s ^ but2 l r)

    let with_but2things pos s l r =
      die pos (s ^ but2things l r)

    let fixed_type pos thing t l =
      with_but pos (thing ^ " must have type " ^ code (show_type t)) l

    let if_condition ~pos ~t1:l ~t2:(_,t) ~error:_ = 
      fixed_type pos ("The condition of an " ^ code "if (...) ... else ..." ^ " expression") t l

    let if_branches ~pos ~t1:l ~t2:r ~error:_ =
      with_but2 pos ("Both branches of an " ^ code "if (...) ... else ..." ^
                       " expression should have the same type") l r

    let switch_pattern ~pos ~t1:(lexpr,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The type of an input to a switch should match the type of its patterns, but
the expression" ^ nl () ^
tab () ^ code lexpr ^ nl () ^
"has type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the patterns have type" ^ nl () ^
tab () ^ code (show_type rt))

    let switch_patterns ~pos ~t1:(lexpr,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
All the cases of a switch should have compatible patterns, but
the pattern" ^ nl () ^
tab () ^ code lexpr ^ nl () ^
"has type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the subsequent patterns have type" ^ nl () ^
tab () ^ code (show_type rt))

    let switch_branches ~pos ~t1:(lexpr, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
All the cases of a switch should have the same type, but
the expression" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"while the subsequent expressions have type" ^ nl() ^
tab() ^ code (show_type rt))

    (* BUG: This griper is a bit rubbish because it doesn't distinguish
    between two different errors. *)
    let extend_record ~pos ~t1:(lexpr, lt) ~t2:(_,t) ~error:_ =
      die pos ("\
Only a record can be extended, and it must be extended with different fields, but
the expression" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"while the extension fields have type" ^ code (show_type t) ^ ".")

    let record_with ~pos ~t1:(lexpr, lt) ~t2:(_,t) ~error:_ =
      die pos ("\
A record can only be updated with compatible fields, but
the expression" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"while the update fields have type" ^ code (show_type t) ^ ".")

    let list_lit ~pos ~t1:l ~t2:r ~error:_ =
      with_but2 pos "All elements of a list literal must have the same type" l r

    let table_name ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Table names" t l

    let table_db ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Databases" t l

    let delete_table ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Tables" t l

    let delete_where ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Where clauses" t l

    let delete_pattern ~pos ~t1:(lexpr, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The binder must match the table in a delete generator, \
but the pattern" ^ nl() ^
tab () ^ code lexpr ^ nl () ^
"has type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the read row has type" ^ nl () ^
tab () ^ code (show_type rt))

    let delete_outer ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
Database deletes are wild" ^ nl() ^
code (show_type rt) ^ nl() ^
"but the currently allowed effects are" ^ nl() ^
code (show_type lt) ^ ".")

    let insert_table ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Tables" t l

    let insert_values ~pos ~t1:(lexpr, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The values must match the table in an insert expression,
but the values" ^ nl () ^
tab () ^ code lexpr ^ nl () ^
"have type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the write row has type" ^ nl () ^
tab () ^ code (show_type rt))

    let insert_read ~pos ~t1:(_, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The fields must match the table in an insert expression,
but the fields have type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the read row has type" ^ nl () ^
tab () ^ code (show_type rt))

    let insert_write ~pos ~t1:(_, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The fields must match the table in an insert expression,
but the fields have type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the write row has type" ^ nl () ^
tab () ^ code (show_type rt))

    let insert_needed ~pos ~t1:(_, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The fields must match the table in an insert expression,
but the fields have type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the needed row has type" ^ nl () ^
tab () ^ code (show_type rt))

    let insert_id ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Identity variables" t l

    let insert_outer ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
Database inserts are wild" ^ nl() ^
code (show_type rt) ^ nl() ^
"but the currently allowed effects are" ^ nl() ^
code (show_type lt) ^ ".")

    let update_table ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Tables" t l

    let update_pattern ~pos ~t1:l ~t2:r ~error:_ =
      with_but2things pos
        "The binding must match the table in an update expression" ("pattern", l) ("row", r)

    let update_read ~pos ~t1:(_, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The fields must match the table in an update expression,
but the fields have type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the read row has type" ^ nl () ^
tab () ^ code (show_type rt))

    let update_write ~pos ~t1:(_, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The fields must match the table in an update expression,
but the fields have type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the write row has type" ^ nl () ^
tab () ^ code (show_type rt))

    let update_needed ~pos ~t1:(_, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The fields must match the table in an update expression,
but the fields have type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the needed row has type" ^ nl () ^
tab () ^ code (show_type rt))

    let update_where ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Where clauses" t l

    let update_outer ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
Database updates are wild" ^ nl() ^
code (show_type rt) ^ nl() ^
"but the currently allowed effects are" ^ nl() ^
code (show_type lt) ^ ".")

    let range_bound ~pos ~t1:l ~t2:(_,t) ~error:_ =
      die pos "Range bounds must be integers."

    let spawn_outer ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
Spawn blocks are wild" ^ nl() ^
code (show_type rt) ^ nl() ^
"but the currently allowed effects are" ^ nl() ^
code (show_type lt) ^ ".")

    let spawn_wait_outer ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
Spawn wait blocks are wild" ^ nl() ^
code (show_type rt) ^ nl() ^
"but the currently allowed effects are" ^ nl() ^
code (show_type lt) ^ ".")

    let query_outer ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
The query block has effects" ^ nl() ^
code (show_type rt) ^ nl() ^
"but the currently allowed effects are" ^ nl() ^
code (show_type lt) ^ ".")

    let query_base_row ~pos ~t1:(lexpr, lt) ~t2:(_, _rt) ~error:_ =
      with_but pos ("Query blocks must have LOROB type") (lexpr, lt)

    let receive_mailbox ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
The current mailbox must always have a mailbox type" ^ nl() ^
code (show_type rt) ^ nl() ^
"but the currently allowed effects are" ^ nl() ^
code (show_type lt) ^ ".")

    let receive_patterns ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
The current mailbox type should match the type of the patterns in a receive, but
the current mailbox takes messages of type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the patterns have type" ^ nl () ^
tab () ^ code (show_type rt))

    let unary_apply ~pos ~t1:(lexpr, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The unary operator" ^ nl() ^ 
tab () ^ code lexpr ^ nl() ^
"has type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the argument passed to it has type" ^ nl() ^
tab () ^ code (show_type (List.hd (TypeUtils.arg_types rt))) ^ nl() ^
"and the currently allowed effects are" ^ nl() ^
tab() ^ code (show_row (TypeUtils.effect_row rt)) ^ ".")

    let infix_apply ~pos ~t1:(lexpr, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The infix operator" ^ nl() ^ 
tab () ^ code lexpr ^ nl() ^
"has type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the arguments passed to it have types" ^ nl() ^
tab () ^ code (show_type (List.hd (TypeUtils.arg_types rt))) ^ nl() ^
"and" ^ nl() ^
tab () ^ code (show_type (List.hd (List.tl (TypeUtils.arg_types rt)))) ^ nl() ^
"and the currently allowed effects are" ^ nl() ^
tab() ^ code (show_row (TypeUtils.effect_row rt)) ^ ".")

    let fun_apply ~pos ~t1:(lexpr, lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The function" ^ nl() ^ 
tab () ^ code lexpr ^ nl () ^
"has type" ^ nl () ^
tab () ^ code (show_type lt) ^ nl () ^
"while the arguments passed to it have types" ^ nl() ^
String.concat
(nl() ^ "and" ^ nl())
(List.map (fun t ->
             tab() ^ code (show_type t)) (TypeUtils.arg_types rt)) ^ nl() ^
"and the currently allowed effects are" ^ nl() ^
tab() ^ code (show_row (TypeUtils.effect_row rt)) ^ ".")

    let xml_attribute ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "XML attributes" t l

    let xml_attributes ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "A list of XML attributes" t l

    let xml_child ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "XML child nodes" t l

    let formlet_body ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Formlet bodies" t l

    let page_body ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Page bodies" t l

    let render_formlet ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Formlets" t l

    let render_handler ~pos ~t1:l ~t2:r ~error:_ =
      with_but2 pos
        "The formlet must match its handler in a formlet placement" l r

    let render_attributes ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "A list of XML attributes" t l

    let page_placement ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Page antiquotes" t l

    let form_binding_body ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Formlets" t l

    let form_binding_pattern ~pos ~t1:l ~t2:(rexpr, rt) ~error:_ =
(*      let rt = Types.make_formlet_type rt in*)
        with_but2things pos
          ("The binding must match the formlet in a formlet binding") ("pattern", l) ("expression", (rexpr, rt))

    let iteration_list_body ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "The body of a list generator" t l
      
    let iteration_list_pattern ~pos ~t1:l ~t2:(rexpr,rt) ~error:_ =
      let rt = Types.make_list_type rt in
        with_but2things pos
          ("The binding must match the list in a list generator") ("pattern", l) ("expression", (rexpr, rt))

    let iteration_table_body ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "The body of a table generator" t l

    let iteration_table_pattern ~pos ~t1:l ~t2:(rexpr,rt) ~error:_ =
      let rt = Types.make_table_type (rt, Types.fresh_type_variable `Any, Types.fresh_type_variable `Any) in
        with_but2things pos
          ("The binding must match the table in a table generator") ("pattern", l) ("expression", (rexpr, rt))

    let iteration_body ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "The body of a for comprehension" t l

    let iteration_where ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Where clauses" t l

    let iteration_base_order ~pos ~t1:(expr,t) ~t2:_ ~error:_ =
      with_but pos
        ("An orderby clause must return a list of records of base type")
        (expr, t)

    let iteration_base_body ~pos ~t1:(expr,t) ~t2:_ ~error:_ =
      with_but pos
        ("A database comprehension must return a list of records of base type")
        (expr, t)

    let escape ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "The argument to escape" t l

    let escape_outer ~pos ~t1:(_, lt) ~t2:(_, rt) ~error:_ =
      die pos ("\
Escape is wild" ^ nl() ^
code (show_type rt) ^ nl() ^
"but the currently allowed effects are" ^ nl() ^
code (show_type lt) ^ ".")

    let projection ~pos ~t1:(lexpr, lt) ~t2:(_,t) ~error:_ =
      die pos ("\
Only a field that is present in a record can be projected, but \
the expression" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"while the projection has type" ^ code (show_type t) ^ ".")

    let upcast_source ~pos ~t1:(lexpr, lt) ~t2:(_,t) ~error:_ =
      die pos ("\
The source expression must match the source type of an upcast, but\
the expression" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"while the source type is" ^ code (show_type t) ^ ".")

    let upcast_subtype pos t1 t2 =
      die pos ("\
An upcast must be of the form" ^ code ("e : t2 <- t1") ^
"where " ^ code "t1" ^ " is a subtype of" ^ code "t2" ^ nl() ^
"but" ^ nl() ^
code (show_type t1) ^ nl() ^
"is not a subtype of" ^ nl() ^
code (show_type t2) ^ ".")
        
    let value_restriction pos t =
      die pos (
"Because of the value restriction there can be no" ^ nl() ^
"free rigid type variables at an ungeneralisable binding site," ^ nl() ^
"but the type " ^ code (show_type t) ^ " has free rigid type variables.")

    let toplevel_purity_restriction pos b =
      die pos (
"Side effects are not allowed outside of" ^ nl() ^
"function definitions. This binding may have a side effect.")

    let duplicate_names_in_pattern pos =
      die pos ("Duplicate names are not allowed in patterns.")

    let type_annotation ~pos ~t1:(lexpr,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The inferred type of the expression" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"is" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"but it is annotated with type" ^ nl() ^
tab() ^ code (show_type rt))

    let bind_val ~pos ~t1:l ~t2:r ~error:_ =
      with_but2things pos
        ("The binder must match the type of the body in a value binding") ("pattern", l) ("expression", r)

    let bind_val_annotation ~pos ~t1:(_,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The value has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"but it is annotated with type" ^ nl() ^
tab() ^ code (show_type rt))

    let bind_fun_annotation ~pos ~t1:(_,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The non-recursive function definition has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"but it is annotated with type" ^ nl() ^
tab() ^ code (show_type rt))

    let bind_fun_return ~pos ~t1:(_,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The non-recursive function definition has return type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"but its annotation has return type" ^ nl() ^
tab() ^ code (show_type rt))

    let bind_rec_annotation ~pos ~t1:(_,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The recursive function definition has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"but it is annotated with type" ^ nl() ^
tab() ^ code (show_type rt))

    let bind_rec_rec ~pos ~t1:(_,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The recursive function definition has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"but its previously inferred type is" ^ nl() ^
tab() ^ code (show_type rt))

    let bind_exp ~pos ~t1:l ~t2:(_,t) ~error:_ =
      fixed_type pos "Side-effect expressions" t l

    (* patterns *)
    let list_pattern ~pos ~t1:(lexpr,lt) ~t2:(rexpr,rt) ~error:_ =
      die pos ("\
All elements in a list pattern must have the same type, but the pattern" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"while the pattern" ^ nl() ^
tab() ^ code rexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type rt))

    let cons_pattern ~pos ~t1:(lexpr,lt) ~t2:(rexpr,rt) ~error:_ =
      die pos ("\
The two subpatterns of a cons pattern " ^ code "p1::p2" ^ " must have compatible types:\
if " ^ code "p1" ^ " has type " ^ code "t'" ^ " then " ^ code "p2" ^ " must have type " ^ code "[t]" ^ ".\
However, the pattern" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type (TypeUtils.element_type lt)) ^ nl() ^
"whereas the pattern" ^ nl() ^
tab() ^ code rexpr ^ nl() ^
"has type" ^ nl() ^
tab() ^ code (show_type rt))

    let record_pattern ~pos:pos ~t1:(_lexpr,_lt) ~t2:(_rexpr,_rt) ~error =
      match error with
        | `PresentAbsentClash (label, _, _) ->
            let (_, _, expr) = SourceCode.resolve_pos pos in
            (* NB: is it certain that this is what's happened? *)
          die pos ("\
Duplicate labels are not allowed in record patterns.  However, the pattern" ^ nl() ^
tab() ^ code expr ^ nl() ^
"contains more than one binding for the label " ^ nl() ^
tab() ^ code label)
      | `Msg msg -> raise (Errors.Type_error (pos, msg))

    let pattern_annotation ~pos ~t1:(lexpr,lt) ~t2:(_,rt) ~error:_ =
      die pos ("\
The inferred type of the pattern" ^ nl() ^
tab() ^ code lexpr ^ nl() ^
"is" ^ nl() ^
tab() ^ code (show_type lt) ^ nl() ^
"but it is annotated with type" ^ nl() ^
tab() ^ code (show_type rt))

    let splice_exp ~pos:pos ~t1:(_,lt) ~t2:_ ~error:_ =
      die pos ("\
An expression enclosed in {} in a regex pattern must have type String, 
but the expression here has type " ^ (show_type lt))


end

type context = Types.typing_environment = {
  (* mapping from variables to type schemes *)
  var_env   : Types.environment ;

  (* mapping from type alias names to the types they name.  We don't
     use this to resolve aliases in the code, which is done before
     type inference.  Instead, we use it to resolve references
     introduced here to aliases defined in the prelude such as "Page"
     and "Formlet". *)
  tycon_env : Types.tycon_environment ;

  (* the current effects *)
  effect_row : Types.row
}

let empty_context eff =
  { var_env   = Env.empty;
    tycon_env = Env.empty;
    effect_row = eff }

let bind_var context (v, t) = {context with var_env = Env.bind context.var_env (v,t)}
let bind_tycon context (v, t) = {context with tycon_env = Env.bind context.tycon_env (v,t)}
let bind_effects context r = {context with effect_row = r}

let type_section context (`Section s as s') =
  let env = context.var_env in
  let (tyargs, t) =
    match s with
      | `Minus         -> Utils.instantiate env "-"
      | `FloatMinus    -> Utils.instantiate env "-."
      | `Project label ->
          let a = Types.fresh_type_variable `Any in
          let rho = Types.fresh_row_variable `Any in
          let effects = Types.make_empty_open_row `Any in (* projection is pure! *)
          let r = `Record (StringMap.add label (`Present, a) StringMap.empty, rho) in
            [`Type a; `Row (StringMap.empty, rho); `Row effects], `Function (Types.make_tuple_type [r], effects, a)
      | `Name var      -> Utils.instantiate env var
  in
    if Settings.get_value Instantiate.quantified_instantiation then
      let tyvars = Types.quantifiers_of_type_args tyargs in 
        tabstr(tyvars, tappl (s', tyargs)), t
    else
      tappl (s', tyargs), t

let datatype aliases = Instantiate.typ -<- DesugarDatatypes.read ~aliases

let type_unary_op env = 
  let datatype = datatype env.tycon_env in function
  | `Minus      -> datatype "(Int) -> Int"
  | `FloatMinus -> datatype "(Float) -> Float"
  | `Name n     -> Utils.instantiate env.var_env n

let type_binary_op ctxt = 
  let datatype = datatype ctxt.tycon_env in function
  | `Minus        -> Utils.instantiate ctxt.var_env "-"
  | `FloatMinus   -> Utils.instantiate ctxt.var_env "-."
  | `RegexMatch flags -> 
      let nativep  = List.exists ((=) `RegexNative)  flags
      and listp    = List.exists ((=) `RegexList)    flags 
      and replacep = List.exists ((=) `RegexReplace) flags in
        begin
          match replacep, listp, nativep with
           | true,   _   , false -> (* stilde  *) datatype "(String, Regex) -> String"
           | false, true , false -> (* ltilde *)  datatype "(String, Regex) -> [String]"
           | false, false, false -> (* tilde *)   datatype "(String, Regex) -> Bool"
        end
  | `And
  | `Or           -> datatype "(Bool,Bool) -> Bool"
  | `Cons         -> Utils.instantiate ctxt.var_env "Cons"
  | `Name "++"    -> Utils.instantiate ctxt.var_env "Concat"
  | `Name ">"
  | `Name ">="
  | `Name "=="
  | `Name "<"
  | `Name "<="
  | `Name "<>"    ->
      let a = Types.fresh_type_variable `Any in
      let eff = (StringMap.empty, Types.fresh_row_variable `Any) in
        ([`Type a; `Row eff],
         `Function (Types.make_tuple_type [a; a], eff, `Primitive `Bool))
  | `Name "!"     -> Utils.instantiate ctxt.var_env "send"
  | `Name n       -> Utils.instantiate ctxt.var_env n

(** close a pattern type relative to a list of patterns

   If there are no _ or variable patterns at a variant type, then that
   variant will be closed.
*)
let rec close_pattern_type : pattern list -> Types.datatype -> Types.datatype = fun pats t ->
  let cpt : pattern list -> Types.datatype -> Types.datatype = close_pattern_type in
    match t with
      | `Alias (alias, t) -> `Alias (alias, close_pattern_type pats t)
      | `Record row when Types.is_tuple row->
          let fields, row_var = fst (Types.unwrap_row row) in
          let rec unwrap_at i p =
            match fst p with
              | `Variable _ | `Any | `Constant _ -> p
              | `As (_, p) | `HasType (p, _) -> unwrap_at i p
              | `Tuple ps ->
                  List.nth ps i
              | `Nil | `Cons _ | `List _ | `Record _ | `Variant _ | `Negative _ -> assert false in
          let fields =
            StringMap.fold
              (fun name ->
                 function
                   | `Present, t ->
                       let pats = List.map (unwrap_at ((int_of_string name) - 1)) pats in
                         StringMap.add name (`Present, cpt pats t)
                   | `Absent, _
                   | `Var _, _ ->
                       assert false) fields StringMap.empty in
            `Record (fields, row_var)
      | `Record row ->
          let fields, row_var = fst (Types.unwrap_row row) in
          let rec unwrap_at name p =
            match fst p with
              | `Variable _ | `Any | `Constant _ -> p
              | `As (_, p) | `HasType (p, _) -> unwrap_at name p
              | `Record (ps, default) ->
                  if List.mem_assoc name ps then
                    List.assoc name ps
                  else
                    begin
                      match default with
                        | None -> assert false
                        | Some p -> unwrap_at name p
                    end
              | `Nil | `Cons _ | `List _ | `Tuple _ | `Variant _ | `Negative _ -> assert false in
          let fields =
            StringMap.fold
              (fun name ->
                 function
                   | `Present, t ->
                       let pats = List.map (unwrap_at name) pats in
                         StringMap.add name (`Present, cpt pats t)
                   | `Absent, _
                   | `Var _, _ ->
                        assert false) fields StringMap.empty in
            `Record (fields, row_var)
      | `Variant row ->
          let fields, row_var = fst (Types.unwrap_row row) in
          let end_pos p =
            let _, (_, end_pos, buf) = p in
              (*
                QUESTION:
                
                This indicates the position immediately after the pattern.
                How can we indicate a 0-length position in an error message?
              *)
              (end_pos, end_pos, buf) in
            
          let rec unwrap_at : string -> pattern -> pattern list = fun name p ->
            match fst p with
              | `Variable _ | `Any -> [ `Any, end_pos p ]
              | `As (_, p) | `HasType (p, _) -> unwrap_at name p
              | `Variant (name', None) when name=name' ->
                    [(`Record ([], None), end_pos p)]
              | `Variant (name', Some p) when name=name' -> [p]
              | `Variant _ -> []
              | `Negative names when List.mem name names -> []
              | `Negative _ -> [ `Any, end_pos p ]
              | `Nil | `Cons _ | `List _ | `Tuple _ | `Record _ | `Constant _ -> assert false in
          let rec are_open : pattern list -> bool =
            function
              | [] -> false
              | ((`Variable _ | `Any | `Negative _), _) :: _ -> true
              | ((`As (_, p) | `HasType (p, _)), _) :: ps -> are_open (p :: ps)
              | ((`Variant _), _) :: ps -> are_open ps
              | ((`Nil | `Cons _ | `List _ | `Tuple _ | `Record _ | `Constant _), _) :: _ -> assert false in
          let fields =
            StringMap.fold
              (fun name field_spec env ->
                 match field_spec with
                   | `Present, t ->
                       let pats = concat_map (unwrap_at name) pats in
                       let t = cpt pats t in
                         (StringMap.add name (`Present, t)) env
                   | `Absent, _
                   | `Var _, _ ->
                       assert false) fields StringMap.empty
          in
            if are_open pats then
              begin
                let row = (fields, row_var) in
                  (* NOTE: type annotations can lead to a closed type even though the patterns are open *)
(*
                  if Types.is_closed_row row then
                    failwith ("Open row pattern with closed type: "^Types.string_of_row row)
                  else
*)
                    `Variant row
              end
            else
              begin
                match Unionfind.find row_var with
                  | `Flexible _ | `Rigid _ -> `Variant (fields, Unionfind.fresh `Closed)
                  | `Recursive _ | `Body _ | `Closed -> assert false
              end
      | `Application (l, [`Type t]) 
          when Eq.eq Types.Abstype.eq_t l Types.list ->
          let rec unwrap p : pattern list =
            match fst p with
              | `Variable _ | `Any -> [p]
              | `Constant _ | `Nil -> []
              | `Cons (p1, p2) -> p1 :: unwrap p2 
              | `List ps -> ps
              | `As (_, p) | `HasType (p, _) -> unwrap p
              | `Variant _ | `Negative _ | `Record _ | `Tuple _ -> assert false in
          let pats = concat_map unwrap pats in
            `Application (Types.list, [`Type (cpt pats t)])
      | `ForAll (qs, t) -> `ForAll (qs, cpt pats t)
      | `MetaTypeVar point ->
          begin
            match Unionfind.find point with
              | `Body t -> cpt pats t
              | `Flexible _ | `Rigid _ -> t
              | `Recursive _ -> assert false
          end
      | `Not_typed
      | `Primitive _
      | `Function _
      | `Table _
       (* TODO: expand applications? *)
      | `Application _ -> t

let unify ~pos ~(handle:Gripers.griper) ((_,ltype as t1), (_,rtype as t2)) =
  try
    Utils.unify (ltype, rtype)
  with
      Unify.Failure error ->
        begin
          match error with
            | `Msg s ->
                Debug.print ("Unification error: "^s)
            | _ -> ()
        end;
        handle ~pos ~t1 ~t2 ~error

(** check for duplicate names in a list of pattern *)
let check_for_duplicate_names : Sugartypes.position -> pattern list -> unit = fun pos ps ->
  let add name binder binderss =
    if StringMap.mem name binderss then
      let (count, binders) = StringMap.find name binderss in
        StringMap.add name (count+1, binder::binders) binderss
    else
      StringMap.add name (1, [binder]) binderss in   
      
  let rec gather binderss ((p : patternnode), pos) =
    match p with
      | `Any -> binderss
      | `Nil -> binderss
      | `Cons (p, q) ->
          let binderss = gather binderss p in gather binderss q
      | `List ps ->
          List.fold_right (fun p binderss -> gather binderss p) ps binderss
      | `Variant (_, p) ->
          opt_app (fun p -> gather binderss p) binderss p
      | `Negative _ -> binderss
      | `Record (ps, p) ->
          let binderss = List.fold_right (fun (_, p) binderss -> gather binderss p) ps binderss in
            opt_app (fun p -> gather binderss p) binderss p
      | `Tuple ps ->
          List.fold_right (fun p binderss -> gather binderss p) ps binderss
      | `Constant _ -> binderss
      | `Variable ((name, _, _) as binder) ->
          add name binder binderss
      | `As (((name, _, _) as binder), p) ->
          let binderss = gather binderss p in
            add name binder binderss
      | `HasType (p, _) -> gather binderss p in

  let binderss =
    List.fold_left gather StringMap.empty ps in
  let dups = StringMap.filterv (fun (i, _) -> i > 1) binderss in
    if not (StringMap.is_empty dups) then
      Gripers.duplicate_names_in_pattern pos

let type_pattern closed : pattern -> pattern * Types.environment * Types.datatype =
  let make_singleton_row =
    match closed with
      | `Closed -> Types.make_singleton_closed_row
      | `Open -> (fun var -> Types.make_singleton_open_row var `Any) in

  (* type_pattern p types the pattern p returning a typed pattern, a
     type environment for the variables bound by the pattern and two
     types. The first type is the type of the pattern 'viewed from the
     outside' - in the case of variant patterns it must be open in
     order to allow cases to unify. The second type is the type of the
     pattern 'viewed from the inside'. Type annotations are only
     applied to the inner pattern. The type environment is constructed
     using types from the inner type.

  *)
  let rec type_pattern (pattern, pos' : pattern) : pattern * Types.environment * (Types.datatype * Types.datatype) =
    let _UNKNOWN_POS_ = "<unknown>" in
    let tp = type_pattern in
    let unify (l, r) = unify ~pos:pos' (l, r)
    and erase (p,_, _) = p
    and ot (_,_,(t,_)) = t
    and it (_,_,(_,t)) = t
    and env (_,e,_) = e
    and pos ((_,p),_,_) = let (_,_,p) = SourceCode.resolve_pos p in p
    and (++) = Env.extend in
    let (p, env, (outer_type, inner_type)) :
           patternnode * Types.environment * (Types.datatype * Types.datatype) =
      match pattern with
        | `Any ->
            let t = Types.fresh_type_variable `Any in
              `Any, Env.empty, (t, t)
        | `Nil ->
            let t = Types.make_list_type (Types.fresh_type_variable `Any) in
              `Nil, Env.empty, (t, t)
        | `Constant c as c' ->
            let t = Constant.constant_type c in
              c', Env.empty, (t, t)
        | `Variable (x,_,pos) -> 
            let xtype = Types.fresh_type_variable `Any in
              (`Variable (x, Some xtype, pos),
               Env.bind Env.empty (x, xtype),
               (xtype, xtype))
        | `Cons (p1, p2) -> 
            let p1 = tp p1
            and p2 = tp p2 in
            let () = unify ~handle:Gripers.cons_pattern ((pos p1, Types.make_list_type (ot p1)), 
                                                        (pos p2, ot p2)) in
            let () = unify ~handle:Gripers.cons_pattern ((pos p1, Types.make_list_type (it p1)), 
                                                        (pos p2, it p2)) in
              `Cons (erase p1, erase p2), env p1 ++ env p2, (ot p2, it p2)
        | `List ps -> 
            let ps' = List.map tp ps in
            let env' = List.fold_right (env ->- (++)) ps' Env.empty in
            let list_type p ps typ =
              let _ = List.iter (fun p' -> unify ~handle:Gripers.list_pattern ((pos p, typ p), 
                                                                              (pos p', typ p'))) ps
              in
                Types.make_list_type (typ p) in
            let ts =
              match ps' with
                | [] -> let t = Types.fresh_type_variable `Any in t, t
                | p::ps ->
                    list_type p ps ot, list_type p ps it
            in                            
              `List (List.map erase ps'), env', ts
        | `Variant (name, None) -> 
            let vtype () = `Variant (make_singleton_row (name, (`Present, Types.unit_type))) in
              `Variant (name, None), Env.empty, (vtype (), vtype ())
        | `Variant (name, Some p) -> 
            let p = tp p in
            let vtype typ = `Variant (make_singleton_row (name, (`Present, typ p))) in
              `Variant (name, Some (erase p)), env p, (vtype ot, vtype it)
        | `Negative names ->
            let row_var = Types.fresh_row_variable `Any in

            let positive, negative =
              List.fold_right
                (fun name (positive, negative) ->
                   let a = Types.fresh_type_variable `Any in
                   let b =
                     if Settings.get_value constrain_absence_types then a
                     else Types.fresh_type_variable `Any
                   in                         
                     (StringMap.add name (`Present, a) positive,
                      StringMap.add name (`Absent, b) negative))
                names (StringMap.empty, StringMap.empty) in
                
            let outer_type = `Variant (positive, row_var) in
            let inner_type = `Variant (negative, row_var) in
              `Negative names, Env.empty, (outer_type, inner_type)
        | `Record (ps, default) -> 
            let ps = alistmap tp ps in
            let default = opt_map tp default in
            let initial_outer, initial_inner, denv =
              match default with
                | None ->
                    let row = Types.make_empty_closed_row () in
                      row, row, Env.empty
                | Some r ->
                    let make_closed_row typ =
                      let row = 
                        List.fold_right
                          (fun (label, _) ->
                             let field_type = Types.fresh_type_variable `Any in
                               Types.row_with (label, (`Absent, field_type))) (* Types.for_all ([q], field_type)))) *)
                          ps (Types.make_empty_open_row `Any) in
                      let () = unify ~handle:Gripers.record_pattern (("", `Record row),
                                                                    (pos r, typ r))
                      in
                        row
                    in                      
                      make_closed_row ot, make_closed_row it, env r in
            let rtype typ initial =
              `Record (List.fold_right
                         (fun (l, f) -> Types.row_with (l, (`Present, typ f)))
                         ps initial) in
            let penv = 
              List.fold_right (snd ->- env ->- (++)) ps Env.empty
            in
              (`Record (alistmap erase ps, opt_map erase default),
               penv ++ denv,
               (rtype ot initial_outer, rtype it initial_outer))
        | `Tuple ps -> 
            let ps' = List.map tp ps in
            let env' = List.fold_right (env ->- (++)) ps' Env.empty in
            let make_tuple typ = Types.make_tuple_type (List.map typ ps') in
              `Tuple (List.map erase ps'), env', (make_tuple ot, make_tuple it)
        | `As ((x, _, pos), p) ->
            let p = tp p in
            let env' = Env.bind (env p) (x, it p) in
              `As ((x, Some (it p), pos), erase p), env', (ot p, it p)
        | `HasType (p, (_,Some t as t')) ->
            let p = tp p in
            let () = unify ~handle:Gripers.pattern_annotation ((pos p, it p), (_UNKNOWN_POS_, t))
            in
              `HasType (erase p, t'), env p, (ot p, t) in
      (p, pos'), env, (outer_type, inner_type)
  in
    fun pattern ->
      let () = check_for_duplicate_names (snd pattern) [pattern] in
      let pos, env, (outer_type, _) = type_pattern pattern in
        pos, env, outer_type

let rec pattern_env : pattern -> Types.datatype Env.t = 
  fun (p, _) -> match p with
    | `Any
    | `Nil
    | `Constant _ -> Env.empty

    | `HasType (p,_) -> pattern_env p
    | `Variant (_, Some p) -> pattern_env p
    | `Variant (_, None) -> Env.empty
    | `Negative _ -> Env.empty
    | `Record (ps, Some p) ->
        List.fold_right (snd ->- pattern_env ->- Env.extend) ps (pattern_env p)
    | `Record (ps, None) ->
        List.fold_right (snd ->- pattern_env ->- Env.extend) ps Env.empty
    | `Cons (h,t) -> Env.extend (pattern_env h) (pattern_env t)
    | `List ps
    | `Tuple ps -> List.fold_right (pattern_env ->- Env.extend) ps Env.empty
    | `Variable (v, Some t, _) -> Env.bind Env.empty (v, t)
    | `Variable (_, None, _) -> assert false
    | `As       ((v, Some t, _), p) -> Env.bind (pattern_env p) (v, t)
    | `As       ((_, None, _), _) -> assert false


let update_pattern_vars env =
(object (self)
  inherit SugarTraversals.map as super

  method patternnode : patternnode -> patternnode =
    fun n ->      
      let update (x, _, pos) =
        let t = Env.lookup env x in
          (x, Some t, pos)
      in
        match n with
          | `Variable b -> `Variable (update b)
          | `As (b, p) -> `As (update b, self#pattern p)
          | _ -> super#patternnode n
 end)#pattern

let rec extract_formlet_bindings : phrase -> Types.datatype Env.t = function
  | `FormBinding (_, pattern), _ -> pattern_env pattern
  | `Xml (_, _, _, children), _ ->
      List.fold_right
        (fun child env ->
           Env.extend env (extract_formlet_bindings child))
        children Env.empty
  | _ -> Env.empty
      
let show_context : context -> context =
  fun context ->
    Printf.fprintf stderr "Types  : %s\n" (Show.show Env.Dom.show_t (Env.domain context.tycon_env));
    Printf.fprintf stderr "Values : %s\n" (Show.show Env.Dom.show_t (Env.domain context.var_env));
    flush stderr;
    context


(* given a list of argument patterns and a return type
   return the corresponding function type *)
let make_ft ps effects return_type =
  let pattern_typ (_, _, t) = t in
  let args =
    Types.make_tuple_type -<- List.map pattern_typ in
  let rec ft =
    function
      | [p] -> `Function (args p, effects, return_type)
      | p::ps -> `Function (args p, (StringMap.empty, Types.fresh_row_variable `Any), ft ps)
  in
    ft ps

let make_ft_poly_curry ps effects return_type =
  let pattern_typ (_, _, t) = t in
  let args =
    Types.make_tuple_type -<- List.map pattern_typ in
  let rec ft =
    function
      | [p] -> [], `Function (args p, effects, return_type)
      | p::ps ->
          let qs, t = ft ps in
          let q, eff = Types.fresh_row_quantifier `Any in
            q::qs, `Function (args p, eff, t)
  in
    Types.for_all (ft ps)

let rec type_check : context -> phrase -> phrase * Types.datatype = 
  fun context (expr, pos) ->
    let _UNKNOWN_POS_ = "<unknown>" in
    let no_pos t = (_UNKNOWN_POS_, t) in
    let unify (l, r) = unify ~pos:pos (l, r)
    and (++) env env' = {env with var_env = Env.extend env.var_env env'} in
    let typ (_,t) : Types.datatype = t 
    and erase (p, _) = p
    and erase_pat (p, _, t) = p
    and pattern_typ (_, _, t) = t
    and pattern_env (_, e, _) = e in
    let pattern_pos ((_,p),_,_) = let (_,_,p) = SourceCode.resolve_pos p in p in
    let ppos_and_typ p = (pattern_pos p, pattern_typ p) in
    let uexp_pos (_,p) = let (_,_,p) = SourceCode.resolve_pos p in p in   
    let exp_pos (p,_) = uexp_pos p in
    let pos_and_typ e = (exp_pos e, typ e) in
    let tpc p = type_pattern `Closed p
    and tpo p = type_pattern `Open p
    and tc : phrase -> phrase * Types.datatype = type_check context
    and expr_string (_,pos : Sugartypes.phrase) : string =
      let (_,_,e) = SourceCode.resolve_pos pos in e 
    and erase_cases = List.map (fun ((p, _, t), (e, _)) -> p, e) in
    let type_cases binders =
      let pt = Types.fresh_type_variable `Any in
      let bt = Types.fresh_type_variable `Any in
      let binders, pats = 
        List.fold_right
          (fun (pat, body) (binders, pats) ->
             let pat = tpo pat in
             let () =
               unify ~handle:Gripers.switch_patterns
                 (ppos_and_typ pat, no_pos pt)
             in
               (pat, body)::binders, pat :: pats)
          binders ([], []) in
      let pt = close_pattern_type (List.map fst3 pats) pt in

      (* NOTE: it is important to type the patterns in isolation first in order
         to allow them to be closed before typing the bodies *)

      let binders = 
        List.fold_right
          (fun (pat, body) binders ->
             let body = type_check (context ++ pattern_env pat) body in
             let () = unify ~handle:Gripers.switch_branches
               (pos_and_typ body, no_pos bt)
             in
               (pat, body)::binders)
          binders []
      in
        binders, pt, bt in

    let e, t =
      match (expr : phrasenode) with
        | `Var v            ->
            (
              try
                let (tyargs, t) = Utils.instantiate context.var_env v in
                  if Settings.get_value Instantiate.quantified_instantiation then
                    let tyvars = Types.quantifiers_of_type_args tyargs in 
                      tabstr(tyvars, tappl (`Var v, tyargs)), t
                  else
                    tappl (`Var v, tyargs), t
              with
                  Errors.UndefinedVariable msg ->
                    Gripers.die pos ("Unknown variable " ^ v ^ ".")
            )
        | `Section _ as s   -> type_section context s

        (* literals *)
        | `Constant c as c' -> c', Constant.constant_type c
        | `TupleLit [p] -> 
            let p = tc p in
              `TupleLit [erase p], typ p
        | `TupleLit ps ->
            let ps = List.map tc ps in
              `TupleLit (List.map erase ps), Types.make_tuple_type (List.map typ ps)
        | `RecordLit (fields, rest) ->
            let _ =
              (* check that each label only occurs once *)
              List.fold_left
                (fun labels (name, _) ->
                   if StringSet.mem name labels then
                     Gripers.die pos ("Duplicate labels (" ^ name ^ ") in record.")
                   else
                     StringSet.add name labels)
                StringSet.empty fields in
            let fields, field_env, absent_field_env = 
              List.fold_right
                (fun (label, e) (fields, field_env, absent_field_env) ->
                   let e = tc e in
                   let t = typ e in
                   let t' =
                     if Settings.get_value constrain_absence_types then t
                     else Types.fresh_type_variable `Any
                   in
                     ((label, e)::fields,
                      StringMap.add label (`Present, t) field_env,
                      StringMap.add label (`Absent, t') absent_field_env))
                fields ([], StringMap.empty, StringMap.empty) in
              begin match rest with
                | None ->
                    `RecordLit (alistmap erase fields, None), `Record (field_env, Unionfind.fresh `Closed)
                | Some r ->
                    let r : phrase * Types.datatype = tc r in

                    (* FIXME:
                       
                       we need to explicitly instantiate quantifiers
                       like this *whenever* we do any kind of
                       elimination
                    *)

                    (* explicitly instantiate any quantifiers attached to r *)
                    let r =
                      let (tyargs, rtype) = Instantiate.typ (typ r) in
                      let rexp, rpos = erase r in
                        (tappl (rexp, tyargs), rpos), rtype in

                    let rtype = typ r in

                    (* make sure rtype is a record type that doesn't match any of the existing fields *)
                    let () = unify ~handle:Gripers.extend_record
                      (pos_and_typ r, no_pos (`Record (absent_field_env, Types.fresh_row_variable `Any))) in

                    let (rfield_env, rrow_var), _ = Types.unwrap_row (TypeUtils.extract_row rtype) in 
                      (* attempt to extend field_env with the labels from rfield_env
                         i.e. all the labels belonging to the record r
                      *)
                    let field_env' =
                      StringMap.fold (fun label t field_env' ->
                                        match t with
                                          | `Absent, t ->
                                              if StringMap.mem label field_env then
                                                field_env'
                                              else
                                                StringMap.add label (`Absent, t) field_env'
                                          | `Present, _ ->
                                              if StringMap.mem label field_env then
                                                failwith ("Could not extend record "^ expr_string (fst r)^" (of type "^
                                                            Types.string_of_datatype rtype^") with the label "^
                                                            label^
                                                            " (of type"^Types.string_of_datatype (`Record (field_env, Unionfind.fresh `Closed))^
                                                            ") because the labels overlap")
                                              else
                                                StringMap.add label t field_env'
                                          | `Var _, _ -> assert false) rfield_env field_env in
                      `RecordLit (alistmap erase fields, Some (erase r)), `Record (field_env', rrow_var)
              end
        | `ListLit (es, _) ->
            begin match List.map tc es with
              | [] ->
                  let t = Types.fresh_type_variable `Any in
                    `ListLit ([], Some t), `Application (Types.list, [`Type t])
              | e :: es -> 
                  List.iter (fun e' -> unify ~handle:Gripers.list_lit (pos_and_typ e, pos_and_typ e')) es;
                  `ListLit (List.map erase (e::es), Some (typ e)), `Application (Types.list, [`Type (typ e)])
            end
        | `FunLit (_, (pats, body)) ->
            let () = check_for_duplicate_names pos (List.flatten pats) in
            let pats = List.map (List.map tpc) pats in
            let fold_in_envs = List.fold_left (fun env pat' -> env ++ pattern_env pat') in
            let {var_env = env'} = List.fold_left fold_in_envs context pats in

            (* type of the effects in the body of the lambda *)
            let effects = (StringMap.empty, Types.fresh_row_variable `Any) in
            let body = type_check ({context with
                                      var_env = env';
                                      effect_row = effects}) body in

            let ftype = make_ft pats effects (typ body) in
            let argss =
              let rec arg_types =
                function
                  | (`Function (args, effects, t)) -> (args, effects) :: arg_types t
                  | _ -> []
              in
                arg_types ftype in 

            (*
              FIXME:

              fun (x:a) {x:a} : (b) -> b

              should probably give an error, but doesn't if quantified
              instantiation is switched on.

              Perhaps what we should be doing is filtering out all type
              variables that appear in patterns and type annotations
              from the quantifiers. We could do this by adding them
              to the environment passed to Utils.generalise.

              Needs more thought...
            *)

            let e = `FunLit (Some argss, (List.map (List.map erase_pat) pats, erase body)) in
              if Settings.get_value Instantiate.quantified_instantiation then
                let (qs, _tyargs), ftype = Utils.generalise context.var_env ftype in
                let _, ftype = Instantiate.typ ftype in
                  tabstr (qs, e), ftype
              else
                e, ftype                

        | `ConstructorLit (c, None, _) ->
            let type' = `Variant (Types.make_singleton_open_row 
                                    (c, (`Present, Types.unit_type))
                                    `Any) in
              `ConstructorLit (c, None, Some type'), type'

        | `ConstructorLit (c, Some v, _) ->
            let v = tc v in
            let type' = `Variant (Types.make_singleton_open_row
                                    (c, (`Present, typ v))
                                    `Any) in
              `ConstructorLit (c, Some (erase v), Some type'), type'

        (* database *)
        | `DatabaseLit (name, (driver, args)) ->
            let driver = opt_map tc driver
            and args   = opt_map tc args
            and name   = tc name in
              `DatabaseLit (erase name, (opt_map erase driver, opt_map erase args)), `Primitive `DB

        | `TableLit (tname, (dtype, Some (read_row, write_row, needed_row)), constraints, db) ->
            let tname = tc tname 
            and db = tc db in
            let () = unify ~handle:Gripers.table_name (pos_and_typ tname, no_pos Types.string_type)
            and () = unify ~handle:Gripers.table_db (pos_and_typ db, no_pos Types.database_type) in
              `TableLit (erase tname, (dtype, Some (read_row, write_row, needed_row)), constraints, erase db), 
            `Table (read_row, write_row, needed_row)
        | `DBDelete (pat, from, where) ->
            let pat  = tpc pat in
            let from = tc from in
            let read  = `Record (Types.make_empty_open_row `Base) in
            let write = `Record (Types.make_empty_open_row `Base) in
            let needed = `Record (Types.make_empty_open_row `Base) in
            let () = unify ~handle:Gripers.delete_table
              (pos_and_typ from, no_pos (`Table (read, write, needed))) in
            let () = unify ~handle:Gripers.delete_pattern (ppos_and_typ pat, no_pos read) in

            let inner_effects = Types.make_empty_closed_row () in
            let context' = bind_effects (context ++ pattern_env pat) inner_effects in

            let where = opt_map (type_check context') where in
            let () =
              opt_iter
                (fun e -> unify ~handle:Gripers.delete_where (pos_and_typ e, no_pos Types.bool_type)) where in

            (* delete is wild *)
            let () =
              let outer_effects =
                Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any
              in
                unify ~handle:Gripers.delete_outer
                  (no_pos (`Record context.effect_row), no_pos (`Record outer_effects))
            in
              `DBDelete (erase_pat pat, erase from, opt_map erase where), Types.unit_type
        | `DBInsert (into, labels, values, id) ->
            let into   = tc into in
            let values = tc values in
            let id = opt_map tc id in
            let read  = `Record (Types.make_empty_open_row `Base) in
            let write = `Record (Types.make_empty_open_row `Base) in
            let needed = `Record (Types.make_empty_open_row `Base) in
            let () = unify ~handle:Gripers.insert_table
              (pos_and_typ into, no_pos (`Table (read, write, needed))) in

            let field_env =
              List.fold_right
                (fun name field_env ->
                   if StringMap.mem name field_env then
                     Gripers.die pos "Duplicate labels in insert expression."
                   else
                     StringMap.add name (`Present, Types.fresh_type_variable `Base) field_env)
                labels StringMap.empty in

            (* check that the fields in the type of values match the declared labels *)
            let () =
              unify ~handle:Gripers.insert_values
                (pos_and_typ values,
                 no_pos (Types.make_list_type (`Record (field_env, Unionfind.fresh `Closed)))) in

            let needed_env =
              StringMap.map
                (fun (_f, t) -> Types.fresh_presence_variable (), t)
                field_env in

            (* all fields being inserted must be present in the read row *)
            let () = unify ~handle:Gripers.insert_read
              (no_pos read, no_pos (`Record (field_env, Types.fresh_row_variable `Base))) in

            (* all fields being inserted must be present in the write row *)
            let () = unify ~handle:Gripers.insert_write
              (no_pos write, no_pos (`Record (field_env, Types.fresh_row_variable `Base))) in

            (* all fields being inserted must be consistent with the needed row *)
            let () = unify ~handle:Gripers.insert_needed
              (no_pos needed, no_pos (`Record (needed_env, Unionfind.fresh `Closed))) in

            (* insert returning ... *)
            let return_type =
              match id with
                | None -> Types.unit_type
                | Some (((id : phrasenode), _), _) ->
                    begin
                      match id with
                        | `Constant (`String id) ->
                            (* HACK: The returned column is encoded as
                               a string.  We check here that it
                               appears as a column in the read type of
                               the table.
                            *)
                            unify
                              ~handle:Gripers.insert_id
                              (no_pos read,
                               no_pos (`Record (StringMap.singleton id (`Present, Types.int_type), Types.fresh_row_variable `Base)));
                            Types.int_type
                        | _ -> assert false
                    end in

            (* insert is wild *)
            let () =
              let outer_effects =
                Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any
              in
                unify ~handle:Gripers.insert_outer
                  (no_pos (`Record context.effect_row), no_pos (`Record outer_effects))
            in
              `DBInsert (erase into, labels, erase values, opt_map erase id), return_type
        | `DBUpdate (pat, from, where, set) ->
            let pat  = tpc pat in
            let from = tc from in
            let read =  `Record (Types.make_empty_open_row `Base) in
            let write = `Record (Types.make_empty_open_row `Base) in
            let needed = `Record (Types.make_empty_open_row `Base) in
            let () = unify ~handle:Gripers.update_table
              (pos_and_typ from, no_pos (`Table (read, write, needed))) in

            (* the pattern should match the read type *)
            let () = unify ~handle:Gripers.update_pattern (ppos_and_typ pat, no_pos read) in

            let inner_effects = Types.make_empty_closed_row () in
            let context' = bind_effects (context ++ pattern_env pat) inner_effects in

            let where = opt_map (type_check context') where in

            (* check that the where clause is boolean *)
            let () =
              opt_iter
                (fun e -> unify ~handle:Gripers.update_where (pos_and_typ e, no_pos Types.bool_type)) where in

            let set, field_env =
              List.fold_right
                (fun (name, exp) (set, field_env) ->
                   let exp = type_check context' exp in
                     if StringMap.mem name field_env then
                       Gripers.die pos "Duplicate fields in update expression."
                     else
                       (name, exp)::set, StringMap.add name (`Present, typ exp) field_env)
                set ([], StringMap.empty) in

            let needed_env =
              StringMap.map
                (fun (_f, t) -> Types.fresh_presence_variable (), t)
                field_env in

            (* all fields being updated must be present in the read row *)
            let () = unify ~handle:Gripers.update_read
              (no_pos read, no_pos (`Record (field_env, Types.fresh_row_variable `Base))) in

            (* all fields being updated must be present in the write row *)
            let () = unify ~handle:Gripers.update_write
              (no_pos write, no_pos (`Record (field_env, Types.fresh_row_variable `Base))) in

            (* all fields being updated must be consistent with the needed row *)
            let () = unify ~handle:Gripers.update_needed
              (no_pos needed, no_pos (`Record (needed_env, Types.fresh_row_variable `Base))) in

            (* update is wild *)
            let () =
              let outer_effects =
                Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any
              in
                unify ~handle:Gripers.update_outer
                  (no_pos (`Record context.effect_row), no_pos (`Record outer_effects))
            in
              `DBUpdate (erase_pat pat, erase from, opt_map erase where, 
                         List.map (fun (n,(p,_)) -> n, p) set), Types.unit_type

        (* concurrency *)
        | `Spawn (p, _) ->
            (* (() -e-> _) -> Process (e) *)
            let inner_effects = Types.make_empty_open_row `Any in
            let pid_type = `Application (Types.process, [`Row inner_effects]) in
            let () =
              let outer_effects =
                Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any
              in
                unify ~handle:Gripers.spawn_outer
                  (no_pos (`Record context.effect_row), no_pos (`Record outer_effects)) in
            let p = type_check (bind_effects context inner_effects) p in
              `Spawn (erase p, Some inner_effects), pid_type
        | `SpawnWait (p, _) ->
            (* (() -{b}-> d) -> d *)
            let inner_effects = Types.make_empty_open_row `Any in
            let pid_type = `Application (Types.process, [`Row inner_effects]) in
            let () =
              let outer_effects =
                Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any
              in
                unify ~handle:Gripers.spawn_wait_outer
                  (no_pos (`Record context.effect_row), no_pos (`Record outer_effects)) in
            let p = type_check (bind_effects context inner_effects) p in
            let return_type = typ p in
              `SpawnWait (erase p, Some inner_effects), return_type
        | `Query (range, p, _) ->
            let range, outer_effects =
              match range with
                | None -> None, Types.make_empty_open_row `Any
                | Some (limit, offset) ->
                    let limit = tc limit in
                    let () = unify ~handle:Gripers.range_bound (pos_and_typ limit, no_pos Types.int_type) in
                    let offset = tc offset in
                    let () = unify ~handle:Gripers.range_bound (pos_and_typ offset, no_pos Types.int_type) in
                    let outer_effects =
                      Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any
                    in
                      Some (erase limit, erase offset), outer_effects in
            let inner_effects = Types.make_empty_closed_row () in
            let () = unify ~handle:Gripers.query_outer
              (no_pos (`Record context.effect_row), no_pos (`Record outer_effects)) in
            let p = type_check (bind_effects context inner_effects) p in
            let shape = Types.make_list_type (`Record (StringMap.empty, Types.fresh_row_variable `Base)) in
            let () = unify ~handle:Gripers.query_base_row (pos_and_typ p, no_pos shape) in
              `Query (range, erase p, Some (typ p)), typ p
        | `Receive (binders, _) ->
            let mb_type = Types.fresh_type_variable `Any in
            let effects =
              Types.row_with ("wild", (`Present, Types.unit_type))
                (Types.make_singleton_open_row ("hear", (`Present, mb_type)) `Any) in

            let () = unify ~handle:Gripers.receive_mailbox
              (no_pos (`Record context.effect_row), no_pos (`Record effects)) in

            let binders, pattern_type, body_type = type_cases binders in
            let () = unify ~handle:Gripers.receive_patterns
              (no_pos mb_type, no_pos pattern_type)
            in
              `Receive (erase_cases binders, Some body_type), body_type

        (* applications of various sorts *)
        | `UnaryAppl ((_, op), p) ->
            let tyargs, opt = type_unary_op context op
            and p = tc p
            and rettyp = Types.fresh_type_variable `Any in
              unify ~handle:Gripers.unary_apply
                ((Sugartypes.string_of_unary_op op, opt),
                 no_pos (`Function (Types.make_tuple_type [typ p], context.effect_row, rettyp)));
              `UnaryAppl ((tyargs, op), erase p), rettyp
        | `InfixAppl ((_, op), l, r) ->
            let tyargs, opt = type_binary_op context op in
            let l = tc l
            and r = tc r
            and rettyp = Types.fresh_type_variable `Any in
              unify ~handle:Gripers.infix_apply
                ((Sugartypes.string_of_binop op, opt), 
                 no_pos (`Function (Types.make_tuple_type [typ l; typ r], 
                                    context.effect_row, rettyp)));
              `InfixAppl ((tyargs, op), erase l, erase r), rettyp
        | `RangeLit (l, r) -> 
            let l, r = tc l, tc r in
            let () = unify ~handle:Gripers.range_bound  (pos_and_typ l,
                                                         no_pos Types.int_type)
            and () = unify ~handle:Gripers.range_bound  (pos_and_typ r,
                                                         no_pos Types.int_type)
            in `RangeLit (erase l, erase r),
            Types.make_list_type Types.int_type 
        | `FnAppl (f, ps) ->
            let f = tc f in
            let ps = List.map (tc) ps in

              (*
                We take advantage of this type isomorphism:
                
                forall X.P -> Q == P -> forall X.Q
                where X is not free in P

                What we need to do for:
                
                forall XS.P -> Q

                - instantiate each quantifier in XS
                that is free in P

                - push the other quantifiers
                into the return type

                - generate an appropriate term to
                explicitly witness the isomorphism
                
                For f a we generate /\ZS.f XS a.
              *)
              begin
                match Types.concrete_type (typ f) with
                  | `ForAll (qs, `Function (fps, fe, rettyp)) as t ->
                      (*                       Debug.print ("f: " ^ Show.show show_phrase (erase f));                      *)
                      (*                       Debug.print ("t: " ^ Types.string_of_datatype t); *)
                      
                      (* the free type variables in the arguments (and effects) *)
                      let arg_vars =
                        Types.TypeVarSet.union (Types.free_type_vars fps) (Types.free_row_type_vars fe) in

                      (* return true if this quantifier appears free in the arguments (or effects) *)
                      let free_in_arg q = Types.TypeVarSet.mem (Types.var_of_quantifier q) arg_vars in

                      (*
                        since we've smashed through the quantifiers, we should
                        make any remaining quantifiers flexible
                      *)

                      (* xs is a list of tuples of the shape:
                         (original quantifier, (fresh quantifier, fresh type argument))
                      *)
                      let xs =
                        List.map
                          (fun q ->
                             q, Types.freshen_quantifier_flexible q)
                          (Types.unbox_quantifiers qs) in

                      (* quantifiers for the return type *)
                      let rqs =
                        (fst -<- List.split -<- snd -<- List.split)
                          (List.filter
                             (fun (q, _) -> not (free_in_arg q))
                             xs) in

                      (* type arguments to apply f to *)
                      let tyargs = (snd -<- List.split -<- snd -<- List.split) xs in
                        begin
                          match Instantiate.apply_type t tyargs with
                            | `Function (fps, fe, rettyp) ->
                                let rettyp = Types.for_all (rqs, rettyp) in
                                let ft = `Function (fps, fe, rettyp) in
                                  (*                                   Debug.print ("ft: " ^ Types.string_of_datatype ft); *)
                                let fn, fpos = erase f in
                                let e = tabstr (rqs, `FnAppl ((tappl (fn, tyargs), fpos), List.map erase ps)) in
                                  unify ~handle:Gripers.fun_apply
                                    ((exp_pos f, ft), no_pos (`Function (Types.make_tuple_type (List.map typ ps), 
                                                                         context.effect_row,
                                                                         rettyp)));
                                  e, rettyp
                            | _ ->
                                assert false
                        end
                  | ft ->
                      let rettyp = Types.fresh_type_variable `Any in                        
                        unify ~handle:Gripers.fun_apply
                          ((exp_pos f, ft), no_pos (`Function (Types.make_tuple_type (List.map typ ps), 
                                                               context.effect_row, rettyp)));
                        `FnAppl (erase f, List.map erase ps), rettyp

                  | _ -> assert false
              end
        | `TAbstr (qs, e) ->
            let (e, _), t = tc e in
            let qs = Types.unbox_quantifiers qs in
            let t = Types.for_all(qs, t) in
              tabstr (qs, e), t
        | `TAppl (e, qs) ->
            let (e, _), t = tc e in e, t
                (*            assert false*)
                (* xml *)
        | `Xml (tag, attrs, attrexp, children) ->
            let attrs = alistmap (List.map (tc)) attrs
            and attrexp = opt_map tc attrexp
            and children = List.map (tc) children in
            let () = List.iter
              (snd ->-
                 List.iter (fun attr -> unify ~handle:Gripers.xml_attribute
                              (pos_and_typ attr, no_pos Types.string_type))) attrs
            and () =
              opt_iter
                (fun e ->
                   unify ~handle:Gripers.xml_attributes
                     (pos_and_typ e, no_pos (
                        (Instantiate.alias "Attributes" [] context.tycon_env)))) attrexp
            and () =
              List.iter (fun child ->
                           unify ~handle:Gripers.xml_child (pos_and_typ child, no_pos Types.xml_type)) children in
              `Xml (tag, 
                    List.map (fun (x,p) -> (x, List.map erase p)) attrs,
                    opt_map erase attrexp,
                    List.map erase children), Types.xml_type
        | `TextNode _ as t -> t, Types.xml_type
        | `Formlet (body, yields) ->
            let body = tc body in
            let context' = (context ++ extract_formlet_bindings (erase body)) in
            let yields = type_check context' yields in
              unify ~handle:Gripers.formlet_body (pos_and_typ body, no_pos Types.xml_type);
              (`Formlet (erase body, erase yields),
               Instantiate.alias "Formlet" [`Type (typ yields)] context.tycon_env)
        | `Page e ->
            let e = tc e in
              unify ~handle:Gripers.page_body (pos_and_typ e, no_pos Types.xml_type);
              `Page (erase e), Instantiate.alias "Page" [] context.tycon_env
        | `FormletPlacement (f, h, attributes) ->
            let t = Types.fresh_type_variable `Any in

            let f = tc f
            and h = tc h
            and attributes = tc attributes in
            let () = unify ~handle:Gripers.render_formlet
              (pos_and_typ f, no_pos (Instantiate.alias "Formlet" [`Type t] context.tycon_env)) in
            let () = unify ~handle:Gripers.render_handler
              (pos_and_typ h, (exp_pos f, 
                               Instantiate.alias "Handler" [`Type t] context.tycon_env)) in
            let () = unify ~handle:Gripers.render_attributes
              (pos_and_typ attributes, no_pos (Instantiate.alias "Attributes" [] context.tycon_env))
            in
              `FormletPlacement (erase f, erase h, erase attributes), Types.xml_type
        | `PagePlacement e ->
            let e = tc e in
            let pt = Instantiate.alias "Page" [] context.tycon_env in
              unify ~handle:Gripers.page_placement (pos_and_typ e, no_pos pt);
              `PagePlacement (erase e), Types.xml_type
        | `FormBinding (e, pattern) ->
            let e = tc e
            and pattern = tpc pattern in
            let a = Types.fresh_type_variable `Any in
            let ft = Instantiate.alias "Formlet" [`Type a] context.tycon_env in
              unify ~handle:Gripers.form_binding_body (pos_and_typ e, no_pos ft);
              unify ~handle:Gripers.form_binding_pattern (ppos_and_typ pattern, (exp_pos e, a));
              `FormBinding (erase e, erase_pat pattern), Types.xml_type

        (* various expressions *)
        | `Iteration (generators, body, where, orderby) ->
            let is_query =
              List.exists (function
                             | `List _ -> false
                             | `Table _ -> true) generators in
            let context =              
              if is_query then
                {context with effect_row = Types.make_empty_closed_row ()}
              else
                context in
            let generators, context =
              List.fold_left
                (fun (generators, context) ->
                   function
                     | `List (pattern, e) ->
                         let a = Types.fresh_type_variable `Any in
                         let lt = Types.make_list_type a in
                         let pattern = tpc pattern in
                         let e = tc e in
                         let () = unify ~handle:Gripers.iteration_list_body (pos_and_typ e, no_pos lt) in
                         let () = unify ~handle:Gripers.iteration_list_pattern (ppos_and_typ pattern, (exp_pos e, a))
                         in
                           (`List (erase_pat pattern, erase e) :: generators,
                            context ++ pattern_env pattern)
                     | `Table (pattern, e) ->
                         let a = Types.fresh_type_variable `Any in
                         let tt = Types.make_table_type (a, Types.fresh_type_variable `Any, Types.fresh_type_variable `Any) in
                         let pattern = tpc pattern in
                         let e = tc e in
                         let () = unify ~handle:Gripers.iteration_table_body (pos_and_typ e, no_pos tt) in
                         let () = unify ~handle:Gripers.iteration_table_pattern (ppos_and_typ pattern, (exp_pos e, a)) in
                           (`Table (erase_pat pattern, erase e) :: generators,
                            context ++ pattern_env pattern))
                ([], context) generators in
            let generators = List.rev generators in              
            let tc = type_check context in
            let body = tc body in
            let where = opt_map tc where in
            let orderby = opt_map tc orderby in
            let () =
              unify ~handle:Gripers.iteration_body
                (pos_and_typ body, no_pos (Types.make_list_type (Types.fresh_type_variable `Any))) in
            let () =
              opt_iter (fun where -> unify ~handle:Gripers.iteration_where
                          (pos_and_typ where, no_pos Types.bool_type)) where in

            let () =
              opt_iter
                (fun order ->
                   unify ~handle:Gripers.iteration_base_order
                     (pos_and_typ order, no_pos (`Record (Types.make_empty_open_row `Base)))) orderby in
            let () =
              if is_query then
                unify ~handle:Gripers.iteration_base_body
                  (pos_and_typ body, no_pos (Types.make_list_type (`Record (Types.make_empty_open_row `Base)))) in
            let e = `Iteration (generators, erase body, opt_map erase where, opt_map erase orderby) in
              if is_query then
                `Query (None, (e, pos), Some (typ body)), typ body
              else
                e, typ body
        | `Escape ((name,_,pos), e) ->
            (* There's a question here whether to generalise the
               return type of continuations.  With `escape'
               continuations are let-bound, so generalising the return
               type is sound.  With `call/cc' continuations are
               lambda-bound so the return type cannot be generalised.
               If we do generalise here then we can accept more valid
               programs, since the continuation can then be used in
               any context, e.g.:
               
               escape y in {
               var _ = y(1) == "";
               var _ = y(1) == true;
               2
               }

               However, currently we desugar escape to call/cc, so
               generalising will mean accepting programs that have an
               invalid type in the IR (although they're guaranteed not
               to "go wrong".)

               (Also, should the mailbox type be generalised?)
            *)
            let f = Types.fresh_type_variable `Any in
            let t = Types.fresh_type_variable `Any in

            let eff = Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any in
              (*            let eff = Types.make_empty_open_row `Any in*)

            let cont_type = `Function (Types.make_tuple_type [f], eff, t) in
            let context' = {context 
                            with var_env = Env.bind context.var_env (name, cont_type)} in
            let e = type_check context' e in

            let () =
              let outer_effects =
                Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any
              in
                unify ~handle:Gripers.escape_outer
                  (no_pos (`Record context.effect_row), no_pos (`Record outer_effects)) in

            let () = unify ~handle:Gripers.escape (pos_and_typ e, no_pos f) in
              `Escape ((name, Some cont_type, pos), erase e), typ e
        | `Conditional (i,t,e) ->
            let i = tc i
            and t = tc t
            and e = tc e in
              unify ~handle:Gripers.if_condition
                (pos_and_typ i, no_pos (`Primitive `Bool));
              unify ~handle:Gripers.if_branches
                (pos_and_typ t, pos_and_typ e);
              `Conditional (erase i, erase t, erase e), (typ t)
        | `Block (bindings, e) ->
            let context', bindings = type_bindings context bindings in
            let e = type_check (Types.extend_typing_environment context context') e in
              `Block (bindings, erase e), typ e
        | `Regex r ->
            `Regex (type_regex context r), 
            Instantiate.alias "Regex" [] context.tycon_env
        | `Projection (r,l) ->
            (*
              Take advantage of the type isomorphism:

              forall X.(P, Q) == (forall X.P, forall X.Q)

              Before doing the projection, grab any quantifiers
              and pass them through to the result type.

              If the label matches one of the existing ones
              in the field env then we unify against a singleton
              closed row.

              Otherwise, we instantiate the quantifiers and unify
              against a singleton open row.

            *)
            let r = tc r in
              begin
                match TypeUtils.concrete_type (typ r) with
                  | `ForAll (qs, `Record row) as t ->
                      let xs =
                        List.map
                          (fun q ->
                             q, Types.freshen_quantifier_flexible q)
                          (Types.unbox_quantifiers qs) in

                      (* type arguments to apply r to *)
                      let tyargs = (snd -<- List.split -<- snd -<- List.split) xs in

                      let rt = Instantiate.apply_type t tyargs in
                        
                      let (field_env, row_var) as row =
                        match rt with
                          | `Record row -> fst (Types.unwrap_row row)
                          | _ -> assert false in

                        begin
                          match StringMap.lookup l field_env with
                            | Some (presence, t) ->
                                (* the free type variables in the projected type *)
                                let vars = Types.free_type_vars t in

                                (* return true if this quantifier appears free in the projected type *)
                                let free_in_body q = Types.TypeVarSet.mem (Types.var_of_quantifier q) vars in

                                (* quantifiers for the projected type *)
                                let pqs =
                                  (fst -<- List.split -<- snd -<- List.split)
                                    (List.filter
                                       (fun (q, _) -> free_in_body q)
                                       xs) in

                                let fieldtype = Types.for_all (pqs, t) in

                                (* really we just need to unify the presence variable
                                   with `Presence, but our griper interface doesn't currently
                                   support that *)
                                let rt = `Record (StringMap.singleton l (presence, fieldtype), Types.closed_row_var) in
                                  unify ~handle:Gripers.projection
                                    ((exp_pos r, rt),
                                     no_pos (`Record (Types.make_singleton_closed_row (l, (`Present, Types.fresh_type_variable `Any)))));

                                  let rn, rpos = erase r in
                                  let e = tabstr (pqs, `Projection ((tappl (rn, tyargs), rpos), l)) in
                                    e, fieldtype
                            | None ->
                                let fieldtype = Types.fresh_type_variable `Any in
                                  unify ~handle:Gripers.projection
                                    ((exp_pos r, rt),
                                     no_pos (`Record (Types.make_singleton_open_row 
                                                        (l, (`Present, fieldtype))
                                                        `Any)));

                                  let rn, rpos = erase r in
                                  let e = `Projection ((tappl (rn, tyargs), rpos), l) in
                                    e, fieldtype
                                      
                        end
                  | _ -> 
                      let fieldtype = Types.fresh_type_variable `Any in
                        unify ~handle:Gripers.projection
                          (pos_and_typ r, no_pos (`Record (Types.make_singleton_open_row 
                                                             (l, (`Present, fieldtype))
                                                             `Any)));
                        `Projection (erase r, l), fieldtype
              end
        | `With (r, fields) ->
            let r = tc r in
            let fields = alistmap tc fields in

            let () =
              let fields_type =
                `Record (List.fold_right
                           (fun (lab, _) row ->
                              Types.row_with (lab, (`Present, Types.fresh_type_variable `Any)) row)
                           fields (Types.make_empty_open_row `Any)) in
                unify ~handle:Gripers.record_with (pos_and_typ r, no_pos fields_type) in
            let (rfields, row_var), _ = Types.unwrap_row (TypeUtils.extract_row (typ r)) in
            let rfields =
              StringMap.mapi
                (fun name t ->
                   if List.mem_assoc name fields then
                     `Present, snd (List.assoc name fields)
                   else t)
                rfields
            in
              `With (erase r, alistmap erase fields), `Record (rfields, row_var)
        | `TypeAnnotation (e, (_, Some t as dt)) ->
            let e = tc e in
              unify ~handle:Gripers.type_annotation (pos_and_typ e, no_pos t);
              `TypeAnnotation (erase e, dt), t
        | `Upcast (e, (_, Some t1 as t1'), (_, Some t2 as t2')) ->
            let e = tc e in
              if Types.is_sub_type (t2, t1) then
                begin
                  unify ~handle:Gripers.upcast_source (pos_and_typ e, no_pos t2);
                  `Upcast (erase e, t1', t2'), t1
                end
              else
                Gripers.upcast_subtype pos t2 t1
        | `Switch (e, binders, _) ->
            let e = tc e in
            let binders, pattern_type, body_type = type_cases binders in
            let () = unify ~handle:Gripers.switch_pattern (pos_and_typ e, no_pos pattern_type) in
              `Switch (erase e, erase_cases binders, Some body_type), body_type
    in (e, pos), t

(** [type_binding] takes XXX YYY (FIXME)
    The input context is the environment in which to type the bindings.

    The output context is the environment resulting from typing the
    bindings.  It does not include the input context.
*)
and type_binding : context -> binding -> binding * context =
  fun context (def, pos) ->
    let type_check = type_check in
    let unify pos (l, r) = unify ~pos:pos (l, r)
    and typ (_,t) = t
    and erase (e, _) = e
    and erase_pat (e, _, t) = e
    and pattern_typ (_, _, t) = t
    and tc = type_check context
    and tpc = type_pattern `Closed
    and pattern_env (_, e, _) = e
    and (++) ctxt env' = {ctxt with var_env = Env.extend ctxt.var_env env'} in
    let _UNKNOWN_POS_ = "<unknown>" in
    let no_pos t = (_UNKNOWN_POS_, t) in
    let pattern_pos ((_,p),_,_) = let (_,_,p) = SourceCode.resolve_pos p in p in
    let ppos_and_typ p = (pattern_pos p, pattern_typ p) in
    let uexp_pos (_,p) = let (_,_,p) = SourceCode.resolve_pos p in p in   
    let exp_pos (p,_) = uexp_pos p in
    let pos_and_typ e = (exp_pos e, typ e) in

    let empty_context = empty_context (context.Types.effect_row) in

    let typed, ctxt = match def with
      | `Include _ -> assert false
      | `Val (_, pat, body, location, datatype) -> 
          let body = tc body in
          let pat = tpc pat in
          let penv = pattern_env pat in
          let bt =
            match datatype with
              | Some (_, Some t) ->
                  unify pos ~handle:Gripers.bind_val_annotation (no_pos (typ body), no_pos t);
                  t
              | _ -> typ body in
          let () = unify pos ~handle:Gripers.bind_val (ppos_and_typ pat, (exp_pos body, bt)) in
          let body = erase body in
          let ((tyvars, _), bt), pat, penv =
            if Utils.is_generalisable body then
              let penv = Env.map (snd -<- Utils.generalise context.var_env) penv in
              let pat = update_pattern_vars penv (erase_pat pat) in
                (Utils.generalise context.var_env bt, pat, penv)
            else
              let tyvars = Generalise.get_type_variables context.var_env bt in
                if List.exists (function
                                  | (_, `Rigid, _) -> true
                                  | (_, `Flexible, _) -> false) tyvars
                then
                  Gripers.value_restriction pos bt
                else
                  (([], []), bt), erase_pat pat, penv
          in
            `Val (tyvars, pat, body, location, datatype), 
          {empty_context with
             var_env = penv}
      | `Fun (((name,_,fpos), (_, (pats, body)), location, t) as def) ->
          let () = check_for_duplicate_names pos (List.flatten pats) in
          let pats = List.map (List.map tpc) pats in

          let effects = Types.make_empty_open_row `Any in
          let return_type = Types.fresh_type_variable `Any in

          (** Check that any annotation matches the shape of the function *)
          let ft =
            match t with
              | None ->
                  make_ft pats effects return_type
              | Some (_, Some ft) ->
                  (* make sure the annotation has the right shape *)
                  let shape = make_ft pats effects return_type in
                  let _, fti = Instantiate.typ ft in
                  let () = unify pos ~handle:Gripers.bind_fun_annotation (no_pos shape, no_pos fti) in
                    ft in

          (* type check the body *)
          let fold_in_envs = List.fold_left (fun env pat' -> env ++ (pattern_env pat')) in
          let context' = List.fold_left fold_in_envs context pats in

          let body = type_check (bind_effects context' effects) body in

          (* check that the body type matches the return type of any annotation *)
          let () = unify pos ~handle:Gripers.bind_fun_return (no_pos (typ body), no_pos return_type) in

          (* generalise*)
          let (tyvars, _tyargs), ft = Utils.generalise context.var_env ft in
          let ft = Instantiate.freshen_quantifiers ft in
            (`Fun ((name, Some ft, fpos),
                   (tyvars, (List.map (List.map erase_pat) pats, erase body)),
                   location, t),
             {empty_context with
                var_env = Env.bind Env.empty (name, ft)})
      | `Funs defs ->
          (*
            Compute initial types for the functions using
            - the patterns
            - an optional type annotation
            
            Note that the only way of getting polymorphic recursion is
            to provide a type annotation (generalisation would
            otherwise be unsound as the function types cannot be fully
            known until the definition bodies have been inspected).

            As well as the function types, the typed patterns are also
            returned here as a simple optimisation.  *)

          let fresh_wild () = Types.make_singleton_open_row ("wild", (`Present, Types.unit_type)) `Any in

          let inner_env, patss =
            List.fold_left
              (fun (inner_env, patss) ((name,_,_), (_, (pats, body)), _, t, pos) ->
                 let () = check_for_duplicate_names pos (List.flatten pats) in
                 let pats = List.map (List.map tpc) pats in
                 let inner =
                   match t with
                     | None ->
                         (* Here we're taking advantage of the
                            following equivalence to make the curried
                            arrows polymorphic:

                            fun f(x1)...(xk) {e}
                            ==
                            fun f(x1)...(xk) {
                            fun f(x1)...(xk) {e}
                            f(x1)...(xk)
                            }
                         *)
                         make_ft_poly_curry pats (fresh_wild ()) (Types.fresh_type_variable `Any)
                     | Some (_, Some t) ->
                         let shape = make_ft pats (fresh_wild ()) (Types.fresh_type_variable `Any) in
                         let (_, ft) = Generalise.generalise_rigid context.var_env t in
                           (* make sure the annotation has the right shape *)
                         let _, fti = Instantiate.typ ft in
                         let () = unify pos ~handle:Gripers.bind_rec_annotation (no_pos shape, no_pos fti) in
                           ft
                 in
                   Env.bind inner_env (name, inner), pats::patss)
              (Env.empty, []) defs in
          let patss = List.rev patss in

          (* 
             type check the function bodies using
             - monomorphic bindings for unannotated functions
             - potentially polymorphic bindings for annotated functions
          *)
          let defs =
            let body_env = Env.extend context.var_env inner_env in
            let fold_in_envs = List.fold_left (fun env pat' -> env ++ (pattern_env pat')) in
              List.rev
                (List.fold_left2
                   (fun defs ((name, _, name_pos), (_, (_, body)), location, t, pos) pats ->
                      let context' = (List.fold_left
                                        fold_in_envs {context with var_env = body_env} pats) in
                      let effects = fresh_wild () in
                      let body = type_check (bind_effects context' effects) body in
                      let shape =
                        make_ft pats effects (typ body) in
                        (* it is important to instantiate with rigid
                           type variables in order to ensure that the
                           inferred type is consistent with any
                           annotation *)
                      let ft =
                        let _, ft = Instantiate.rigid context'.var_env name in
                          if Settings.get_value Instantiate.quantified_instantiation then
                            match ft with
                              | `ForAll (_, ft) -> ft
                              | ft -> ft
                          else
                            ft in
                      let () = unify pos ~handle:Gripers.bind_rec_rec (no_pos shape, no_pos ft) in
                        ((name, None, name_pos), (([], None), (pats, body)), location, t, pos) :: defs) [] defs patss) in

          (* Generalise to obtain the outer types *)
          let defs, outer_env =
            let defs, outer_env =
              List.fold_left2
                (fun (defs, outer_env) ((name, _, name_pos), (_, (pats, body)), location, t, pos) pats ->
                   let inner = Env.lookup inner_env name in
                   let inner, outer, tyvars =
                     match inner with
                       | `ForAll (inner_tyvars, inner_body) ->
                           let (tyvars, _tyargs), outer = Utils.generalise context.var_env inner_body in
                           let extras =
                             let has q =
                               let n = Types.type_var_number q in
                                 List.exists (fun q -> Types.type_var_number q = n) (Types.unbox_quantifiers inner_tyvars)
                             in
                               List.map (fun q ->
                                           if has q then None
                                           else Some q) tyvars in
                           let outer = Instantiate.freshen_quantifiers outer in
                           let inner = Instantiate.freshen_quantifiers inner in
                             (inner, extras), outer, tyvars
                       | _ ->
                           let (tyvars, _tyargs), outer = Utils.generalise context.var_env inner in
                           let extras = List.map (fun q -> Some q) tyvars in
                           let outer = Instantiate.freshen_quantifiers outer in
                             (inner, extras), outer, tyvars in

                   let pats = List.map (List.map erase_pat) pats in
                   let body = erase body in
                     (((name, Some outer, name_pos), ((tyvars, Some inner), (pats, body)), location, t, pos)::defs,
                      Env.bind outer_env (name, outer)))
                ([], Env.empty) defs patss
            in
              List.rev defs, outer_env
          in
            `Funs defs, {empty_context with var_env = outer_env}       
              
      | `Foreign ((name, _, pos), language, (_, Some datatype as dt)) ->
          (`Foreign ((name, Some datatype, pos), language, dt),
           (bind_var empty_context (name, datatype)))
      | `Type (name, vars, (_, Some dt)) as t ->
          t, bind_tycon empty_context (name, `Alias (List.map (snd ->- val_of) vars, dt))
      | `Infix -> `Infix, empty_context
      | `Exp e ->
          let e = tc e in
          let () = unify pos ~handle:Gripers.bind_exp
            (pos_and_typ e, no_pos Types.unit_type)
          in
            `Exp (erase e), empty_context
    in 
      (typed, pos), ctxt
and type_regex typing_env : regex -> regex =
  fun m -> 
    let erase (e, _) = e in
    let typ ((_, _), t) = t in
    let no_pos t = ("<unknown>", t) in
    let tr = type_regex typing_env in
      match m with
        | (`Range _ | `Simply _ | `Any  | `StartAnchor | `EndAnchor) as r -> r
        | `Quote r -> `Quote (tr r)
        | `Seq rs -> `Seq (List.map tr rs)
        | `Alternate (r1, r2) -> `Alternate (tr r1, tr r2)
        | `Group r -> `Group (tr r)
        | `Repeat (repeat, r) -> `Repeat (repeat, tr r)
        | `Splice ((pn, pos) as e) -> 
	    let e = type_check typing_env e in
	    let () = unify ~pos:pos ~handle:Gripers.splice_exp
	      (no_pos (typ e), no_pos Types.string_type)
	    in
	      `Splice (erase e)
        | `Replace (r, `Literal s) -> `Replace (tr r, `Literal s)
        | `Replace (r, `Splice e) -> `Replace (tr r, `Splice (erase (type_check typing_env e)))
and type_bindings (globals : context)  bindings =
  let tyenv, bindings =
    List.fold_left
      (fun (ctxt, bindings) (binding : binding) ->
         let binding, ctxt' = type_binding (Types.extend_typing_environment globals ctxt) binding in
           Types.extend_typing_environment ctxt ctxt', binding::bindings)
      (empty_context globals.Types.effect_row, []) bindings
  in
    tyenv, List.rev bindings

let show_pre_sugar_typing = Settings.add_bool("show_pre_sugar_typing",
                                              false, `User)

let binding_purity_check bindings =
  List.iter (fun ((_, pos) as b) ->
               if not (Utils.is_pure_binding b) then
                 Gripers.toplevel_purity_restriction pos b)
    bindings

module Check =
struct
  let program tyenv (bindings, body) =
    try
      Debug.if_set show_pre_sugar_typing
        (fun () ->
           "before type checking: \n"^Show.show show_program (bindings, body));
      let tyenv', bindings = type_bindings tyenv bindings in
      let tyenv' = Types.normalise_typing_environment tyenv' in
        if Settings.get_value check_top_level_purity then
          binding_purity_check bindings; (* TBD: do this only in web mode? *)
        match body with
          | None -> (bindings, None), Types.unit_type, tyenv'
          | Some (_,pos as body) ->
              let body, typ = type_check (Types.extend_typing_environment tyenv tyenv') body in
              let typ = Types.normalise_datatype typ in
                (bindings, Some body), typ, tyenv'
    with
        Unify.Failure (`Msg msg) -> failwith msg

  let sentence tyenv =
    function
      | `Definitions bindings -> 
          let tyenv', bindings = type_bindings tyenv bindings in
          let tyenv' = Types.normalise_typing_environment tyenv' in
            `Definitions bindings, Types.unit_type, tyenv'
      | `Expression (_, pos as body) -> 
          let body, t = (type_check tyenv body) in
          let t = Types.normalise_datatype t in
            `Expression body, t, tyenv
      | `Directive d -> `Directive d, Types.unit_type, tyenv
end
