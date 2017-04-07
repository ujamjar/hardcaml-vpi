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

let mti_inc = getenv "MTI_PATH"

let cvc_inc = "???" (* how can we find this path? 
                       (assuming we can get the simulator to work at all!) *)

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
    rule "cosim_ocaml_linker"
      ~prods:["src/cosim.vpi"]
      ~deps:["src/cosim_c.o"; "src/cosim_icarus.byte.o"]
      (fun env _ ->
        Cmd(S[
          A"cc"; A"-o"; A"cosim.vpi"; 
            (* flags for linking icarus vpi objects *)
            t["vpi_ldflags"];
            A"cosim_icarus.byte.o"; A"src/cosim_c.o";
            (* path to ocaml libs *)
            t["ocaml_ldpath"];
            (* path to ctypes libs *)
            t["ctypes_ldpath"];
            (* required libraries *)
            S(List.map (fun l -> A("-l"^l)) libs);
            (* required icarus verilog libraries *)
            t["vpi_ldlibs"];
            A"-Wl,-E"
        ]));

    rule "hc_ivl.vpi"
      ~prods:["hc_ivl.vpi"]
      ~deps:["src/hardcaml_vpi.c"]
      (fun env _ ->
         Cmd(S[
             A"gcc"; 
             Sh"`iverilog-vpi --cflags`"; 
             Sh"`iverilog-vpi --ldflags `"; 
             Sh"`iverilog-vpi --ldlibs`"; 
             A"src/hardcaml_vpi.c";
             A"-g"; A"-o"; A"hc_ivl.vpi" ]));

    rule "hc_cvc.vpi"
      ~prods:["hc_cvc.vpi"]
      ~deps:["src/hardcaml_vpi.c"]
      (fun env _ ->
         let c s = Cmd(S(List.map (fun x -> A x) (split ((=)' ') s))) in
         Seq[
           c("gcc -c -g -fPIC -I "^cvc_inc^" src/hardcaml_vpi.c");
           c"ld -G -shared -export-dynamic hardcaml_vpi.o -o hc_cvc.vpi";
         ]);

    rule "hc_mti.vpi"
      ~prods:["hc_mti.vpi"]
      ~deps:["src/hardcaml_vpi.c"]
      (fun env _ ->
        let c s = Cmd(S(List.map (fun x -> A x) (split ((=)' ') s))) in
	      c("gcc -m32 -g -fPIC -shared -o hc_mti.vpi -I "^mti_inc^" src/hardcaml_vpi.c"));

  end
  | _ -> ()

