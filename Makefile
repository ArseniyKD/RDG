# -----------
# | This section finds your ANTLR install for linking and including.
# -----------
# Get the ANTLR install location.
ANTLRI:=${ANTLR_INS}/include/antlr4-runtime/
ANTLRS:=${ANTLR_INS}/lib/libantlr4-runtime.a

# -----------
# | This section builds generic file name suffixes for generated files.
# -----------
# The stems of all the compilable files.
GEN_COMP_NAME_STEM:=BaseListener Listener BaseVisitor Visitor Lexer Parser

# The stems of all the non-compilable files.
GEN_NONCOMP_NAME_STEM:=.interp .tokens Lexer.interp Lexer.tokens

# Apply required file extensions to the stems of compilable files based on
# language to get generated compilable file names that are only missing the
# grammar prefix.
GEN_COMP_NAME_STEM_CPP:=$(foreach file, $(GEN_COMP_NAME_STEM), \
										$(file).cpp $(file).h)
GEN_COMP_NAME_STEM_JAVA:=$(foreach file, $(GEN_COMP_NAME_STEM), \
										$(file).java)

# Combine the compilable files and the non-compilable files of each language
# to get a list of files with out grammar name prefixes that would be expected
# to be generated in an output directory.
GEN_FILE_SUFFIXES_CPP:=$(GEN_COMP_NAME_STEM_CPP) $(GEN_NONCOMP_NAME_STEM)
GEN_FILE_SUFFIXES_JAVA:=$(GEN_COMP_NAME_STEM_JAVA) $(GEN_NONCOMP_NAME_STEM)

# -----------
# | This section builds the actual file destinations for the generated files
# | using the above generic suffixes.
# -----------
# We'll generate these files in a gen dir. Gen is for the cpp files and the tool
# while gui is for the java files used in grun.
GEN_DIR:=${CURDIR}/gen/
GUI_GEN_DIR:=${CURDIR}/gui/

# Find all grammars in the base directory.
GRAMMARS:=$(wildcard *.g4)

# Construct the actual file desitination for the generated files for each
# grammar by prepending the destination directory and the grammar name.
GEN_RESULTS_CPP:= \
	$(foreach grammar, $(GRAMMARS:%.g4=%), \
		$(foreach base, $(GEN_FILE_SUFFIXES_CPP), $(GEN_DIR)$(grammar)$(base)))
GEN_RESULTS_JAVA:= \
	$(foreach grammar, $(GRAMMARS:%.g4=%), \
		$(foreach base, $(GEN_FILE_SUFFIXES_JAVA), $(GUI_GEN_DIR)$(grammar)$(base)))

# Filter the final file lists to get a list of just the compilable files.
GEN_RESULTS_COMP_CPP:= $(filter %.cpp %.h, $(GEN_RESULTS_CPP))
GEN_RESULTS_COMP_JAVA:= $(filter %.java, $(GEN_RESULTS_JAVA))

# -----------
# | This section finds the buildable files for your personal tool.
# -----------
# Get all of our source files.
SRC_CPP:=$(addprefix ${CURDIR}/, $(wildcard *.cpp *.h *.hpp))

# -----------
# | This section defines some overarching make information.
# -----------
# These targets produce nothing.
.PHONY: all clean gui

# Notify that these are not files to destroy. They are treated as
# "intermediates" otherise.
.PRECIOUS: $(GEN_RESULTS_CPP) $(GEN_RESULTS_JAVA)

# By default we want to make our tool.
all: tool

# -----------
# | This section defines the make rules for building the tool.
# -----------
# How to build our tool. Depend on (GEN_RESULTS_COMP_CPP).o first, then
# (SRC_CPP) because (SRC_CPP) likely depends on the parser. We depend on the .h
# files in (GEN_RESULTS_COMP_CPP) so we know when they're changed, but there's
# no rule to build them so it just ensures that they exist. We change the .cpp
# extensions to .o so that it's forced to build them if there were changes in
# the .cpp. The same logic applies to (SRC_CPP).
tool: $(GEN_RESULTS_COMP_CPP:.cpp=.o) $(SRC_CPP:.cpp=.o)
	c++ -std=gnu++11 -Wall \
		$(filter %.o, $^) $(ANTLRS) \
		-I"$(ANTLRI)" -I"$(GEN_DIR)" \
		-o rdg

# How to generate object files for cpp files in the current directory. These are
# personal source files. Depend on our specific source file and all of the
# generated headers/objects.
%.o: %.cpp $(GEN_RESULTS_COMP_CPP:.cpp=.o)
	c++ -std=gnu++11 -Wall -Wno-attributes -I"$(ANTLRI)" -I"$(GEN_DIR)" \
		-c "$<" -o "$@"

# How to generate object files for cpp files in the gen directory. These are
# generated source files.
$(GEN_DIR)%.o: $(GEN_DIR)%.cpp
	c++ -std=gnu++11 -Wall -Wno-attributes -I"$(ANTLRI)" -I"$(GEN_DIR)" \
		-c "$<" -o "$@"

# How to generate files from a grammar. The rule says it knows how to build any
# generated h or cpp file in the gen dir and depends on the grammar file. If
# there are changes to the grammar file, this rule will rebuild.
$(foreach result, $(GEN_FILE_SUFFIXES_CPP), $(GEN_DIR)%$(result)): %.g4
	java -Xmx500M org.antlr.v4.Tool \
		-Dlanguage=Cpp -listener -visitor \
		-o "$(GEN_DIR)" "$<"

# -----------
# | This section defines the make rules for running the gui and building its
# | required files.
# -----------
# How to run the grun gui. Depend on (GEN_RESULTS_COMP_JAVA).o so that we build
# for grun. We change the .java extensions to .class so that it's forced to
# build them if there were changes in the .java.
# First convert file into the real path to the file. This way we can take
# absolute paths to test files. We still require the grammar to be in the same
# directory as this makefile. Next, canonicalise the grammar name, because we
# need the name without extension for grun, but with for cp and rm.
# We can't do this if we don't know the grammar name and rule name, so we stop.
# If we don't know the input file name then we warn and use stdin instead.
gui: override file:=$(realpath $(file))
gui: override grammar:=$(grammar:%.g4=%)
gui: $(GEN_RESULTS_COMP_JAVA:.java=.class)
ifndef grammar
	@echo "Add 'grammar=grammarName' to your command."
else ifndef rule
	@echo "Add 'rule=startRule' to your command."
else
	cp $(grammar).g4 $(GUI_GEN_DIR)
ifndef file
	@echo "Add 'file=inputFile' to your command if you wanted to parse a file."
	@echo "Using stdin for input instead. Terminate with EOF (ctrl+d on" \
		"mac/linux, ctrl+z on windows)."
endif
	cd $(GUI_GEN_DIR) && \
		java org.antlr.v4.gui.TestRig $(grammar) $(rule) $(file) -gui
	rm -f $(GUI_GEN_DIR)$(grammar).g4
endif

# How to generate class files for the java files in the gui directory. These
# are generated source files. Note that this doesn't depend on just the java
# file but ALL java files. It's required to find all of the symbols
$(GUI_GEN_DIR)%.class: $(GEN_RESULTS_COMP_JAVA)
	@cd ${GUI_GEN_DIR}
	javac $^

# How to generate the java files for the gui.
$(foreach result, $(GEN_FILE_SUFFIXES_JAVA), $(GUI_GEN_DIR)%$(result)): %.g4
	java -Xmx500M org.antlr.v4.Tool -listener -visitor -o "$(GUI_GEN_DIR)" "$<"

# How to clean up
clean:
	rm -rf *.o "$(GEN_DIR)" "$(GUI_GEN_DIR)" tool
