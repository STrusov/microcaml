let env_vars = [|
   "SHELL";
   "LANGUAGEG";
   "LANGUAGE";
   "LANGUAG";
   "PATH";
   "USER";
|]

let print_env name = print_string (name ^
   (try "=" ^ Sys.getenv name with Not_found -> " неопределена"));
   print_newline ()
;;

Array.iter print_env env_vars

