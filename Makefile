########################################
# hardcaml - hardware design in OCaml
#
#   (c) 2014 MicroJamJar Ltd
#
# Author(s): andy.ray@ujamjar.com
# Description: 
#
########################################

.PHONY: all vpi clean tags prepare publish

all: vpi

VPI_CFLAGS=`iverilog-vpi --cflags`
VPI_LDFLAGS=`iverilog-vpi --ldflags`
VPI_LDLIBS=`iverilog-vpi --ldlibs`
OCAML_LDPATH=`ocamlc -where`
CTYPES_LDPATH=`opam config var ctypes:lib`

pkg/META: pkg/META.in
	cp pkg/META.in pkg/META

vpi: pkg/META
	VPI_CFLAGS=${VPI_CFLAGS} \
	VPI_LDFLAGS=${VPI_LDFLAGS} \
	VPI_LDLIBS=${VPI_LDLIBS} \
	OCAML_LDPATH=${OCAML_LDPATH} \
	CTYPES_LDPATH=${CTYPES_LDPATH} \
	ocaml pkg/pkg.ml build

clean:
	ocamlbuild -clean
	- find . -name "*~" | xargs rm

VERSION      := $$(opam query --version)
NAME_VERSION := $$(opam query --name-version)
ARCHIVE      := $$(opam query --archive)

tag:
	git tag -a "v$(VERSION)" -m "v$(VERSION)."
	git push origin v$(VERSION)

prepare:
	opam publish prepare -r hardcaml $(NAME_VERSION) $(ARCHIVE)

publish:
	opam publish submit -r hardcaml $(NAME_VERSION)
	rm -rf $(NAME_VERSION)

