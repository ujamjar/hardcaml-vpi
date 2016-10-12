open Ocamlbuild_plugin

let rec split at_ str = 
  let length = String.length str in
  let rec f prev i = 
    if i = length then 
      if i=prev then []
      else String.sub str prev (i-prev) :: []
    else
      if at_ str.[i] then
        if i=prev then f (prev+1) (i+1) 
        else String.sub str prev (i-prev) :: f (i+1) (i+1)
      else
        f prev (i+1) 
  in
  f 0 0

let vpi_cflags = getenv "VPI_CFLAGS"
let vpi_ldflags = getenv "VPI_LDFLAGS"
let vpi_ldlibs = getenv "VPI_LDLIBS"
let ocaml_ldpath = getenv "OCAML_LDPATH"
let ctypes_ldpath = getenv "CTYPES_LDPATH"

let libs = [
  (* ocaml stdlib *)
  "unix"; "bigarray"; "camlstr"; "nums";
  (* ctypes *)
  "ctypes_stubs"; "ctypes-foreign-base_stubs"; "ffi"; "dl"; 
  (* ocaml runtime *)
  "camlrun_shared"; 
  "m";
]

let () = dispatch @@ function
  | Before_options -> Options.use_ocamlfind := true
  | After_rules -> begin
    let t l = T(Tags.of_list l) in

    flag ["ocaml_verbose"; "ocaml"; "compile"] @@ S[A"-verbose"];
    flag ["ocaml_versboe"; "ocaml"; "link"] @@ S[A"-verbose"];

    (* add flag not available in ocaml 4.01.0 (which uses ocamlbuild.0) *)
    flag ["link"; "ocaml"; "output_obj"] @@ A"-linkpkg";

    let args f l = List.map f (split ((=)' ') l) in

    (* cosim_c.c should be compiled against the iverilog-vpi header/flags *)
    flag ["compile"; "c"; "iverilog"] @@ 
      S(List.concat @@ args (fun a -> [A"-ccopt";P a]) vpi_cflags);

    (* various bits of the link command *)
    flag ["vpi_cflags"] @@ S(args (fun x -> P x) vpi_cflags);
    flag ["vpi_ldflags"] @@ S(args (fun x -> P x) vpi_ldflags);
    flag ["vpi_ldlibs"] @@ S(args (fun x -> P x) vpi_ldlibs);
    flag ["ocaml_ldpath"] @@ A("-L"^ocaml_ldpath);
    flag ["ctypes_ldpath"] @@ A("-L"^ctypes_ldpath);

    (* link the vpi object *)
    rule "linkerizer"
      ~prods:["cosim.vpi"]
      ~deps:["cosim_c.o"; "cosim_icarus.byte.o"]
      (fun env _ ->
        Cmd(S[
          A"cc"; A"-o"; A"cosim.vpi"; 
            (* flags for linking icarus vpi objects *)
            t["vpi_ldflags"];
            A"cosim_icarus.byte.o"; A"cosim_c.o";
            (* path to ocaml libs *)
            t["ocaml_ldpath"];
            (* path to ctypes libs *)
            t["ctypes_ldpath"];
            (* required libraries *)
            S(List.map (fun l -> A("-l"^l)) libs);
            (* required icarus verilog libraries *)
            t["vpi_ldlibs"];
            A"-Wl,-E"
        ]))

  end
  | _ -> ()

