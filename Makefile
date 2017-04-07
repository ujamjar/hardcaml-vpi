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

WITH_IVL=$(shell (which iverilog-vpi > /dev/null 2>&1 && echo true) || echo false)
WITH_MTI=$(shell (which vsim > /dev/null 2>&1 && echo true) || echo false)

VPI_CFLAGS=`iverilog-vpi --cflags`
VPI_LDFLAGS=`iverilog-vpi --ldflags`
VPI_LDLIBS=`iverilog-vpi --ldlibs`
MTI_PATH=$(shell dirname `which vsim`)/../include
OCAML_LDPATH=`ocamlc -where`
CTYPES_LDPATH=`opam config var ctypes:lib`

pkg/META: pkg/META.in
	cp pkg/META.in pkg/META

vpi: pkg/META
	VPI_CFLAGS=${VPI_CFLAGS} \
	VPI_LDFLAGS=${VPI_LDFLAGS} \
	VPI_LDLIBS=${VPI_LDLIBS} \
	MTI_PATH=${MTI_PATH} \
	OCAML_LDPATH=${OCAML_LDPATH} \
	CTYPES_LDPATH=${CTYPES_LDPATH} \
	ocaml pkg/pkg.ml build \
		--with-ivl $(WITH_IVL) \
		--with-mti $(WITH_MTI)

clean:
	ocamlbuild -clean
	rm -f *~
	rm -f src/*~
	rm -f transcript verilog.log
	rm -fr work

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

#########

cleaner:
	rm *.o cvcsim *.vvp *.vpi

