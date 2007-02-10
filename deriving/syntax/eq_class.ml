#load "pa_extend.cmo";;
#load "q_MLast.cmo";;

open Deriving
include Deriving.Struct_utils(struct let classname="Eq" let defaults = "Eq_defaults" end)

let currentp currents = function
| None -> false
| Some (_, s) -> List.mem_assoc s currents

let module_name currents = function
| None -> assert false
| Some (_, s) -> List.assoc s currents

let gen_printer =
  let current default (t:MLast.ctyp) gen ({loc=loc;currents=currents} as ti) c = 
    let lt = ltype_of_ctyp t in
    if currentp currents lt then 
      <:module_expr< $uid:(module_name currents lt)$ >>
    else default t gen ti c
  in 
  gen_module_expr
    ~tyapp:(current gen_app)
    ~tylid:(current gen_lid)
    ~tyrec:gen_other 
    ~tysum:gen_other
    ~tyvrn:gen_other

let gen_printers ({loc=loc} as ti) tuplel tupler params = 
 let m = (List.fold_left
            (fun s param -> <:module_expr< $s$ $param$ >>)
            <:module_expr< $uid:Printf.sprintf "Eq_%d" (List.length params)$ >>
            (List.map (gen_printer ti) params)) in
   <:expr< let module S = $m$ in S.eq $tuplel$ $tupler$ >>

(* Generate a printer for each constructor parameter *)
let gen_case ti (loc, name, params) =
  match params with
    | []  ->  <:patt< ($uid:name$, $uid:name$) >>, None, <:expr< True >>
    | [p] ->  <:patt< ($uid:name$ l, $uid:name$ r) >>, 
                None, 
              <:expr< let module M = $gen_printer ti p$ in M.eq l r >>
    | ps  -> let names = List.map (fun n -> 
                                     let l, r = Printf.sprintf "l%d" n, Printf.sprintf "r%d" n in
                                       (<:patt< $lid:l$ >>, <:patt< $lid:r$ >>, <:expr< $lid:l$ >>, <:expr< $lid:r$ >>))
                                  (range 0 (List.length ps - 1)) in 
             let pattl = <:patt< ( $list:List.map (fun (l,_,_,_)->l) names$)>>
             and pattr = <:patt< ( $list:List.map (fun (_,r,_,_)->r) names$)>>
             and exprl = <:expr< ( $list:List.map (fun (_,_,l,_)->l) names$)>>
             and exprr = <:expr< ( $list:List.map (fun (_,_,_,r)->r) names$)>> in
        (<:patt< ($uid:name$ $pattl$, $uid:name$ $pattr$) >>,
         None,
         gen_printers ti exprl exprr params)

(* Generate the format function, the meat of the thing. *)
let gen_eq_sum ({loc=loc} as ti) ctors = 
  let matches = (List.map (gen_case ti) ctors) @ [<:patt<_>>, None, <:expr< False>>] in
<:str_item< 
   value rec eq l r = match (l, r) with
       [ $list:matches$ ]
>>

let gen_eq_record ({loc=loc}as ti) fields = 
  failwith "gen_eq_record nyi"

let gen_polycase ({loc=loc; tname=tname} as ti) = function
| MLast.RfTag (name, _ (* what is this? *), params') ->
    failwith "gen_polycase nyi"
| MLast.RfInh (<:ctyp< $lid:tname$ >> as ctyp) -> 
    failwith "gen_polycase nyi"
| MLast.RfInh _ -> error loc ("Cannot generate eq instance for " ^ tname)



let gen_eq_polyv ({loc=loc;tname=tname} as ti) (row,_) =
<:str_item< 
   value rec eq = 
             fun [ $list:List.map (gen_polycase ti) row$ ]
>>

let gen_module_expr ti = 
  gen_module_expr ti
    ~tyrec:(fun _ _ ti fields -> apply_defaults ti (gen_eq_record ti fields))
    ~tysum:(fun _ _ ti ctors -> apply_defaults ti (gen_eq_sum ti ctors))
    ~tyvrn:(fun _ _ ti row -> apply_defaults ti (gen_eq_polyv ti row))
    ti.rtype

let gen_instances loc tdl = gen_finstances ~gen_module_expr:gen_module_expr loc ~tdl:tdl
let _ = 
  begin
    instantiators := ("Eq", gen_instances):: !instantiators;
    sig_instantiators := ("Eq", Sig_utils.gen_sigs "Eq"):: !sig_instantiators;
  end
