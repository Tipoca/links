open Utility
open Performance

let `T (pos, dt, _) = Syntax.no_expr_data

let identity x = x

let expunge_source_pos =
  (Syntax.Functor_expression'.map
     (fun (`T (_,_,l)) -> `T (pos, dt, l)))

let expunge_all_source_pos =
  Syntax.transform_program expunge_source_pos

let newer f1 f2 = 
   ((Unix.stat f1).Unix.st_mtime > (Unix.stat f2).Unix.st_mtime) 
  
let make_cache = true

let read_file_cache : string -> (Types.typing_environment * Syntax.program) = fun filename ->
  let cachename = filename ^ ".cache" in
    try
      if make_cache && newer cachename filename then
        call_with_open_infile cachename ~binary:true
          (fun cachefile ->
             (Marshal.from_channel cachefile 
                : (Types.typing_environment * Syntax.program)))
          (* (OCaml manual recommends putting a type signature on unmarshal 
             calls; not clear whether this actually helps. It seems we get 
             a segfault if the marhsaled data is not the right type.) *)
      else
        (Debug.print("No precompiled " ^ filename);
         raise (Sys_error "Precompiled source file out of date."))
    with (Sys_error _| Unix.Unix_error _) ->
      let sugar, pos_context = measure "parse" (Parse.parse_file ~pp:(Settings.get_value Basicsettings.pp) Parse.program) filename in
      let resolve = Parse.retrieve_code pos_context in
      let (bindings, expr), _, _ = Frontend.Pipeline.program Library.typing_env resolve sugar in
      let defs = Sugar.desugar_definitions resolve bindings in
      let expr = opt_map (Sugar.desugar_expression resolve) expr in
      let program = Syntax.Program (defs, from_option (Syntax.unit_expression (`U Syntax.dummy_position)) expr) in
      let env, program = measure "type" (Inference.type_program Library.typing_env) program in
      let program = measure "optimise" Optimiser.optimise_program (env, program) in
      let program = Syntax.labelize program
      in 
	(try (* try to write to the cache *)
           call_with_open_outfile cachename ~binary:true
             (fun cachefile ->
                Marshal.to_channel cachefile 
                  (env, expunge_all_source_pos program)
                  [Marshal.Closures])
	 with _ -> ()) (* Ignore errors writing the cache file *);
        env, program
  
let dump_cached filename =
   let env, program = read_file_cache filename in
     print_string (Syntax.labelled_string_of_program program)
