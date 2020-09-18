grammar riscdot;

// Similar to functionCalls, this is only used in the second pass of the compiler
// to figure out how to create the dot graph. 
statements: (.*? statement)* .*? EOF;

// This is what is used to generate the dot graph. 
statement: LABEL':' #lblSt
    | functionCall #funcSt
    ;

// functionCalls is used in the first pass of the compiler to grab all the 
// function definitions. However, functionCall is used in the second pass of
// the compiler as well.
functionCalls: (.*? functionCall)* .*? EOF;
functionCall: 'jal' 'ra,' LABEL;

// Lexer rule for recognizing labels.
LABEL: [a-zA-Z] ([a-zA-Z0-9])*;

// Lexer rules for ignoring comments and strings as we should never parse 
// anything within strings or comments.
COMMENT: '#' ~[\r\n]* -> skip;
STRING: '"' .*? '"' -> skip;

// Typical lexer rule to ignore 
WS: [ \t\r\n] -> skip;

// The last lexer rule to just completely ignore everything else. Otherwise,
// program will throw a lot of errors.
REST: . -> skip;
