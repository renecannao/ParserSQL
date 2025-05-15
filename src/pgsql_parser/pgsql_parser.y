/* src/pgsql_parser/pgsql_parser.y */
%code requires {
    namespace PgsqlParser {
      struct AstNode;
    }
    #include <string> 
}


%{ // C PROLOGUE - This code is now part of a C++ compilation unit
#include "pgsql_parser/pgsql_parser.h" // For PgsqlParser::Parser context & yyscan_t

// Forward declaration of the lexer function.
// Since both Bison and Flex output will be compiled as C++,
// extern "C" is not strictly needed here FOR LINKAGE BETWEEN THEM.
// The signature must match YY_DECL in pgsql_lexer.l.
// The type `union PGSQL_YYSTYPE` should be known from pgsql_parser.tab.h or forward declared if needed.
// Bison itself defines this union before using it in its generated code.
union PGSQL_YYSTYPE; // Forward declaration, useful if this prologue is processed before Bison's own definition
int pgsql_yylex(union PGSQL_YYSTYPE* yylval_param, yyscan_t yyscanner, PgsqlParser::Parser* parser_context);

%} // END C PROLOGUE

%define api.prefix {pgsql_yy}
%define api.pure full 
%define parse.error verbose 

%code top {}

%lex-param { yyscan_t yyscanner }
%lex-param { PgsqlParser::Parser* parser_context }

%parse-param { yyscan_t yyscanner }
%parse-param { PgsqlParser::Parser* parser_context }

%union {
    std::string* str_val;
    PgsqlParser::AstNode* node_val;
}

%token TOKEN_SELECT TOKEN_FROM TOKEN_INSERT TOKEN_INTO TOKEN_VALUES
%token TOKEN_LPAREN TOKEN_RPAREN TOKEN_SEMICOLON
%token TOKEN_ASTERISK

%token <str_val> TOKEN_QUIT
%token <str_val> TOKEN_IDENTIFIER
%token <str_val> TOKEN_STRING_LITERAL

%type <node_val> statement
%type <node_val> simple_statement
%type <node_val> command_statement
%type <node_val> select_statement
%type <node_val> insert_statement
%type <node_val> identifier_node
%type <node_val> string_literal_node
%type <node_val> value_for_insert
%type <node_val> select_list_item
%type <node_val> optional_semicolon /* <<< NEW TYPE (though it produces no value for AST) */


%start query_list

%%

query_list:
    /* empty */ { if (parser_context) parser_context->internal_set_ast(nullptr); }
    | query_list statement { /* Manages last statement's AST. */ }
    ;

/* NEW RULE for optional semicolon */
optional_semicolon:
    TOKEN_SEMICOLON { $$ = nullptr; /* Or some placeholder if needed, but usually not for this */ }
    | /* empty */   { $$ = nullptr; } /* Allows nothing, produces no AST node for itself */
    ;

statement:
    simple_statement    { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | select_statement  { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | insert_statement  { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    ;

simple_statement:
    command_statement   { $$ = $1; }
    ;

command_statement:
    TOKEN_QUIT optional_semicolon {
        $$ = new PgsqlParser::AstNode(PgsqlParser::NodeType::NODE_COMMAND, std::move(*$1));
        delete $1;
        // $2 (optional_semicolon) doesn't contribute a meaningful value here
    }
    ;

identifier_node:
    TOKEN_IDENTIFIER {
        $$ = new PgsqlParser::AstNode(PgsqlParser::NodeType::NODE_IDENTIFIER, std::move(*$1));
        delete $1;
    }
    ;

string_literal_node:
    TOKEN_STRING_LITERAL {
        std::string val = std::move(*$1);
        delete $1;
        if (val.length() >= 2 && val.front() == '\'' && val.back() == '\'') {
            val = val.substr(1, val.length() - 2);
        }
        $$ = new PgsqlParser::AstNode(PgsqlParser::NodeType::NODE_STRING_LITERAL, std::move(val));
    }
    ;

select_list_item:
    identifier_node { $$ = $1; } 
    | TOKEN_ASTERISK { 
        $$ = new PgsqlParser::AstNode(PgsqlParser::NodeType::NODE_ASTERISK, "*"); 
    }
    ;

select_statement:
    TOKEN_SELECT select_list_item TOKEN_FROM identifier_node optional_semicolon { /* MODIFIED */
        $$ = new PgsqlParser::AstNode(PgsqlParser::NodeType::NODE_SELECT_STATEMENT); 
        $$->addChild($2); 
        $$->addChild($4); 
        // $5 (optional_semicolon) doesn't contribute
    }
    ;

value_for_insert:
    string_literal_node { $$ = $1; }
    ;

insert_statement:
    TOKEN_INSERT TOKEN_INTO identifier_node TOKEN_VALUES TOKEN_LPAREN value_for_insert TOKEN_RPAREN optional_semicolon {
        $$ = new PgsqlParser::AstNode(PgsqlParser::NodeType::NODE_INSERT_STATEMENT); 
        $$->addChild($3); 
        $$->addChild($6); 
        // $8 (optional_semicolon) doesn't contribute
    }
    ;

%%

// pgsql_yyerror is defined in pgsql_parser.cpp with C linkage,
// and declared in pgsql_parser.h. Bison will generate a call to it.

