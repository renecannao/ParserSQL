%code requires {
    namespace MysqlParser { // Changed namespace
      struct AstNode;
    }
    #include <string> 
}

%{ // C PROLOGUE
#include "mysql_parser/mysql_parser.h" // Changed include path and namespace

// Forward declaration of the lexer function.
// Using explicit union name based on previous PGSQL_YYSTYPE findings.
union MYSQL_YYSTYPE; // Forward declaration
int mysql_yylex(union MYSQL_YYSTYPE* yylval_param, yyscan_t yyscanner, MysqlParser::Parser* parser_context);

%} // END C PROLOGUE

%define api.prefix {mysql_yy} // Changed prefix
%define api.pure full 
%define parse.error verbose 

%code top {}

%lex-param { yyscan_t yyscanner }
%lex-param { MysqlParser::Parser* parser_context } // Changed namespace

%parse-param { yyscan_t yyscanner }
%parse-param { MysqlParser::Parser* parser_context } // Changed namespace

%union {
    std::string* str_val;
    MysqlParser::AstNode* node_val; // Changed namespace
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
%type <node_val> optional_semicolon


%start query_list

%%

query_list:
    /* empty */ { if (parser_context) parser_context->internal_set_ast(nullptr); }
    | query_list statement { /* Manages last statement's AST. */ }
    ;

optional_semicolon:
    TOKEN_SEMICOLON { $$ = nullptr; }
    | /* empty */   { $$ = nullptr; }
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
        // If $1 (TOKEN_QUIT) has no str_val because it's a simple token now
        // $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COMMAND, "QUIT");
        // If TOKEN_QUIT still carries value:
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COMMAND, std::move(*$1)); // Changed namespace
        delete $1;
    }
    ;

identifier_node:
    TOKEN_IDENTIFIER {
        // For backticked identifiers, yytext might include backticks. Strip them.
        std::string val = std::move(*$1);
        delete $1;
        if (val.length() >= 2 && val.front() == '`' && val.back() == '`') {
            val = val.substr(1, val.length() - 2);
            // Further unescape `` to ` if needed (lexer might do this already)
             size_t pos = 0;
             while ((pos = val.find("``", pos)) != std::string::npos) {
                 val.replace(pos, 2, "`");
                 pos += 1;
             }
        }
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, std::move(val)); // Changed namespace
    }
    ;

string_literal_node:
    TOKEN_STRING_LITERAL {
        std::string val = std::move(*$1); // Lexer should provide the full string including quotes
        delete $1;
        char quote_char = 0;
        if (!val.empty()) quote_char = val.front();

        if (val.length() >= 2 && (val.front() == '\'' || val.front() == '"') && val.front() == val.back()) {
            val = val.substr(1, val.length() - 2);
        }
        // Basic unescaping, can be more complex for MySQL
        // For example, \' or \" or \\ or '' or ""
        std::string unescaped_val;
        unescaped_val.reserve(val.length());
        bool escaping = false;
        for (size_t i = 0; i < val.length(); ++i) {
            if (escaping) {
                switch (val[i]) {
                    case 'n': unescaped_val += '\n'; break;
                    case 't': unescaped_val += '\t'; break;
                    case 'r': unescaped_val += '\r'; break;
                    case 'b': unescaped_val += '\b'; break;
                    case '\\': unescaped_val += '\\'; break;
                    case '\'': unescaped_val += '\''; break;
                    case '"': unescaped_val += '"'; break;
                    // MySQL specific escapes like % _ can be handled if used in LIKE context
                    default: unescaped_val += val[i]; break; 
                }
                escaping = false;
            } else if (val[i] == '\\') { // MySQL general escape char
                escaping = true;
            } else if (quote_char != 0 && val[i] == quote_char && (i + 1 < val.length() && val[i+1] == quote_char) ) { // '' or ""
                unescaped_val += quote_char;
                i++; // Skip next quote
            }
            else {
                unescaped_val += val[i];
            }
        }
         if(escaping) unescaped_val+='\\'; // trailing backslash


        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(unescaped_val)); // Changed namespace
    }
    ;

select_list_item:
    identifier_node { $$ = $1; } 
    | TOKEN_ASTERISK { 
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ASTERISK, "*"); // Changed namespace
    }
    ;

select_statement:
    TOKEN_SELECT select_list_item TOKEN_FROM identifier_node optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_STATEMENT);  // Changed namespace
        $$->addChild($2); 
        $$->addChild($4); 
    }
    ;

value_for_insert:
    string_literal_node { $$ = $1; }
    ;

insert_statement:
    TOKEN_INSERT TOKEN_INTO identifier_node TOKEN_VALUES TOKEN_LPAREN value_for_insert TOKEN_RPAREN optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INSERT_STATEMENT); // Changed namespace
        $$->addChild($3); 
        $$->addChild($6); 
    }
    ;

%%
