#include "riscdotLexer.h"
#include "riscdotParser.h"
#include "ANTLRFileStream.h"
#include "CommonTokenStream.h"
#include "tree/ParseTree.h"
#include "tree/ParseTreeWalker.h"
#include "riscdotBaseVisitor.h"
#include <iostream>
#include <cstdlib>
#include <unordered_map>
#include <string>

#include "support/Any.h"

class riscdotVis : public riscdotBaseVisitor {
    public:
        riscdotVis(char *outputFile);
        ~riscdotVis();
        antlrcpp::Any visitFunctionCall(riscdotParser::FunctionCallContext * ctx) override;
        antlrcpp::Any visitFunctionCalls(riscdotParser::FunctionCallsContext * ctx) override;
        antlrcpp::Any visitStatements(riscdotParser::StatementsContext * ctx) override;
        antlrcpp::Any visitLblSt(riscdotParser::LblStContext * ctx) override;
        antlrcpp::Any visitFuncSt(riscdotParser::FuncStContext * ctx) override;
        antlrcpp::Any visitSpSt(riscdotParser::SpStContext * ctx) override;
        antlrcpp::Any visitLoadFromSP(riscdotParser::LoadFromSPContext * ctx) override;
        antlrcpp::Any visitStoreToSP(riscdotParser::StoreToSPContext * ctx) override;
        antlrcpp::Any visitMoveSP(riscdotParser::MoveSPContext * ctx) override;
        std::string generateNodes();
    private:
        std::unordered_map<std::string, std::string> funcs;
        std::string currFunc; 
        std::ofstream outStream; 
        std::string outStr;
};

riscdotVis::riscdotVis(char *outputFile) {
    funcs = std::unordered_map<std::string, std::string>();
    funcs["main"] = "";
    currFunc = "DEFAULT_NO_ENCLOSING_FUNCTION";
    outStream = std::ofstream(outputFile);
    outStr = "";

    outStream << "digraph G {\n";
}

// NEVER DO THIS IN ACTUAL CODE.
// This can technically throw an error, and if a destructor throws an error
// during stack unwinding (processing another error), this will immediately 
// terminate the program. 
riscdotVis::~riscdotVis() {
    outStream << "}";
}

// Since all we care about in a function call is the label that it leads to, 
// return that.
antlrcpp::Any riscdotVis::visitFunctionCall(riscdotParser::FunctionCallContext * ctx) {
    return ctx->LABEL()->getText();
}

// During the first pass of the compiler, construct the set of function calls.
antlrcpp::Any riscdotVis::visitFunctionCalls(riscdotParser::FunctionCallsContext * ctx) {
    for( auto funcCall : ctx->functionCall() ) {
        std::string lbl = visit(funcCall);
        funcs[lbl] = "";
    }
    return antlrcpp::Any(); 
}

// During the second pass of the compiler, simply generate the dot graph.
antlrcpp::Any riscdotVis::visitStatements(riscdotParser::StatementsContext * ctx) {
    for( auto st : ctx->statement()) {
        visit(st);
    }
    // First output the function node definitions, and then add all the edges.
    outStream << generateNodes() << outStr; 
    return antlrcpp::Any();
}

// If the label that we are visiting is a function, then we want to set the name 
// of the function we are currently processing as the source for the graph.
antlrcpp::Any riscdotVis::visitLblSt(riscdotParser::LblStContext * ctx) {
    std::string lbl = ctx->LABEL()->getText();
    if (funcs.find(lbl) != funcs.end() || lbl == "main") {
        currFunc = lbl;
    }
    return antlrcpp::Any();
}

// Upon visiting a function call, add the generated edge to the graph, along with
// the line number as the edge label.
antlrcpp::Any riscdotVis::visitFuncSt(riscdotParser::FuncStContext * ctx) {
    std::string lbl = visit(ctx->functionCall());
    auto lineNum = ctx->start->getLine();
    outStr += "\t" + currFunc + " -> " + lbl + " [ label=\"" + std::to_string(lineNum) + "\" ];\n";
    return antlrcpp::Any();
}

// In order to add all the stack manipulation code to the annotation of each 
// function node, you first need to figure out what sort of stack manipulation
// operation it is.
antlrcpp::Any riscdotVis::visitSpSt(riscdotParser::SpStContext * ctx) {
    visit( ctx->stackManip() );
    return antlrcpp::Any();
}


// If the stack manipulation operation is a load from the stack, then we add 
// the lw annotation to the function.
antlrcpp::Any riscdotVis::visitLoadFromSP(riscdotParser::LoadFromSPContext * ctx) {
    funcs[currFunc] += "lw     " + ctx->LABEL()->getText() + ", " + ctx->INT()->getText() + "(sp)\\n";
    return antlrcpp::Any();
}

// If the stack manipulation operation is a store to the stack, then we add the
// sw annotation to the function.
antlrcpp::Any riscdotVis::visitStoreToSP(riscdotParser::StoreToSPContext * ctx) {
    funcs[currFunc] += "sw     " + ctx->LABEL()->getText() + ", " + ctx->INT()->getText() + "(sp)\\n";
    return antlrcpp::Any();
}

// If the stack manipulation operation is a movement of the stack pointer, then
// we add the addi annotation to the function.
antlrcpp::Any riscdotVis::visitMoveSP(riscdotParser::MoveSPContext * ctx) {
    funcs[currFunc] += "addi  sp, sp, " + ctx->INT()->getText() + "\\n";
    return antlrcpp::Any();
}

// Just before we emplace all the edges into the graph, we need to create all
// the function nodes and add the necessary annotations to the function node.
std::string riscdotVis::generateNodes() {
    std::string out = "";
    for( auto& it: funcs ) {
        out += "\t" + it.first + " [ shape=box,label=\"" + it.first + "\\n\\n" + it.second + "\"];\n";
    }
    return out;
}


int main( int argc, char **argv ) {
    if ( argc < 3 ) {
        std::cout << "Need an input file and an output file." << std::endl;
        return 1;
    }

    antlr4::ANTLRFileStream afs(argv[1]);
    riscdotLexer lexer(&afs);
    antlr4::CommonTokenStream tokens(&lexer);
    riscdotParser parser(&tokens);

    antlr4::tree::ParseTree *tree = parser.functionCalls();

    riscdotVis vis(argv[2]);

    vis.visit(tree);

    // I straight up do not know how to do this properly, so here is a 
    // pretty silly hack. 
    antlr4::ANTLRFileStream afs2(argv[1]);
    riscdotLexer lexer2(&afs2);
    antlr4::CommonTokenStream tokens2(&lexer2);
    riscdotParser parser2(&tokens2);

    tree = parser2.statements();

    vis.visit(tree);
}
