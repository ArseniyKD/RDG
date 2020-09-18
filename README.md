# RDG

RDG, or RISC-V Dot Graph generator, is a small application of ANTLR4 grammars
to create a function call graph of RISC-V assembly source code. The call graph
will have edge labels representing the line of code where the function has been
called. Note: nested function definitions are not supported.

### Acknowledgement:
   The Makefile was provided by Braedy Kuzma as part of CMPUT 415 at the University of Alberta.

# Usage
## Building
   1. Install ANTLR4, git, java (only the runtime is necessary) and graphviz.
   2. In the root directory of this repository, run `make`
   3. The project should now be built and the executable is available in the same directory.

## Using RDG
   1. Once RDG is built, you can use it as so: `rdg <input_risc-v_assembly_file> <output_file>`
   2. This will generate a call graph in the "Dot" language.
   3. You can generate a PDF of the graph as so: `dot -Tpdf <output_file_from_step_1> -o <output_pdf>`
