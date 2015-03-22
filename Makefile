########################################
# hardcaml - hardware design in OCaml
#
#   (c) 2014 MicroJamJar Ltd
#
# Author(s): andy.ray@ujamjar.com
# Description: 
#
########################################

.PHONY: all vpi install uninstall clean 

all: vpi

# icarus verilog VPI cosim interface
vpi: 
	ocamlbuild -use-ocamlfind $(BUILD_OPTS) cosim_icarus.cmo vpi.cmo
	ocamlfind c -output-obj -package bigarray,num,hardcaml,ctypes.foreign -linkpkg -o cosim_o.o \
		_build/vpi.cmo _build/cosim_icarus.cmo
	mv cosim_o.o _build/cosim_o.o
	ocamlfind c -c -ccopt "`iverilog-vpi --cflags` -o _build/cosim_c.o" -g cosim_c.c 
	$(CC) -o _build/cosim.vpi \
		`iverilog-vpi --ldflags` \
		_build/cosim_o.o _build/cosim_c.o \
		-L`ocamlc -where` \
		-L`opam config var lib`/ctypes \
		-lunix -lbigarray -lcamlstr \
		-lctypes_stubs -lctypes-foreign-base_stubs \
		-lcamlrun_shared -lffi -ldl -lm \
		`iverilog-vpi --ldlibs` \
		-Wl,-E

install:
	ocamlfind install hardcaml-vpi META \
		hardcaml_vvp.sh _build/cosim.vpi

uninstall: 
	ocamlfind remove hardcaml-vpi

clean:
	ocamlbuild -clean
	- find . -name "*~" | xargs rm

