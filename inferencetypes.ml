open Utility

type type_var_set = Type_basis.type_var_set

type datatype = [
  | (datatype, row) Type_basis.type_basis
  | `MetaTypeVar of datatype Unionfind.point ]
and field_spec = datatype Type_basis.field_spec_basis
and field_spec_map = field_spec StringMap.t
and row_var = [
  | row Type_basis.row_var_basis
  | `MetaRowVar of row Unionfind.point ]
and row = (datatype, row_var) Type_basis.row_basis

type type_variable = Type_basis.type_variable
type quantifier = Type_basis.quantifier

let string_type = `List (`Primitive `Char)

type inference_expression = (Syntax.position * datatype * string option (* label *)) Syntax.expression'


(* [TODO]
      change the return type of these functions to be IntSet.t
*)
let
    free_type_vars, free_row_type_vars =
  let rec free_type_vars' : type_var_set -> datatype -> int list = fun rec_vars ->
    function
      | `Not_typed               -> []
      | `Primitive _             -> []
      | `TypeVar var             ->
	  if IntSet.mem var rec_vars then
	    []
	  else
	    [var]
      | `Function (from, into)   -> free_type_vars' rec_vars from @ free_type_vars' rec_vars into
      | `Record row              -> free_row_type_vars' rec_vars row
      | `Variant row             -> free_row_type_vars' rec_vars row
      | `Recursive (var, body)    ->
	  if IntSet.mem var rec_vars then
	    []
	  else
	    free_type_vars' (IntSet.add var rec_vars) body
      | `List (datatype)             -> free_type_vars' rec_vars datatype
      | `Mailbox (datatype)          -> free_type_vars' rec_vars datatype
      | `DB                      -> []
      | `MetaTypeVar point       -> free_type_vars' rec_vars (Unionfind.find point)
  and free_row_type_vars' : type_var_set -> row -> int list = 
    fun rec_vars (field_env, row_var) ->
      let field_vars = List.concat (List.map (fun (_, t) -> free_type_vars' rec_vars t) (Types.get_present_fields field_env)) in
      let row_vars =
        match row_var with
	  | `RowVar (Some var) -> [var]
	  | `RowVar None -> []
	  | `RecRowVar (var, row) -> if IntSet.mem var rec_vars then
	      []
	    else
              (free_row_type_vars' (IntSet.add var rec_vars) row)
	  | `MetaRowVar point -> free_row_type_vars' rec_vars (Unionfind.find point)
      in
        field_vars @ row_vars
  in
    ((fun t -> Utility.unduplicate (=) (free_type_vars' IntSet.empty t)),
     (fun t -> Utility.unduplicate (=) (free_row_type_vars' IntSet.empty t)))

type assumption = datatype Type_basis.assumption_basis
type environment = datatype Type_basis.environment_basis



module BasicInferenceTypeOps :
  (Type_basis.BASICTYPEOPS
   with type typ = datatype
   and type row_var' = row_var) =
struct
  type typ = datatype
  type row_var' = row_var

  type field_spec = typ Type_basis.field_spec_basis
  type field_spec_map = typ Type_basis.field_spec_map_basis
  type row = (typ, row_var') Type_basis.row_basis

  let empty_field_env = StringMap.empty
  let closed_row_var = `RowVar None

  let make_type_variable var = `MetaTypeVar (Unionfind.fresh (`TypeVar var))
  let make_row_variable var = `MetaRowVar (Unionfind.fresh (empty_field_env, `RowVar (Some var)))

  let is_closed_row =
    let rec is_closed_row' rec_vars =
      function
	| (_, `RowVar (Some var)) -> IntSet.mem var rec_vars
	| (_, `RowVar None) -> true
	| (_, `RecRowVar (var, row)) ->
	     ((IntSet.mem var rec_vars) or (is_closed_row' (IntSet.add var rec_vars) row))
	| (_, `MetaRowVar point) ->
	    is_closed_row' rec_vars (Unionfind.find point)
    in
      is_closed_row' IntSet.empty

  let get_row_var = fun (_, row_var) ->
    let rec get_row_var' = fun rec_vars -> function
      | `RowVar None -> None
      | `RowVar (Some var) -> Some var
      | `RecRowVar (var, (_, row_var')) ->
	  if IntSet.mem var rec_vars then
	    None
	  else
	    get_row_var' (IntSet.add var rec_vars) row_var'
      | `MetaRowVar point ->
	  get_row_var' rec_vars (snd (Unionfind.find point))
    in
      get_row_var' IntSet.empty row_var
end

let field_env_union : (field_spec_map * field_spec_map) -> field_spec_map =
  fun (env1, env2) ->
    StringMap.fold (fun label field_spec env' ->
		      StringMap.add label field_spec env') env1 env2

let contains_present_fields field_env =
  StringMap.fold
    (fun _ field_spec present ->
       match field_spec with
	 | `Present _ -> true
	 | `Absent -> present
    ) field_env false

let is_flattened_row : row -> bool =
  let rec is_flattened = fun rec_vars -> function
    | (_, `MetaRowVar point) ->
	(match Unionfind.find point with 
	   | (_, `RowVar None) -> false
	   | (field_env', `RowVar (Some _)) ->
	       assert(not (contains_present_fields field_env')); true
	   | (field_env', `RecRowVar (var, rec_row)) ->
	       assert(not (contains_present_fields field_env'));
	       if IntSet.mem var rec_vars then true
	       else is_flattened (IntSet.add var rec_vars) rec_row
	   | (_ , `MetaRowVar _) -> false)
    | (_, `RowVar None) -> true
    | (_, `RowVar (Some _ ))
    | (_, `RecRowVar (_, _)) ->	assert(false)
  in
    is_flattened IntSet.empty

let is_empty_row : row -> bool =
  let rec is_empty = fun rec_vars -> fun (field_env, row_var) ->
    StringMap.is_empty field_env &&
      begin
	match row_var with
	  | `MetaRowVar point ->
	      let (field_env, row_var) = Unionfind.find point
	      in
		StringMap.is_empty field_env &&
		  begin
		    match row_var with
		      | `RowVar _ -> true
		      | `RecRowVar (var, _) when IntSet.mem var rec_vars -> true
		      | `RecRowVar (var, rec_row) -> is_empty (IntSet.add var rec_vars) rec_row
		      | `MetaRowVar point -> is_empty rec_vars (Unionfind.find point)
		  end
	  | `RowVar None -> true
	  | `RowVar (Some _)
	  | `RecRowVar (_, _) -> assert(false)
      end
  in
    is_empty IntSet.empty

(* 
 convert a row to the form (field_env, row_var)
 where row_var is of the form:
    `RowVar None
  | `MetaRowVar (empty, `RowVar (Some var))
  | `MetaRowVar (empty, `RecRowVar (var, rec_row))
 *)
let flatten_row : row -> row =
  let rec flatten_row' : (row Unionfind.point) IntMap.t -> row -> row =
    fun rec_env row ->
      let row' =
	match row with
	  | (field_env, `MetaRowVar point) ->
	      let row' = Unionfind.find point in
		(match row' with
		   | (field_env', `RowVar None) ->
		       field_env_union (field_env, field_env'), `RowVar None
		   | (field_env', `RowVar (Some var)) ->
		       assert(not (contains_present_fields field_env'));
		       if IntMap.mem var rec_env then
			 (field_env, `MetaRowVar (IntMap.find var rec_env))
		       else
		         row
		   | (field_env', `RecRowVar (var, rec_row)) ->
		       assert(not (contains_present_fields field_env'));
		       if IntMap.mem var rec_env then
			 field_env, `MetaRowVar (IntMap.find var rec_env)
		       else
			 (let point' = Unionfind.fresh (field_env', `RecRowVar (var, (StringMap.empty, `RowVar (Some var)))) in
			  let rec_row' = flatten_row' (IntMap.add var point' rec_env) rec_row in
			    Unionfind.change point' (field_env', `RecRowVar (var, rec_row'));
			    field_env_union (field_env, field_env'), `MetaRowVar point')
		   | (_, `MetaRowVar _) ->
		       let field_env', row_var' = flatten_row' rec_env row' in
			 field_env_union (field_env, field_env'), row_var')
	  | (_, `RowVar None) -> row
	  | _ -> assert(false)
      in
	assert (is_flattened_row row');
	row'
  in
    flatten_row' IntMap.empty


(*
 As flatten_row except if the flattened row_var is of the form:

  `MetaRowVar (`RecRowVar (var, rec_row))

then it is unwrapped. This ensures that all the fields are exposed
in field_env.
 *)
let unwrap_row : row -> (row * (int * row) option) =
  let rec unwrap_row' : (row Unionfind.point) IntMap.t -> row -> (row * (int * row) option) =
    fun rec_env -> function
      | (field_env, `MetaRowVar point) as row ->
	  (match Unionfind.find point with
	     | (field_env', `RowVar None) ->
		 (field_env_union (field_env, field_env'), `RowVar None), None
	     | (field_env', `RowVar (Some var)) ->
		 assert(not (contains_present_fields field_env'));
		 if IntMap.mem var rec_env then
		   (field_env, `MetaRowVar (IntMap.find var rec_env)), None
		 else
		   row, None
	     | (field_env', `RecRowVar ((var, body) as rec_row)) ->
		 assert(not (contains_present_fields field_env'));
		 if IntMap.mem var rec_env then
		   (field_env, `MetaRowVar (IntMap.find var rec_env)), Some rec_row
		 else
		   (let point' = Unionfind.fresh (field_env', `RecRowVar (var, (StringMap.empty, `RowVar (Some var)))) in
		    let unwrapped_body, _ = unwrap_row' (IntMap.add var point' rec_env) body in
		      Unionfind.change point' (field_env', `RecRowVar (var, unwrapped_body));
		      let field_env'', row_var' = unwrapped_body in
			(field_env_union ((field_env_union (field_env, field_env')), field_env''), row_var')), Some rec_row
	     | (_, `MetaRowVar _) as row' ->
		 let (field_env', row_var'), rec_row = unwrap_row' rec_env row' in
		   (field_env_union (field_env, field_env'), row_var'), rec_row)
      | (_, `RowVar None) as row -> row, None
      | _ -> assert(false)
  in
    fun row ->
      let unwrapped_row, rec_row = unwrap_row' IntMap.empty row
      in
	assert (is_flattened_row unwrapped_row);
	unwrapped_row, rec_row	

module InferenceTypeOps :
  (Type_basis.TYPEOPS
   with type typ = datatype
   and type row_var = row_var) = Type_basis.TypeOpsGen(BasicInferenceTypeOps)

let empty_var_maps : unit ->
    ((datatype Unionfind.point) IntMap.t ref *
     (row Unionfind.point) IntMap.t ref) =
  fun () ->
    let type_var_map : (datatype Unionfind.point) IntMap.t ref = ref IntMap.empty in
    let row_var_map : (row Unionfind.point) IntMap.t ref = ref IntMap.empty in
      (type_var_map, row_var_map)
    

(*** Conversions ***)

(* implementation *)
let rec inference_type_of_type = fun ((type_var_map, _) as var_maps) -> function
  | `Not_typed -> `Not_typed
  | `Primitive p -> `Primitive p
  | `TypeVar var ->
      if IntMap.mem var (!type_var_map) then
	`MetaTypeVar (IntMap.find var (!type_var_map))
      else
	let point = Unionfind.fresh (`TypeVar var)
	in
	  type_var_map := IntMap.add var point (!type_var_map);
	  `MetaTypeVar point
  | `Function (f, t) -> `Function (inference_type_of_type var_maps f, inference_type_of_type var_maps t)
  | `Record row -> `Record (inference_row_of_row var_maps row)
  | `Variant row -> `Variant (inference_row_of_row var_maps row)
  | `Recursive (var, t) ->
      if IntMap.mem var (!type_var_map) then
	`MetaTypeVar (IntMap.find var (!type_var_map))
      else
	let point = Unionfind.fresh (`TypeVar var)
	in
	  type_var_map := IntMap.add var point (!type_var_map);
	  let t' = `Recursive (var, inference_type_of_type var_maps t) in
	    Unionfind.change point t';
	    `MetaTypeVar point
  | `List (t) -> `List (inference_type_of_type var_maps t)
  | `Mailbox (t) -> `Mailbox (inference_type_of_type var_maps t)
  | `DB -> `DB
and inference_field_spec_of_field_spec var_maps = function
  | `Present t -> `Present (inference_type_of_type var_maps t)
  | `Absent -> `Absent
and inference_row_of_row = fun ((_, row_var_map) as var_maps) -> function
  | fields, `RowVar None ->
      (StringMap.map (inference_field_spec_of_field_spec var_maps) fields, `RowVar None)
  | fields, `RowVar (Some var) ->
      let field_env : field_spec_map = StringMap.map (inference_field_spec_of_field_spec var_maps) fields
      in
	if IntMap.mem var (!row_var_map) then
	  (field_env, `MetaRowVar (IntMap.find var (!row_var_map)))
	else
	  let point = Unionfind.fresh (StringMap.empty, `RowVar (Some var))
	  in
	    row_var_map := IntMap.add var point (!row_var_map);
	    (field_env, `MetaRowVar point)
  | fields, `RecRowVar (var, rec_row) ->
      let field_env : field_spec_map = StringMap.map (inference_field_spec_of_field_spec var_maps) fields
      in
	if IntMap.mem var (!row_var_map) then
	  (field_env, `MetaRowVar (IntMap.find var (!row_var_map)))
	else
	  let point = Unionfind.fresh (StringMap.empty, `RecRowVar (var, (StringMap.empty, `RowVar None)))
	  in
	    row_var_map := IntMap.add var point (!row_var_map);
	    let rec_row' = inference_row_of_row var_maps rec_row in
	      Unionfind.change point (StringMap.empty, `RecRowVar (var, rec_row'));
	      (field_env, `MetaRowVar point)

(* interface *)
let inference_type_of_type = inference_type_of_type (empty_var_maps ())
let inference_field_spec_of_field_spec = inference_field_spec_of_field_spec (empty_var_maps ())
let inference_row_of_row = inference_row_of_row (empty_var_maps ())

(* implementation *)
let rec type_of_inference_type : type_var_set -> datatype -> Types.datatype = fun rec_vars ->
  function
    | `Not_typed -> `Not_typed
    | `Primitive p -> `Primitive p
    | `TypeVar var -> `TypeVar var
    | `Function (f, t) -> `Function (type_of_inference_type rec_vars f, type_of_inference_type rec_vars t)
    | `Record row -> `Record (row_of_inference_row rec_vars row)
    | `Variant row -> `Variant (row_of_inference_row rec_vars row)
    | `Recursive (var, t) ->
	if IntSet.mem var rec_vars then
	  `TypeVar var
	else
	  `Recursive (var, type_of_inference_type (IntSet.add var rec_vars) t)
    | `List (t) -> `List (type_of_inference_type rec_vars t)
    | `Mailbox (t) -> `Mailbox (type_of_inference_type rec_vars t)
    | `DB -> `DB
    | `MetaTypeVar point -> type_of_inference_type rec_vars (Unionfind.find point)
and field_spec_of_inference_field_spec = fun rec_vars ->
  function
    | `Present t -> `Present (type_of_inference_type rec_vars t)
    | `Absent -> `Absent
and row_of_inference_row = fun rec_vars row ->
  let field_env, row_var = flatten_row row in
  let field_env' = StringMap.map (field_spec_of_inference_field_spec rec_vars) field_env in
  let row_var' = row_var_of_inference_row_var rec_vars row_var
  in
    field_env', row_var'
and row_var_of_inference_row_var = fun rec_vars -> function
  | `MetaRowVar point ->
      begin
	match Unionfind.find point with
	  | (env, `RowVar var) ->
	      assert(not (contains_present_fields env));
	      `RowVar var
	  | (_, `RecRowVar (var, rec_row)) ->
	      if IntSet.mem var rec_vars then
		`RowVar (Some var)
	      else
		`RecRowVar (var, row_of_inference_row (IntSet.add var rec_vars) rec_row)
	  | (_, (`MetaRowVar _ as rv)) -> row_var_of_inference_row_var rec_vars rv (* assert(false)*)
       end
  | `RowVar None ->
      `RowVar None
  | `RowVar (Some _) ->
      assert(false)
  | `RecRowVar (_, _) ->
      assert(false)

(* implementation and interface *)

(* interface *)
let type_of_inference_type = type_of_inference_type IntSet.empty
let field_spec_of_inference_field_spec = field_spec_of_inference_field_spec IntSet.empty
let row_of_inference_row = row_of_inference_row IntSet.empty
let row_var_of_inference_row_var = row_var_of_inference_row_var IntSet.empty


(* assumptions *)
let inference_assumption_of_assumption : Types.assumption -> assumption = function
  | (quantifiers, t) -> (quantifiers, inference_type_of_type t)
let assumption_of_inference_assumption : assumption -> Types.assumption = function
  | (quantifiers, t) -> (quantifiers, type_of_inference_type t)

(* environments *)
let inference_environment_of_environment : Types.environment -> environment =
  List.map (fun (name, assumption) -> (name, inference_assumption_of_assumption assumption))
let environment_of_inference_environment : environment -> Types.environment =
  List.map (fun (name, assumption) -> (name, assumption_of_inference_assumption assumption))

(* conversions between expressions and inference expressions *)
let inference_expression_of_expression : Syntax.expression -> inference_expression =
  Syntax.redecorate (fun (pos, t, label) -> (pos, inference_type_of_type t, label))
let expression_of_inference_expression : inference_expression -> Syntax.expression =
  Syntax.redecorate (fun (pos, t, label) -> (pos, type_of_inference_type t, label))

(* output as a string *)
let string_of_datatype = Types.string_of_datatype -<- type_of_inference_type
let string_of_datatype_raw = Types.string_of_datatype_raw -<- type_of_inference_type
let string_of_row : row -> string = Types.string_of_row -<- row_of_inference_row
let string_of_row_var : row_var -> string = Types.string_of_row_var -<- row_var_of_inference_row_var

let string_of_assumption = Types.string_of_assumption -<- assumption_of_inference_assumption
let string_of_environment = Types.string_of_environment -<- environment_of_inference_environment
