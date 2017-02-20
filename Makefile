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

###########################################################
# A new dawn cometh

shared: hc_ivl.vpi hc_cvc.vpi hc_mti.vpi

# Icarus verilog
hc.vpi: src/hardcaml_vpi.c
	gcc `iverilog-vpi --cflags` \
		  `iverilog-vpi --ldflags ` src/hardcaml_vpi.c \
			`iverilog-vpi --ldlibs` -g -o hc_ivl.vpi

test.vvp: test.v
	iverilog test.v -o test.vvp

icarus: hc.vpi test.vvp
	vvp -M . -m hc_ivl test.vvp

# CVC64
CVC_INC ?= /home/andyman/dev/bitbucket/janest/ujamjar-janestreet/dev/tools/open-src-cvc.700c/pli_incs
hc_cvc.vpi: src/hardcaml_vpi.c
	gcc -c -g -fPIC \
		-I $(CVC_INC) \
		src/hardcaml_vpi.c 
	ld -G -shared -export-dynamic src/hardcaml_vpi.o -o hc_cvc.vpi

cvcsim: hc_cvc.vpi
	cvcdir/src/cvc64 -q +loadvpi=./hc_cvc.vpi:init_vpi_startup test.v

cvcrun: cvcsim
	./cvcsim

# Modelsim
MTI_INC ?= /home/andyman/intelFPGA/16.1/modelsim_ase/include
hc_mti.vpi: hardcaml_vpi.c
	gcc -m32 -g -fPIC -shared -o hc_mti.vpi \
		-I $(MTI_INC) \
		hardcaml_vpi.c 

mtirun: hc_mti.vpi
	vlib work
	vlog test.v
	vsim -c -pli ./hc_mti.vpi test -do "run -a"

#########

cleaner:
	rm *.o cvcsim *.vvp *.vpi

