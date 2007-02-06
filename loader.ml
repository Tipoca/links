open Performance

let `T (pos, dt, _) = Syntax.no_expr_data

let expunge_source_pos = 
  (Syntax.Functor_expression'.map 
     (fun (`T (_,_,l)) -> `T (pos, dt, l)))

let expunge_all_source_pos =
  List.map expunge_source_pos

let with_open_in_bin_file fname op = 
  let fhandle = open_in_bin fname in
  let result = op fhandle in
    close_in fhandle;
    result

let with_open_out_bin_file fname op = 
  let fhandle = open_out_bin fname in
  let result = op fhandle in
    close_out fhandle;
    result

let newer f1 f2 = 
   ((Unix.stat f1).Unix.st_mtime > (Unix.stat f2).Unix.st_mtime) 
  
let read_file_cache filename : (Inferencetypes.typing_environment * Syntax.expression list) = 
  let cachename = filename ^ ".cache" in
    try
      if newer cachename filename then
        with_open_in_bin_file cachename
          (fun cachefile ->
             (Marshal.from_channel cachefile 
                : (Inferencetypes.typing_environment *Syntax.expression list)))
          (* (OCaml manual recommends putting a type signature on unmarshal 
             calls; not clear whether this actually helps. It seems we get 
             a segfault if the marhsaled data is not the right type.) *)
      else
        (Debug.print("No precompiled " ^ filename);
         raise (Sys_error "Precompiled source file out of date."))
    with (Sys_error _| Unix.Unix_error _) ->
      let exprs = measure "parse" (Parse.parse_file Parse.program) filename in
      let env, exprs = measure "type" (Inference.type_program Library.typing_env) exprs in
      let exprs = measure "optimise" Optimiser.optimise_program (env, exprs)in
      let env, exprs =
        env, List.map Syntax.labelize exprs 
      in 
	(try (* try to write to the cache *)
           with_open_out_bin_file cachename 
             (fun cachefile ->
                Marshal.to_channel cachefile 
                  (env, (expunge_all_source_pos exprs))
                  [Marshal.Closures])
	 with _ -> ()) (* Ignore errors writing the cache file*);
        Debug.print (Utility.mapstrcat "\n" Syntax.labelled_string_of_expression exprs);
        env, exprs
