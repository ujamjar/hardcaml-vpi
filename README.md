# HardCaml Verilog interface

Builds an OCaml socket server as an Icarus Verilog VPI
module.  The OCaml module accesses the simulator VPI APIs and
exposes a simple interface API to control/query a simulation
over a socket.

```
+--------------+
|  iverilog    |
| +----------+ |
| |simulation| |
| +----------+ |
|     | (vpi)  |
| +----------+ |
| | HardCaml | |
| |   vpi    | |
| |shared lib| |
| +----------+ |
+--------------+
      | (socket)
+--------------+
|   HardCaml   |
|   testbench  |
+--------------+
```

* Build a testbench in OCaml for a Verilog model

* Generate Verilog from a HardCaml design and use Icarus Verilog as a simulation backend.

