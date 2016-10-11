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

VPI_CFLAGS=`iverilog-vpi --cflags`
VPI_LDFLAGS=`iverilog-vpi --ldflags`
VPI_LDLIBS=`iverilog-vpi --ldlibs`
OCAML_LDPATH=`ocamlc -where`
CTYPES_LDPATH=`opam config var ctypes:lib`

vpi:
	VPI_CFLAGS=${VPI_CFLAGS} \
	VPI_LDFLAGS=${VPI_LDFLAGS} \
	VPI_LDLIBS=${VPI_LDLIBS} \
	OCAML_LDPATH=${OCAML_LDPATH} \
	CTYPES_LDPATH=${CTYPES_LDPATH} \
	ocaml pkg/pkg.ml build

clean:
	ocamlbuild -clean
	- find . -name "*~" | xargs rm

