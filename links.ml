open Getopt
open Utility
open Debug

(* Whether to run the interactive loop *)
let interacting = Settings.add_bool true "interacting"

(* Whether to print types *)
let printing_types = Settings.add_bool true "printing_types"

(* Prompt in interactive mode *)
let ps1 = "links> "

(* Builtin environments *)
let stdenvs = [], Library.type_env

(* shell directives *)
let directives = [
                   "set", (fun (name::value::_) ->
                             match Settings.get_setting_type name with
                               | `Absent -> Printf.fprintf stderr "no such setting : %s\n"  name; flush stderr
                               | `Int  -> Settings.set_value (Settings.lookup_int name) (int_of_string value)
                               | `Bool -> Settings.set_value (Settings.lookup_bool name) (bool_of_string value)
                               | `String -> Settings.set_value (Settings.lookup_string name) value)
                 ]
let execute_directive name args = 
  try List.assoc name directives args 
  with Not_found -> Printf.fprintf stderr "unknown directive : %s\n" name; flush stderr

(* Run unit tests *)
let run_tests () = 
  Settings.set_value interacting false;
(*   Optimiser.test () ; *)
(*   Js.test () *)
  Js.run_tests ()

(* Print a result, including its type if `printing_types' is true. *)
let print_result rtype result = 
  print_string (Result.string_of_result result);
  print_endline (if Settings.get_value(printing_types) then " : "^ Kind.string_of_kind (Inference.remove_mailbox rtype)
                 else "")

(* Read Links source code, then type, optimize and run it. *)
let evaluate ?(handle_errors=Errors.display_errors_fatal stderr) parse (valenv, typeenv) input = 
  Settings.set_value interacting false;
  handle_errors
    (fun input ->
       let exprs =          Performance.measure "parse" parse input in 
       let typeenv, exprs = Performance.measure "type_program" (Inference.type_program typeenv) exprs in
       let exprs =          Performance.measure "optimise_program" Optimiser.optimise_program (typeenv, exprs) in
       let exprs = List.map Syntax.labelize exprs in
       let valenv, result = Performance.measure "run_program" (Interpreter.run_program valenv) exprs in
         print_result (Syntax.node_kind (last exprs)) result;
         (valenv, typeenv), result
    ) input


(* Interactive loop *)
let rec interact envs = 
let evaluate ?(handle_errors=Errors.display_errors_fatal stderr) parse (valenv, typeenv) input = 
  Settings.set_value interacting false;
  handle_errors
    (fun input ->
       match Performance.measure "parse" parse input with 
         | Left exprs -> 
             let typeenv, exprs = Performance.measure "type_program" (Inference.type_program typeenv) exprs in
             let exprs =          Performance.measure "optimise_program" Optimiser.optimise_program (typeenv, exprs) in
             let exprs = List.map Syntax.labelize exprs in
             let valenv, result = Performance.measure "run_program" (Interpreter.run_program valenv) exprs in
               print_result (Syntax.node_kind (last exprs)) result;
               (valenv, typeenv)
         | Right (directive : Sugar.directive) -> 
             begin
               (Utility.uncurry execute_directive) directive;
               (valenv, typeenv)
             end)
    input
in
let error_handler = Errors.display_errors stderr (fun _ -> envs) in
    print_string ps1; flush stdout; 
    interact (evaluate ~handle_errors:error_handler Parse.parse_sentence envs (stdin, "<stdin>"))

let web_program filename = 
  prerr_endline "WARNING: -w flag is unnecessary and deprecated";
  Settings.set_value interacting false;
  Webif.serve_requests filename 

(** testenv
    Test whether an environment variable is set.
    TBD: Move me to Utility *)
let testenv env_var = 
  try 
    let _ = Sys.getenv env_var in true
  with Not_found -> false

let run_file filename = 
  if testenv "REQUEST_METHOD" then
    (Settings.set_value interacting false;
     Webif.serve_requests filename)
  else
    (evaluate Parse.parse_file stdenvs filename;
    ())

let serialize_expr str = 
  Settings.set_value interacting false;
  let [expr] = Parse.parse_string str in
  let _, expr = Inference.type_expression Library.type_env expr in
  let expr_str, env_str = Forms.serialize_exprenv expr [] in
    print_endline expr_str;
    print_endline env_str;
    ()

let set setting value = Some (fun () -> Settings.set_value setting value)
    
let options : opt list = 
    [
      ('d',     "debug",               set Debug.debugging_enabled true, None);
      ('O',     "optimize",            set Optimiser.optimising true,    None);
      (noshort, "measure-performance", set Performance.measuring true,   None);
      ('n',     "no-types",            set printing_types false,         None);
      ('e',     "evaluate",            None,
       Some (ignore -<- evaluate Parse.parse_string stdenvs));
      ('s',     "serialize-expr",      None,                             Some (serialize_expr));
      ('t',     "run-tests",           Some run_tests,                   None);
      ('w',     "web",                 None,                             Some web_program);
    ]

(* main *)
let _ =
  Errors.display_errors_fatal stderr (parse_cmdline options) run_file;
  if Settings.get_value(interacting) then interact stdenvs
