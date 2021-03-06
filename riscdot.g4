grammar riscdot;

// Similar to functionCalls, this is only used in the second pass of the compiler
// to figure out how to create the dot graph. 
statements: (.*? statement)* .*? EOF;

// This is what is used to generate the dot graph. 
statement: LABEL':' #lblSt
    | functionCall #funcSt
    | stackManip #spSt 
    ;

// This rule is used to be able to tell what sort of stack manipulation 
// operation was used to add the right annotations to the function nodes.
stackManip: 'lw' LABEL (',')? INT? '(' SP ')' #loadFromSP
    | 'sw' LABEL (',')? INT? '(' SP ')' #storeToSP
    | 'addi' SP (',')? SP (',')? INT #moveSP
    ;

// functionCalls is used in the first pass of the compiler to grab all the 
// function definitions. However, functionCall is used in the second pass of
// the compiler as well.
functionCalls: (.*? functionCall)* .*? EOF;
functionCall: 'jal' 'ra,' LABEL;


// Lexer rule to handle the stack pointer to generate the right annotations
// to the function nodes in the resulting dot graph.
// Ordering of the lexer rules is important.
SP: ('sp' | 'fp' );

// Lexer rule for recognizing labels.
LABEL: [a-zA-Z] ([a-zA-Z0-9])*;

INT: ('-')? ([0-9])+;

// Lexer rule to ignore comments. Comments are single line only.
COMMENT: '#' ~[\r\n]* -> skip;

// This set of lexer rules will handle strings with string escapes.
// Without this structure, a string like this <"\"jal ra, function\""> would go
// through and affect the program output, which is a bug. Similarly, we want
// to make sure to parse <"\\"> correctly, since the slashes are not used to
// escape the quote, but rather to escape the backslash. This solution was 
// proposed by Pierre Hebert, and adapted slightly. 
ESC_BACKSLASH: '\\\\';
ESC_DOUBLEQUOTE: '\\"';
DOUBLEQUOTE: '"';
STRING: DOUBLEQUOTE ( ESC_BACKSLASH | ESC_DOUBLEQUOTE | . )*? DOUBLEQUOTE -> skip;

// Typical lexer rule to ignore 
WS: [ \t\r\n] -> skip;

// The last lexer rule to just completely ignore everything else. Otherwise,
// program will throw a lot of errors.
REST: . -> skip;
