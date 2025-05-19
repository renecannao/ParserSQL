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
%lex-param { MysqlParser::Parser* parser_context }

%parse-param { yyscan_t yyscanner }
%parse-param { MysqlParser::Parser* parser_context }

%union {
    std::string* str_val;
    MysqlParser::AstNode* node_val;
}

%token TOKEN_SELECT TOKEN_FROM TOKEN_INSERT TOKEN_INTO TOKEN_VALUES
%token TOKEN_LPAREN TOKEN_RPAREN TOKEN_SEMICOLON TOKEN_ASTERISK
%token TOKEN_SET TOKEN_NAMES TOKEN_CHARACTER TOKEN_GLOBAL TOKEN_SESSION TOKEN_PERSIST TOKEN_PERSIST_ONLY
%token TOKEN_EQUAL TOKEN_DOT TOKEN_DEFAULT TOKEN_COLLATE TOKEN_COMMA
%token TOKEN_SPECIAL
%token TOKEN_DOUBLESPECIAL
%token TOKEN_GLOBAL_VAR_PREFIX
%token TOKEN_SESSION_VAR_PREFIX
%token TOKEN_PERSIST_VAR_PREFIX


%token <str_val> TOKEN_QUIT
%token <str_val> TOKEN_IDENTIFIER
%token <str_val> TOKEN_STRING_LITERAL
%token <str_val> TOKEN_NUMBER_LITERAL


%type <node_val> statement simple_statement command_statement select_statement insert_statement
%type <node_val> identifier_node string_literal_node value_for_insert select_list_item optional_semicolon
%type <node_val> set_statement set_option_list set_option
%type <node_val> variable_to_set
%type <node_val> user_variable
%type <node_val> system_variable_unqualified
%type <node_val> system_variable_qualified
%type <node_val> variable_scope
%type <node_val> expression_placeholder
%type <node_val> function_call_placeholder /* <<< NEW TYPE */
%type <node_val> expression_placeholder_list /* <<< NEW TYPE (for function args) */
%type <node_val> opt_expression_placeholder_list /* <<< NEW TYPE */
%type <node_val> set_names_stmt set_charset_stmt
%type <node_val> charset_name_or_default
%type <node_val> collation_name_choice


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
    | set_statement     { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    ;

simple_statement:
    command_statement   { $$ = $1; }
    ;

command_statement:
    TOKEN_QUIT optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COMMAND, std::move(*$1));
        delete $1;
    }
    ;

identifier_node:
    TOKEN_IDENTIFIER {
        std::string val = std::move(*$1);
        delete $1;
        if (val.length() >= 2 && val.front() == '`' && val.back() == '`') {
            val = val.substr(1, val.length() - 2);
             size_t pos = 0;
             while ((pos = val.find("``", pos)) != std::string::npos) {
                 val.replace(pos, 2, "`");
                 pos += 1;
             }
        }
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, std::move(val));
    }
    ;

string_literal_node:
    TOKEN_STRING_LITERAL {
        std::string raw_val = std::move(*$1);
        delete $1;
        std::string val_content; // String content without outer quotes
        char quote_char = 0;

        if (!raw_val.empty()) quote_char = raw_val.front();

        if (raw_val.length() >= 2 && (raw_val.front() == '\'' || raw_val.front() == '"') && raw_val.front() == raw_val.back()) {
            val_content = raw_val.substr(1, raw_val.length() - 2);
        } else {
            // This case implies the lexer didn't provide the quotes, or it's an error.
            // For robustness, assume raw_val is the content if quotes are missing.
            val_content = raw_val;
        }

        std::string unescaped_val;
        unescaped_val.reserve(val_content.length());
        bool escaping = false;
        for (size_t i = 0; i < val_content.length(); ++i) {
            if (escaping) {
                // Add more MySQL specific escapes as needed
                switch (val_content[i]) {
                    case 'n': unescaped_val += '\n'; break;
                    case 't': unescaped_val += '\t'; break;
                    case 'r': unescaped_val += '\r'; break;
                    case 'b': unescaped_val += '\b'; break;
                    case '0': unescaped_val += '\0'; break;
                    case 'Z': unescaped_val += '\x1A'; break;
                    case '\\': unescaped_val += '\\'; break;
                    case '\'': unescaped_val += '\''; break;
                    case '"': unescaped_val += '"'; break;
                    // % and _ are special in LIKE context, not general string escapes here.
                    default: unescaped_val += val_content[i]; break;
                }
                escaping = false;
            } else if (val_content[i] == '\\') {
                // Check for MySQL specific two-char escapes like '' or "" if not handled by quote_char logic
                // For now, standard backslash escape
                escaping = true;
            } else if (quote_char != 0 && val_content[i] == quote_char && (i + 1 < val_content.length() && val_content[i+1] == quote_char) ) {
                // Handles '' within 'string' or "" within "string" as a single quote/double quote
                unescaped_val += quote_char;
                i++; // Skip the second quote of the pair
            }
            else {
                unescaped_val += val_content[i];
            }
        }
         if(escaping) unescaped_val+='\\'; // Keep trailing backslash if it was the last char and an escape

        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(unescaped_val));
    }
    ;

select_list_item:
    identifier_node { $$ = $1; }
    | TOKEN_ASTERISK {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ASTERISK, "*");
    }
    ;

select_statement:
    TOKEN_SELECT select_list_item TOKEN_FROM identifier_node optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_STATEMENT);
        $$->addChild($2);
        $$->addChild($4);
    }
    ;

value_for_insert:
    string_literal_node { $$ = $1; }
    | TOKEN_NUMBER_LITERAL {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(*$1));
        delete $1;
    }
    ;

insert_statement:
    TOKEN_INSERT TOKEN_INTO identifier_node TOKEN_VALUES TOKEN_LPAREN value_for_insert TOKEN_RPAREN optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INSERT_STATEMENT);
        $$->addChild($3);
        $$->addChild($6);
    }
    ;

/* --- SET Statement Rules --- */

/* Rudimentary function call structure for expression_placeholder */
/* This does NOT parse arguments deeply, just recognizes the form func(...) */
opt_expression_placeholder_list:
    /* empty */ { $$ = nullptr; } // No arguments
    | expression_placeholder_list { $$ = $1; }
    ;

expression_placeholder_list:
    expression_placeholder { // A single argument
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "arg_list_wrapper"); // Wrapper for list
        $$->addChild($1);
    }
    | expression_placeholder_list TOKEN_COMMA expression_placeholder { // Multiple arguments
        $1->addChild($3); // Add to existing list wrapper
        $$ = $1;
    }
    ;

function_call_placeholder:
    identifier_node TOKEN_LPAREN opt_expression_placeholder_list TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, $1->value); // Use function name as value
        delete $1;
        if ($3 != nullptr) { // $3 is the opt_expression_placeholder_list node (wrapper)
            // Add children of the wrapper to the function call node
            for (MysqlParser::AstNode* child : $3->children) {
                $$->addChild(child);
            }
            $3->children.clear(); // Avoid double deletion as we moved them
            delete $3;
        }
    }
    ;

expression_placeholder:
    string_literal_node     { $$ = $1; }
    | TOKEN_NUMBER_LITERAL  { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(*$1)); delete $1;}
    | function_call_placeholder { $$ = $1; } /* <<< ADDED FUNCTION CALL */
    | identifier_node       { $$ = $1; }
    | TOKEN_DEFAULT         { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, "DEFAULT"); }
    | system_variable_qualified { $$ = $1; }
    | user_variable             { $$ = $1; }
    ;

variable_scope:
    TOKEN_GLOBAL        { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "GLOBAL"); }
    | TOKEN_SESSION       { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "SESSION"); }
    | TOKEN_PERSIST       { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "PERSIST"); }
    | TOKEN_PERSIST_ONLY  { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "PERSIST_ONLY"); }
    ;

user_variable:
    TOKEN_SPECIAL TOKEN_IDENTIFIER {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_USER_VARIABLE, std::move(*$2));
        delete $2;
    }
    ;

system_variable_unqualified:
    identifier_node {
        $$ = $1;
    }
    ;

system_variable_qualified:
    TOKEN_DOUBLESPECIAL identifier_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        delete $2;
    }
    | TOKEN_GLOBAL_VAR_PREFIX identifier_node {
        MysqlParser::AstNode* scope_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "GLOBAL");
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild(scope_node);
        delete $2;
    }
    | TOKEN_SESSION_VAR_PREFIX identifier_node {
        MysqlParser::AstNode* scope_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "SESSION");
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild(scope_node);
        delete $2;
    }
    ;

variable_to_set:
    user_variable { $$ = $1; }
    | system_variable_qualified { $$ = $1; }
    | variable_scope system_variable_unqualified {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild($1);
        delete $2;
    }
    | system_variable_unqualified {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $1->value);
        delete $1;
    }
    ;

set_option:
    variable_to_set TOKEN_EQUAL expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild($3);
    }
    ;

set_option_list:
    set_option {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SET_STATEMENT);
        $$->addChild($1);
    }
    | set_option_list TOKEN_COMMA set_option {
        $1->addChild($3);
        $$ = $1;
    }
    ;

charset_name_or_default:
    string_literal_node { $$ = $1; }
    | TOKEN_DEFAULT     { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, "DEFAULT"); }
    | identifier_node   { $$ = $1; }
    ;

collation_name_choice:
    string_literal_node { $$ = $1; }
    | identifier_node   { $$ = $1; }
    ;

set_names_stmt:
    TOKEN_NAMES charset_name_or_default {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SET_NAMES);
        $$->addChild($2);
    }
    | TOKEN_NAMES charset_name_or_default TOKEN_COLLATE collation_name_choice {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SET_NAMES);
        $$->addChild($2);
        $$->addChild($4);
    }
    ;

set_charset_stmt:
    TOKEN_CHARACTER TOKEN_SET charset_name_or_default {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SET_CHARSET);
        $$->addChild($3);
    }
    ;

set_statement:
    TOKEN_SET set_names_stmt optional_semicolon { $$ = $2; }
    | TOKEN_SET set_charset_stmt optional_semicolon { $$ = $2; }
    | TOKEN_SET set_option_list optional_semicolon { $$ = $2; }
    ;

%%

