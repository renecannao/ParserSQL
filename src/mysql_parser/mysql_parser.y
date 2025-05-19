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

%code top {
    // Includes here are very early in the generated .c file if needed.
}

// Parameters for mysql_yylex (how Bison will *call* it)
%lex-param { yyscan_t yyscanner }
%lex-param { MysqlParser::Parser* parser_context }

// Parameters for mysql_yyparse itself and for mysql_yyerror
%parse-param { yyscan_t yyscanner }
%parse-param { MysqlParser::Parser* parser_context }


%union { // This defines the members of YYSTYPE (which will be MYSQL_YYSTYPE or mysql_yySTYPE)
    std::string* str_val;
    MysqlParser::AstNode* node_val;
}

/* Declare tokens from the lexer */
%token TOKEN_SELECT TOKEN_FROM TOKEN_INSERT TOKEN_INTO TOKEN_VALUES
%token TOKEN_LPAREN TOKEN_RPAREN TOKEN_SEMICOLON TOKEN_ASTERISK
%token TOKEN_SET TOKEN_NAMES TOKEN_CHARACTER TOKEN_GLOBAL TOKEN_SESSION TOKEN_PERSIST TOKEN_PERSIST_ONLY
%token TOKEN_DOT TOKEN_DEFAULT TOKEN_COLLATE TOKEN_COMMA
%token TOKEN_SPECIAL /* for @ */
%token TOKEN_DOUBLESPECIAL /* for @@ */
%token TOKEN_GLOBAL_VAR_PREFIX
%token TOKEN_SESSION_VAR_PREFIX
%token TOKEN_PERSIST_VAR_PREFIX

%token TOKEN_DELETE
%token TOKEN_LOW_PRIORITY
%token TOKEN_QUICK
%token TOKEN_IGNORE_SYM
%token TOKEN_USING
%token TOKEN_ORDER
%token TOKEN_BY
%token TOKEN_LIMIT
%token TOKEN_ASC
%token TOKEN_DESC
%token TOKEN_WHERE
%token TOKEN_AS

/* Comparison Operator Tokens */
%token TOKEN_EQUAL
%token TOKEN_LESS
%token TOKEN_GREATER
%token TOKEN_LESS_EQUAL
%token TOKEN_GREATER_EQUAL
%token TOKEN_NOT_EQUAL


%token <str_val> TOKEN_QUIT
%token <str_val> TOKEN_IDENTIFIER
%token <str_val> TOKEN_STRING_LITERAL
%token <str_val> TOKEN_NUMBER_LITERAL


%type <node_val> statement simple_statement command_statement select_statement insert_statement delete_statement
%type <node_val> identifier_node string_literal_node value_for_insert select_list_item optional_semicolon
%type <node_val> set_statement set_option_list set_option
%type <node_val> variable_to_set user_variable system_variable_unqualified system_variable_qualified
%type <node_val> variable_scope expression_placeholder function_call_placeholder
%type <node_val> expression_placeholder_list opt_expression_placeholder_list
%type <node_val> set_names_stmt set_charset_stmt charset_name_or_default collation_name_choice

%type <node_val> opt_delete_options delete_option delete_option_item_list
%type <node_val> opt_where_clause
%type <node_val> opt_order_by_clause opt_limit_clause
%type <node_val> order_by_list order_by_item opt_asc_desc
%type <node_val> table_name_list_for_delete
%type <node_val> table_reference_item
%type <node_val> table_reference_list
%type <node_val> comparison_operator
%type <node_val> qualified_identifier_node


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
    | delete_statement  { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
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

qualified_identifier_node:
    identifier_node TOKEN_DOT identifier_node {
        std::string qualified_name = $1->value + "." + $3->value;
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_QUALIFIED_IDENTIFIER, std::move(qualified_name));
        // Children could be added for more structure:
        // $$->addChild($1); // Table/alias part
        // $$->addChild($3); // Column part
        // If adding as children, ensure $1 and $3 are not deleted if they are to be owned by $$
        delete $1;
        delete $3;
    }
    ;

string_literal_node:
    TOKEN_STRING_LITERAL {
        std::string raw_val = std::move(*$1);
        delete $1;
        std::string val_content;
        char quote_char = 0;
        if (!raw_val.empty()) quote_char = raw_val.front();

        if (raw_val.length() >= 2 && (raw_val.front() == '\'' || raw_val.front() == '"') && raw_val.front() == raw_val.back()) {
            val_content = raw_val.substr(1, raw_val.length() - 2);
        } else {
            val_content = raw_val;
        }

        std::string unescaped_val;
        unescaped_val.reserve(val_content.length());
        bool escaping = false;
        for (size_t i = 0; i < val_content.length(); ++i) {
            if (escaping) {
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
                    default: unescaped_val += val_content[i]; break;
                }
                escaping = false;
            } else if (val_content[i] == '\\') {
                escaping = true;
            } else if (quote_char != 0 && val_content[i] == quote_char && (i + 1 < val_content.length() && val_content[i+1] == quote_char) ) {
                unescaped_val += quote_char;
                i++;
            }
            else {
                unescaped_val += val_content[i];
            }
        }
         if(escaping) unescaped_val+='\\';

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
opt_expression_placeholder_list:
    /* empty */ { $$ = nullptr; }
    | expression_placeholder_list { $$ = $1; }
    ;
expression_placeholder_list:
    expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "arg_list_wrapper");
        $$->addChild($1);
    }
    | expression_placeholder_list TOKEN_COMMA expression_placeholder {
        $1->addChild($3);
        $$ = $1;
    }
    ;
function_call_placeholder:
    identifier_node TOKEN_LPAREN opt_expression_placeholder_list TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, $1->value);
        delete $1;
        if ($3 != nullptr) {
            for (MysqlParser::AstNode* child : $3->children) {
                $$->addChild(child);
            }
            $3->children.clear();
            delete $3;
        }
    }
    ;

/* --- Expression Placeholder and Comparison --- */
comparison_operator:
    TOKEN_EQUAL         { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "="); }
    | TOKEN_LESS          { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "<"); }
    | TOKEN_GREATER       { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, ">"); }
    | TOKEN_LESS_EQUAL    { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "<="); }
    | TOKEN_GREATER_EQUAL { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, ">="); }
    | TOKEN_NOT_EQUAL     { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "!="); }
    ;

expression_placeholder:
    string_literal_node     { $$ = $1; }
    | TOKEN_NUMBER_LITERAL  { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(*$1)); delete $1;}
    | function_call_placeholder { $$ = $1; }
    | qualified_identifier_node { $$ = $1; }
    | identifier_node       { $$ = $1; }
    | TOKEN_DEFAULT         { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, "DEFAULT"); }
    | system_variable_qualified { $$ = $1; }
    | user_variable             { $$ = $1; }
    | expression_placeholder comparison_operator expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COMPARISON_EXPRESSION, $2->value);
        delete $2;
        $$->addChild($1);
        $$->addChild($3);
    }
    ;
/* --- End Expression Placeholder --- */

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
    identifier_node { $$ = $1; }
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

/* --- DELETE Statement Rules --- */
delete_option:
    TOKEN_LOW_PRIORITY { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, "LOW_PRIORITY"); }
    | TOKEN_QUICK      { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, "QUICK"); }
    | TOKEN_IGNORE_SYM { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, "IGNORE"); }
    ;

delete_option_item_list:
    delete_option {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS);
        $$->addChild($1);
    }
    | delete_option_item_list delete_option {
        $1->addChild($2);
        $$ = $1;
    }
    ;

opt_delete_options:
    /* empty */ { $$ = nullptr; }
    | delete_option_item_list { $$ = $1; }
    ;

opt_where_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_WHERE expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE);
        $$->addChild($2);
    }
    ;

opt_asc_desc:
    /* empty */       { $$ = nullptr; }
    | TOKEN_ASC       { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, "ASC"); }
    | TOKEN_DESC      { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, "DESC"); }
    ;

order_by_item:
    identifier_node opt_asc_desc { // Could also be qualified_identifier_node for ORDER BY table.column
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_ITEM, $1->value);
        delete $1;
        if ($2 != nullptr) {
            $$->addChild($2);
        }
    }
    ;

order_by_list:
    order_by_item {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_CLAUSE);
        $$->addChild($1);
    }
    | order_by_list TOKEN_COMMA order_by_item {
        $1->addChild($3);
        $$ = $1;
    }
    ;

opt_order_by_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_ORDER TOKEN_BY order_by_list { $$ = $3; }
    ;

opt_limit_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_LIMIT TOKEN_NUMBER_LITERAL {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE);
        MysqlParser::AstNode* limit_val = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(*$2));
        delete $2;
        $$->addChild(limit_val);
    }
    | TOKEN_LIMIT TOKEN_NUMBER_LITERAL TOKEN_COMMA TOKEN_NUMBER_LITERAL {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE);
        MysqlParser::AstNode* offset_val = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(*$2));
        MysqlParser::AstNode* count_val = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(*$4));
        delete $2; delete $4;
        $$->addChild(offset_val);
        $$->addChild(count_val);
    }
    ;

table_name_list_for_delete:
    identifier_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_TABLE_NAME_LIST);
        $$->addChild($1);
    }
    | table_name_list_for_delete TOKEN_COMMA identifier_node {
        $1->addChild($3);
        $$ = $1;
    }
    ;

table_reference_item:
    identifier_node { $$ = $1; }
    | identifier_node TOKEN_AS identifier_node {
        // $1 is table name, $3 is alias. Store alias as value of $1 for now, or make $1 a specific ALIAS_NODE
        // For simplicity, let's make the table_reference_item value be the alias if present, original name otherwise.
        // And add original name as child if alias is present.
        // A better AST would have distinct nodes for table and alias.
        MysqlParser::AstNode* alias_node = $3;
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, alias_node->value); // Alias becomes the value
        $$->addChild($1); // Original table name as child
        delete alias_node;
    }
    | identifier_node identifier_node { // Implicit AS
        MysqlParser::AstNode* alias_node = $2;
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, alias_node->value);
        $$->addChild($1);
        delete alias_node;
    }
    ;

table_reference_list:
    table_reference_item {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "table_ref_list_wrapper");
        $$->addChild($1);
    }
    | table_reference_list TOKEN_COMMA table_reference_item {
        $1->addChild($3);
        $$ = $1;
    }
    ;

delete_statement:
    TOKEN_DELETE opt_delete_options TOKEN_FROM identifier_node
                 opt_where_clause opt_order_by_clause opt_limit_clause optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_STATEMENT);
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($4);
        if ($5) $$->addChild($5); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
        if ($6) $$->addChild($6); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_CLAUSE));
        if ($7) $$->addChild($7); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE));
    }
    | TOKEN_DELETE opt_delete_options table_name_list_for_delete TOKEN_FROM table_reference_list
                 opt_where_clause optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_STATEMENT, "MULTI_TABLE_TARGET_LIST_FROM");
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($3);
        MysqlParser::AstNode* from_wrapper = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FROM_CLAUSE);
        from_wrapper->addChild($5);
        $$->addChild(from_wrapper);
        if ($6) $$->addChild($6); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
    }
    | TOKEN_DELETE opt_delete_options TOKEN_FROM table_name_list_for_delete TOKEN_USING table_reference_list
                 opt_where_clause optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_STATEMENT, "MULTI_TABLE_FROM_USING");
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS));
        // For "DELETE FROM t1, t2 USING ...", t1, t2 are the tables to delete rows FROM,
        // but they are also part of the tables being referenced in the USING clause.
        // The $4 (table_name_list_for_delete) here refers to the tables listed after FROM.
        $$->addChild($4);
        MysqlParser::AstNode* using_wrapper = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_USING_CLAUSE);
        using_wrapper->addChild($6);
        $$->addChild(using_wrapper);
        if ($7) $$->addChild($7); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
    }
    ;

%%

