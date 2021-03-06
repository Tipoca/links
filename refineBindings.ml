open Utility
open Sugartypes

(** [refine_bindings] locates mutually-recursive sccs in sequences of
    bindings.  (As a side effect we also dispense with [`Infix]
    declarations, which are only used during the parsing stage.)
*)
let refine_bindings : binding list -> binding list =
  fun bindings -> 
    (* Group sequences of functions together *)
    let initial_groups = 
      let add group groups = match group with
        | [] -> groups
        | _  -> List.rev group::groups in
      (* Technically it shouldn't be necessary to ensure that the
         order of functions defined within a group is preserved (the
         List.rev above), but it helps with debugging, and it turns
         out to be necessary in order for desugaring of for
         comprehensions to work properly in the prelude - which
         defines concatMap. *)
      let group, groups = 
        List.fold_right
          (fun (binding,_ as bind) (thisgroup, othergroups) -> 
            match binding with
              | `Funs _ -> assert false
              | `Exp _
              | `Foreign _
              | `Include _
              | `Type _
              | `Val _ ->
                  (* collapse the group we're collecting, then start a
                     new empty group *)
                  ([], add [bind] (add thisgroup othergroups))
                | `Fun _ ->
                     (* Add binding to group *)
                  (bind::thisgroup, othergroups)
                | `Infix -> 
                     (* discard binding *)
                  (thisgroup, othergroups))
            bindings ([], [])
      in
        add group groups
    in 
      (* build a callgraph *)
    let callgraph : _ -> (string * (string list)) list
      = fun defs -> 
        let defs = List.map (function
                               | `Fun ((name,_,_), (_, funlit), _, _), _ -> (name, funlit)
                               | _ -> assert false) defs in
        let names = StringSet.from_list (List.map fst defs) in
          List.map
            (fun (name, body) -> name, 
               StringSet.elements 
                 (StringSet.inter (Freevars.funlit body) names))
            defs in
      (* refine a group of function bindings *)
    let groupFuns pos (funs : binding list) : binding list = 
      let unFun = function
        | `Fun (b, (_, funlit), location, dt), pos -> (b, (([], None), funlit), location, dt, pos)
        | _ -> assert false in
      let find_fun name = 
        List.find (function
                     | `Fun ((n,_,_), _, _, _), _ when name = n -> true
                     | _ -> false) 
          funs in
      let graph = callgraph funs in
      let sccs = Graph.topo_sort_sccs graph in
        List.map
          (fun scc ->
             let funs = List.map (find_fun ->- unFun) scc in
               match funs with
                 | [(((n, _, _) as b), ((tyvars, _), body), location, dt, pos)]
                     when not (StringSet.mem n (Freevars.funlit body)) -> `Fun (b, (tyvars, body), location, dt), pos
                 | _ -> `Funs (funs), pos)
      
          sccs
    in 
      (* refine a group of bindings *)
    let group = function
        (* TODO:
           
           Compute the position corresponding to the whole collection
           of functions.
        *)
      | (`Fun _, _)::_ as funs -> groupFuns (Lexing.dummy_pos, Lexing.dummy_pos, None) funs
      | binds                    -> binds in
      concat_map group initial_groups

let refine_bindings =
object (self)
  inherit SugarTraversals.map as super
  method phrasenode : phrasenode -> phrasenode = function
    |`Block (bindings, body) -> 
       let bindings = self#list (fun o -> o#binding) bindings in
       let body = self#phrase body in
         `Block (refine_bindings bindings, body)
    | p -> super#phrasenode p

  method program : program -> program =
    fun (bindings, body) ->
      let bindings = self#list (fun o -> o#binding) bindings in
      let body = self#option (fun o -> o#phrase) body in
        refine_bindings bindings, body

  method sentence : sentence -> sentence = function
    |`Definitions defs -> 
       let defs = self#list (fun o -> o#binding) defs in
         `Definitions (refine_bindings defs)
    | d -> super#sentence d
end
