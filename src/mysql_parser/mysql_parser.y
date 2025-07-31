%code requires {
    namespace MySQLParser {
      struct AstNode;
    }
    #include <string>
}

%{
#include "mysql_parser/mysql_parser.h"
#include "mysql_parser/mysql_ast.h"

union MYSQL_YYSTYPE;
struct MYSQL_YYLTYPE;

int mysql_yylex (union MYSQL_YYSTYPE *yylval_param, MYSQL_YYLTYPE* yyloc, yyscan_t yyscanner, MySQLParser::Parser* parser_context);
%}

%define api.pure full
%define api.prefix {mysql_yy}
%define parse.error verbose

%lex-param { yyscan_t yyscanner }
%lex-param { MySQLParser::Parser* parser_context }

%parse-param { yyscan_t yyscanner }
%parse-param { MySQLParser::Parser* parser_context }

%union {
    std::string* str_val;
    MySQLParser::AstNode* node_val;
}

// Tokens
%token TOKEN_SELECT TOKEN_FROM TOKEN_INSERT TOKEN_INTO TOKEN_VALUES
%token TOKEN_LPAREN TOKEN_RPAREN TOKEN_SEMICOLON TOKEN_ASTERISK
%token TOKEN_PLUS TOKEN_MINUS TOKEN_DIVIDE TOKEN_DIV
%token TOKEN_SET TOKEN_NAMES TOKEN_CHARACTER TOKEN_GLOBAL TOKEN_SESSION TOKEN_PERSIST TOKEN_PERSIST_ONLY
%token TOKEN_DOT TOKEN_DEFAULT TOKEN_COLLATE TOKEN_COMMA
%token TOKEN_SPECIAL TOKEN_DOUBLESPECIAL
%token TOKEN_GLOBAL_VAR_PREFIX TOKEN_SESSION_VAR_PREFIX TOKEN_PERSIST_VAR_PREFIX

%token TOKEN_DELETE TOKEN_LOW_PRIORITY TOKEN_QUICK TOKEN_IGNORE_SYM
%token TOKEN_USING TOKEN_ORDER TOKEN_BY TOKEN_LIMIT TOKEN_ASC TOKEN_DESC TOKEN_WHERE
%token TOKEN_AS TOKEN_DISTINCT TOKEN_GROUP TOKEN_ALL TOKEN_ANY TOKEN_HAVING TOKEN_AND

%token TOKEN_JOIN TOKEN_INNER TOKEN_LEFT TOKEN_RIGHT TOKEN_FULL TOKEN_OUTER TOKEN_CROSS TOKEN_ON
%token TOKEN_NATURAL TOKEN_LANGUAGE TOKEN_WITH TOKEN_QUERY TOKEN_EXPANSION

%token TOKEN_EQUAL TOKEN_LESS TOKEN_GREATER TOKEN_LESS_EQUAL TOKEN_GREATER_EQUAL TOKEN_NOT_EQUAL

%token TOKEN_OUTFILE TOKEN_DUMPFILE TOKEN_FOR TOKEN_UPDATE TOKEN_SHARE TOKEN_OF
%token TOKEN_NOWAIT TOKEN_SKIP TOKEN_LOCKED
%token TOKEN_FIELDS TOKEN_TERMINATED TOKEN_OPTIONALLY TOKEN_ENCLOSED TOKEN_ESCAPED
%token TOKEN_LINES TOKEN_STARTING

%token TOKEN_COUNT TOKEN_SUM TOKEN_AVG TOKEN_MAX TOKEN_MIN

%token TOKEN_TRANSACTION TOKEN_ISOLATION TOKEN_LEVEL
%token TOKEN_READ TOKEN_WRITE TOKEN_ONLY // For transactions access mode
%token TOKEN_COMMITTED TOKEN_UNCOMMITTED TOKEN_SERIALIZABLE TOKEN_REPEATABLE // Isolation levels

%token TOKEN_MATCH TOKEN_AGAINST TOKEN_BOOLEAN TOKEN_MODE

%token TOKEN_IN // For IN BOOLEAN MODE, and potentially IN operator later
%token TOKEN_SHOW TOKEN_DATABASES /* Added for SHOW DATABASES */
/* TOKEN_FIELDS is already declared */
/* TOKEN_FULL is already declared */
%token TOKEN_BEGIN TOKEN_COMMIT /* Added for BEGIN/COMMIT */
%token TOKEN_IS TOKEN_NULL_KEYWORD TOKEN_NOT /* Added for IS NULL / IS NOT NULL */
%token TOKEN_OFFSET /* Added for LIMIT ... OFFSET ... */

// Add these to your existing %token declarations
// Make sure TOKEN_PERCENT is defined if you use '%' operator
%token TOKEN_PERCENT // For '%' modulo operator

%token TOKEN_XOR
%token TOKEN_TRUE TOKEN_FALSE TOKEN_UNKNOWN
%token TOKEN_BINARY TOKEN_ROW TOKEN_SYSTEM
%token TOKEN_BETWEEN
%token TOKEN_MEMBER

// TOKEN_OF is likely already defined for other contexts (e.g., LOCKING OF table)
// %token TOKEN_OF
%token TOKEN_SOUNDS // For SOUNDS (used in SOUNDS LIKE)
%token TOKEN_LIKE   // For LIKE operator keyword
%token TOKEN_ESCAPE
%token TOKEN_REGEXP // For REGEXP operator keyword (MySQL also uses RLIKE)
%token TOKEN_INTERVAL
%token TOKEN_DIV_KEYWORD // For DIV integer division keyword
%token TOKEN_MOD_KEYWORD // For MOD keyword
%token TOKEN_BITWISE_XOR // For ^ bitwise XOR operator
%token TOKEN_BITWISE_OR  // For | bitwise OR operator
%token TOKEN_BITWISE_AND // For & bitwise AND operator
%token TOKEN_BITWISE_LSHIFT // For << bitwise left shift operator
%token TOKEN_BITWISE_RSHIFT // For >> bitwise right shift operator

// Intervals
%token TOKEN_DAY_HOUR TOKEN_DAY_MICROSECOND TOKEN_DAY_MINUTE TOKEN_DAY_SECOND TOKEN_HOUR_MICROSECOND TOKEN_HOUR_MINUTE
%token TOKEN_HOUR_SECOND TOKEN_MINUTE_MICROSECOND TOKEN_MINUTE_SECOND TOKEN_SECOND_MICROSECOND TOKEN_YEAR_MONTH

// Timestamps
%token TOKEN_DAY TOKEN_WEEK TOKEN_HOUR TOKEN_MINUTE TOKEN_MONTH TOKEN_QUARTER TOKEN_SECOND TOKEN_MICROSECOND TOKEN_YEAR

// For qualified system variables like @@PERSIST.var
%token TOKEN_PERSIST_ONLY_VAR_PREFIX // For @@PERSIST_ONLY.

// Add these to your existing %type declarations
%type <node_val> expr boolean_primary_expr predicate bit_expr literal_or_null simple_bit_expr select_subexpr
%type <node_val> truth_value opt_not opt_escape all_or_any

// Dates
%type <node_val> interval timestamp

// Replace your existing expression-related precedence rules with these.
// This order defines precedence from lowest to highest.
// Ensure UMINUS is defined if you have unary minus.
// %right UMINUS // Already in your grammar for unary minus

%token <str_val> TOKEN_QUIT
%token <str_val> TOKEN_IDENTIFIER
%token <str_val> TOKEN_STRING_LITERAL
%token <str_val> TOKEN_NUMBER_LITERAL

// Types
%type <node_val> statement simple_statement command_statement select_statement insert_statement delete_statement
%type <node_val> identifier_node string_literal_node number_literal_node value_for_insert optional_semicolon show_statement begin_statement commit_statement
%type <node_val> set_statement set_option_value_list set_option_value set_transaction_statement transaction_characteristic_list transaction_characteristic isolation_level_spec
%type <node_val> variable_to_set user_variable system_variable_unqualified system_variable_qualified
%type <node_val> variable_scope
%type <node_val> aggregate_function_call function_call_placeholder opt_search_modifier opt_with_query_expansion
%type <node_val> opt_expr_list // expr_list is removed as it's replaced by expression_list for args
%type <node_val> set_names_stmt set_charset_stmt charset_name_or_default collation_name_choice
%type <node_val> subquery_parts_args subquery_part any_token opt_of

%type <node_val> opt_delete_options delete_option delete_option_item_list
%type <node_val> opt_where_clause opt_having_clause
%type <node_val> opt_order_by_clause opt_limit_clause
%type <node_val> order_by_list order_by_item opt_asc_desc table_specification
%type <node_val> table_name_list_for_delete
%type <node_val> comparison_operator
%type <node_val> qualified_identifier_node table_name_spec // Added table_name_spec

%type <node_val> opt_select_options select_option_item
%type <node_val> select_item_list select_item opt_alias
%type <node_val> opt_from_clause from_clause
%type <node_val> opt_group_by_clause group_by_list grouping_element

%type <node_val> table_reference table_reference_inner
%type <node_val> joined_table opt_join_type join_type_natural_spec opt_join_condition join_condition
%type <node_val> identifier_list_args identifier_list

%type <node_val> opt_into_clause into_clause user_var_list
%type <node_val> opt_into_outfile_options_list opt_into_outfile_options_list_tail into_outfile_options_list into_outfile_option
%type <node_val> fields_options_clause lines_options_clause field_option_outfile_list field_option_outfile line_option_outfile_list line_option_outfile
%type <node_val> opt_locking_clause_list locking_clause_list locking_clause lock_strength opt_lock_table_list opt_lock_option
%type <node_val> show_what show_full_modifier show_from_or_in

%type <node_val> subquery derived_table
%type <node_val> single_input_statement // Type for the start symbol

// For INSERT statement enhancements
%type <node_val> opt_column_list column_list_item_list column_list_item
%type <node_val> values_clause value_row_list value_row expression_list

// Precedence
%left TOKEN_SET
%left TOKEN_OR
%left TOKEN_XOR TOKEN_AND TOKEN_NOT
%left AND_SYM AND_AND_SYM
%left TOKEN_BETWEEN TOKEN_CASE WHEN_SYM THEN_SYM ELSE
%left '|'
%left '&'
%left TOKEN_BITWISE_LSHIFT TOKEN_BITWISE_RSHIFT
%left '-' '+'
%left '*' '/' '%' TOKEN_DIV TOKEN_MOD
%left '^'
%left TOKEN_NEG '~'

%left TOKEN_EQUAL TOKEN_LESS TOKEN_GREATER TOKEN_LESS_EQUAL TOKEN_GREATER_EQUAL TOKEN_NOT_EQUAL
%left TOKEN_IS TOKEN_LIKE

// For Unary Minus (Query 4)
%right UMINUS

%left TOKEN_ON TOKEN_USING
%left TOKEN_LEFT TOKEN_RIGHT TOKEN_FULL
%left TOKEN_INNER TOKEN_CROSS
%left TOKEN_JOIN

%right TOKEN_FOR
%left TOKEN_COMMA

%start single_input_statement

%%

// New start rule definition:
single_input_statement:
    /* empty input */ {
        if (parser_context) {
            parser_context->internal_set_ast(nullptr);
        }
        $$ = nullptr;
    }
    | statement {
        // The 'statement' rule's alternatives (e.g., select_statement, insert_statement)
        // are responsible for calling parser_context->internal_set_ast($1)
        // with the AST node they produce.
        // This 'single_input_statement' rule simply propagates the AST node ($1)
        // received from the 'statement' rule.
        // The parser_context->ast_root_ should already hold the correct AST node ($1)
        // due to the call within the 'statement' rule's actions.
        $$ = $1;
    }
    ;

statement:
    simple_statement    { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | select_statement  { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | insert_statement  { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | set_statement     { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | delete_statement  { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | show_statement    { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | begin_statement   { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    | commit_statement  { $$ = $1; if (parser_context) parser_context->internal_set_ast($1); }
    ;

simple_statement:
    command_statement   { $$ = $1; }
    ;

command_statement:
    TOKEN_QUIT optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_COMMAND, std::move(*$1));
        delete $1;
    }
    ;

optional_semicolon:
    TOKEN_SEMICOLON { $$ = nullptr; }
    | /* empty */   { $$ = nullptr; }
    ;

identifier_node:
    TOKEN_IDENTIFIER {
        std::string val = std::move(*$1);
        delete $1;
        // Unquoting logic for backticked identifiers
        if (val.length() >= 2 && val.front() == '`' && val.back() == '`') {
            val = val.substr(1, val.length() - 2);
            // Replace `` with `
            size_t pos = 0;
            while ((pos = val.find("``", pos)) != std::string::npos) {
                val.replace(pos, 2, "`");
                pos += 1; // Move past the replaced `
            }
        }
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_IDENTIFIER, std::move(val));
    }
    ;

qualified_identifier_node: // For table.column or schema.table
    identifier_node TOKEN_DOT identifier_node {
        std::string qualified_name = $1->value + "." + $3->value;
        // Create a generic node; specific handling might be needed based on context
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_QUALIFIED_IDENTIFIER, std::move(qualified_name));
        $$->addChild($1); // table/schema
        $$->addChild($3); // column/table
    }
    // Potentially add schema.table.column or db.schema.table if needed, though usually context implies this
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
            // This case might occur if the lexer returns unquoted strings for some reason,
            // or for types like hex literals X'...' that might not be strictly string literals
            // but are passed as TOKEN_STRING_LITERAL.
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
                    case '0': unescaped_val += '\0'; break; // Null character
                    case 'Z': unescaped_val += '\x1A'; break; // Ctrl+Z for SUB
                    case '\\': unescaped_val += '\\'; break;
                    case '\'': unescaped_val += '\''; break;
                    case '"': unescaped_val += '"'; break;
                    // MySQL also allows escaping % and _ for LIKE contexts, but that's usually handled by
                    // the expression evaluation, not lexing/parsing of the literal itself.
                    default:
                        // If the character after \ is not a special escape char, MySQL treats \ as a literal \
                        // However, standard SQL behavior is often to just take the character literally.
                        // For simplicity here, let's assume it might be an escaped char that we just pass through,
                        // or a literal backslash followed by a character.
                        // A more robust parser might differentiate or follow strict SQL standard for unknown escapes.
                        // For now, we'll treat it as literal character following backslash if not recognized.
                        unescaped_val += val_content[i]; // Or just `unescaped_val += '\\'; unescaped_val += val_content[i];` if \ is always literal
                        break;
                }
                escaping = false;
            } else if (val_content[i] == '\\') {
                // Check if it's a MySQL specific escape sequence that the lexer didn't handle
                // (e.g., if lexer is very basic and passes \ through).
                // Standard SQL string literals use '' for ' and "" for ".
                // MySQL also uses \', \", \\.
                escaping = true;
            } else if (quote_char != 0 && val_content[i] == quote_char && (i + 1 < val_content.length() && val_content[i+1] == quote_char) ) {
                // Handle '' or "" for literal quote (SQL Standard)
                unescaped_val += quote_char;
                i++; // Skip the second quote
            }
            else {
                unescaped_val += val_content[i];
            }
        }
        if(escaping) unescaped_val+='\\'; // if string ends with a single backslash

        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_STRING_LITERAL, std::move(unescaped_val));
    }
    ;

number_literal_node:
    TOKEN_NUMBER_LITERAL {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_NUMBER_LITERAL, std::move(*$1));
        delete $1;
    }
    ;

/* --- SELECT Statement Rules --- */
select_statement:
    TOKEN_SELECT opt_select_options select_item_list
                 opt_into_clause
                 opt_from_clause
                 opt_where_clause
                 opt_group_by_clause
                 opt_having_clause
                 opt_order_by_clause
                 opt_limit_clause
                 opt_locking_clause_list
                 optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SELECT_STATEMENT);
        if ($2) $$->addChild($2); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SELECT_OPTIONS));
        $$->addChild($3); // select_item_list
        if ($4) $$->addChild($4); // opt_into_clause
        if ($5) $$->addChild($5); // opt_from_clause
        if ($6) $$->addChild($6); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_WHERE_CLAUSE));
        if ($7) $$->addChild($7); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_GROUP_BY_CLAUSE));
        if ($8) $$->addChild($8); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_HAVING_CLAUSE));
        if ($9) $$->addChild($9); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ORDER_BY_CLAUSE));
        if ($10) $$->addChild($10); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LIMIT_CLAUSE));
        if ($11) $$->addChild($11); // opt_locking_clause_list
    }
    ;

opt_alias:
    /* empty */ { $$ = nullptr; }
    | TOKEN_AS identifier_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ALIAS, $2->value);
        delete $2;
    }
    | identifier_node { // Implicit AS
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ALIAS, $1->value);
        delete $1;
    }
    ;

select_item:
    identifier_node TOKEN_DOT TOKEN_ASTERISK { // table.*
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SELECT_ITEM);
        MySQLParser::AstNode* table_asterisk = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ASTERISK, $1->value + ".*");
        table_asterisk->addChild($1); // Store the table identifier
        $$->addChild(table_asterisk);
    }
    | TOKEN_ASTERISK { // *
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SELECT_ITEM);
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ASTERISK, "*"));
    }
    | expr opt_alias {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SELECT_ITEM);
        $$->addChild($1);
        if ($2) {
            $$->addChild($2);
        }
    }
    ;

select_item_list:
    select_item {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SELECT_ITEM_LIST);
        $$->addChild($1);
    }
    | select_item_list TOKEN_COMMA select_item {
        $1->addChild($3);
        $$ = $1;
    }
    ;

select_option_item:
    TOKEN_DISTINCT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "DISTINCT"); }
    | TOKEN_ALL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "ALL"); }
    // Add other select options like SQL_CALC_FOUND_ROWS if needed
    ;

opt_select_options:
    /* empty */ { $$ = nullptr; }
    | select_option_item opt_select_options { // Allows multiple options like ALL DISTINCT (though not valid SQL, grammar might allow)
        MySQLParser::AstNode* options_node;
        if ($2 == nullptr) { // First option in the list
            options_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SELECT_OPTIONS);
            options_node->addChild($1);
        } else { // Subsequent options
            options_node = $2;
            // Prepend the new option to maintain order or just add
            std::vector<MySQLParser::AstNode*> temp_children = options_node->children;
            options_node->children.clear();
            options_node->addChild($1); // Add new option first
            for (MySQLParser::AstNode* child : temp_children) {
                options_node->addChild(child);
            }
        }
        $$ = options_node;
    }
    ;

/* --- INTO Clause Rules --- */
opt_into_clause:
    /* empty */ { $$ = nullptr; }
    | into_clause { $$ = $1; }
    ;

into_clause:
    TOKEN_INTO TOKEN_OUTFILE string_literal_node opt_into_outfile_options_list {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTO_OUTFILE);
        $$->addChild($3); // string_literal_node for filename
        if ($4) $$->addChild($4); // opt_into_outfile_options_list
    }
    | TOKEN_INTO TOKEN_DUMPFILE string_literal_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTO_DUMPFILE);
        $$->addChild($3); // string_literal_node for filename
    }
    | TOKEN_INTO user_var_list {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTO_VAR_LIST);
        $$->addChild($2); // user_var_list
    }
    ;

user_var_list:
    user_variable {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_COLUMN_LIST); // Re-use for list of user variables
        $$->addChild($1);
    }
    | user_var_list TOKEN_COMMA user_variable {
        $1->addChild($3);
        $$ = $1;
    }
    ;

opt_into_outfile_options_list:
    /* empty */ { $$ = nullptr; }
    | TOKEN_CHARACTER TOKEN_SET charset_name_or_default opt_into_outfile_options_list_tail {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FILE_OPTIONS);
        MySQLParser::AstNode* charset_opt_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_CHARSET_OPTION);
        charset_opt_node->addChild($3); // charset_name_or_default
        $$->addChild(charset_opt_node);
        if($4) { // opt_into_outfile_options_list_tail
            for(auto child : $4->children) {
                $$->addChild(child); // Add children from the tail list
            }
            $4->children.clear(); // Avoid double deletion if $4 is deleted
            delete $4;
        }
    }
    | into_outfile_options_list { $$ = $1; }
    ;

opt_into_outfile_options_list_tail:
    /* empty */ { $$ = nullptr; }
    | into_outfile_options_list { $$ = $1; }
    ;

into_outfile_options_list:
    into_outfile_option {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FILE_OPTIONS); // Wrapper for single/multiple options
        $$->addChild($1);
    }
    | into_outfile_options_list into_outfile_option {
        $1->addChild($2);
        $$ = $1;
    }
    ;

into_outfile_option:
    fields_options_clause { $$ = $1; }
    | lines_options_clause  { $$ = $1; }
    ;

fields_options_clause:
    TOKEN_FIELDS field_option_outfile_list {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FIELDS_OPTIONS_CLAUSE);
        $$->addChild($2); // field_option_outfile_list
    }
    ;

field_option_outfile_list:
    field_option_outfile {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FILE_OPTIONS); // Re-using for list of field options
        $$->addChild($1);
    }
    | field_option_outfile_list field_option_outfile {
        $1->addChild($2);
        $$ = $1;
    }
    ;

field_option_outfile:
    TOKEN_TERMINATED TOKEN_BY string_literal_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FIELDS_TERMINATED_BY);
        $$->addChild($3);
    }
    | TOKEN_OPTIONALLY TOKEN_ENCLOSED TOKEN_BY string_literal_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FIELDS_OPTIONALLY_ENCLOSED_BY);
        $$->addChild($4);
    }
    | TOKEN_ENCLOSED TOKEN_BY string_literal_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FIELDS_ENCLOSED_BY);
        $$->addChild($3);
    }
    | TOKEN_ESCAPED TOKEN_BY string_literal_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FIELDS_ESCAPED_BY);
        $$->addChild($3);
    }
    ;

lines_options_clause:
    TOKEN_LINES line_option_outfile_list {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LINES_OPTIONS_CLAUSE);
        $$->addChild($2); // line_option_outfile_list
    }
    ;

line_option_outfile_list:
    line_option_outfile {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FILE_OPTIONS); // Re-using for list of line options
        $$->addChild($1);
    }
    | line_option_outfile_list line_option_outfile {
        $1->addChild($2);
        $$ = $1;
    }
    ;

line_option_outfile:
    TOKEN_STARTING TOKEN_BY string_literal_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LINES_STARTING_BY);
        $$->addChild($3);
    }
    | TOKEN_TERMINATED TOKEN_BY string_literal_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LINES_TERMINATED_BY);
        $$->addChild($3);
    }
    ;

/* --- Locking Clause Rules --- */
opt_locking_clause_list:
    /* empty */ { $$ = nullptr; }
    | locking_clause_list { $$ = $1; }
    ;

locking_clause_list:
    locking_clause {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LOCKING_CLAUSE_LIST);
        $$->addChild($1);
    }
    | locking_clause_list locking_clause {
        $1->addChild($2);
        $$ = $1;
    }
    ;

locking_clause:
    TOKEN_FOR lock_strength opt_lock_table_list opt_lock_option {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LOCKING_CLAUSE);
        $$->addChild($2); // lock_strength
        if ($3) $$->addChild($3); // opt_lock_table_list
        if ($4) $$->addChild($4); // opt_lock_option
    }
    ;

lock_strength:
    TOKEN_UPDATE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LOCK_STRENGTH, "UPDATE"); }
    | TOKEN_SHARE  { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LOCK_STRENGTH, "SHARE"); }
    ;

opt_lock_table_list:
    /* empty */ { $$ = nullptr; }
    | TOKEN_OF table_name_list_for_delete { // Re-use table_name_list_for_delete for simplicity
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LOCK_TABLE_LIST);
        $$->addChild($2); // table_name_list_for_delete
    }
    ;

opt_lock_option:
    /* empty */ { $$ = nullptr; }
    | TOKEN_NOWAIT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LOCK_OPTION, "NOWAIT"); }
    | TOKEN_SKIP TOKEN_LOCKED { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LOCK_OPTION, "SKIP LOCKED"); }
    ;

/* --- FROM Clause and JOINs --- */
// For Query 2: Allow qualified identifiers in table references
table_name_spec:
    identifier_node { $$ = $1; }
    | qualified_identifier_node { $$ = $1; } // e.g. information_schema.tables
    ;

opt_from_clause:
    /* empty */ { $$ = nullptr; }
    | from_clause { $$ = $1; }
    ;

from_clause:
    TOKEN_FROM table_reference {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FROM_CLAUSE);
        $$->addChild($2);
    }
    ;

table_reference:
    table_reference_inner { $$ = $1; }
    | joined_table        { $$ = $1; }
    ;

table_reference_inner:
    table_name_spec opt_alias {
        MySQLParser::AstNode* ref_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TABLE_REFERENCE);
        ref_node->addChild($1); // Add table_name_spec as child ($1 is already an AstNode)
        if ($2) { ref_node->addChild($2); } // Add alias as child
        $$ = ref_node;
    }
    | derived_table opt_alias {
        if ($2) {
             $1->addChild($2);
        }
        $$ = $1;
    }
    | TOKEN_LPAREN table_reference TOKEN_RPAREN opt_alias {
        MySQLParser::AstNode* sub_ref_item = $2;
        if ($4) {
            MySQLParser::AstNode* aliased_sub_ref = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TABLE_REFERENCE);
            aliased_sub_ref->addChild(sub_ref_item);
            aliased_sub_ref->addChild($4);
            $$ = aliased_sub_ref;
        } else {
            $$ = sub_ref_item;
        }
    }
    ;

subquery:
    TOKEN_LPAREN select_statement TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SUBQUERY);
        $$->addChild($2); // select_statement
    }
    ;

derived_table:
    subquery { // Typically requires an alias, handled by table_reference_inner
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_DERIVED_TABLE);
        $$->addChild($1); // subquery
    }
    ;

// Handles NATURAL [INNER|LEFT|RIGHT [OUTER]] JOIN
join_type_natural_spec:
    TOKEN_NATURAL opt_join_type {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_JOIN_TYPE_NATURAL_SPEC);
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "NATURAL"));
        if ($2) { // opt_join_type (e.g. LEFT node)
            $$->addChild($2);
        } else { // Pure NATURAL implies INNER
            $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "INNER"));
        }
    }
    ;

opt_join_type: // For non-NATURAL joins: INNER, LEFT [OUTER], RIGHT [OUTER], FULL [OUTER]
    /* empty */ { $$ = nullptr; } // Implicitly INNER if only TOKEN_JOIN is used
    | TOKEN_INNER               { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "INNER"); }
    | TOKEN_LEFT                { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "LEFT"); }
    | TOKEN_LEFT TOKEN_OUTER    { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "LEFT OUTER"); }
    | TOKEN_RIGHT               { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "RIGHT"); }
    | TOKEN_RIGHT TOKEN_OUTER   { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "RIGHT OUTER"); }
    | TOKEN_FULL                { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "FULL"); }
    | TOKEN_FULL TOKEN_OUTER    { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "FULL OUTER"); }
    ;


joined_table:
    table_reference join_type_natural_spec TOKEN_JOIN table_reference_inner opt_join_condition {
        // table_ref NATURAL [INNER|LEFT|RIGHT] JOIN table_ref_inner [ON|USING]
        // $2 is NODE_JOIN_TYPE_NATURAL_SPEC
        MySQLParser::AstNode* join_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_JOIN_CLAUSE);
        std::string natural_join_type_str = $2->children[0]->value; // "NATURAL"
        if ($2->children.size() > 1) { // Has an explicit type like LEFT
            natural_join_type_str += " " + $2->children[1]->value; // "NATURAL LEFT"
        }
        join_node->value = natural_join_type_str + " JOIN";
        join_node->addChild($1); // Left table
        // join_node->addChild($2); // The natural spec node itself - or just use its info for value
        join_node->addChild($4); // Right table
        if ($5) join_node->addChild($5); // Condition (should be null for pure natural if USING is not part of natural spec)
        delete $2; // $2's info is incorporated into join_node->value
        $$ = join_node;
    }
    | table_reference opt_join_type TOKEN_JOIN table_reference_inner opt_join_condition {
        // table_ref [INNER|LEFT|RIGHT|FULL [OUTER]] JOIN table_ref_inner [ON|USING]
        MySQLParser::AstNode* join_node;
        std::string join_desc;
        MySQLParser::AstNode* explicit_join_type = $2; // opt_join_type node or nullptr

        if (explicit_join_type) {
            join_desc = explicit_join_type->value + " JOIN";
        } else { // Implicit INNER JOIN
            join_desc = "INNER JOIN"; // Default for JOIN without explicit type
            explicit_join_type = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "INNER"); // Create node for AST
        }
        join_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_JOIN_CLAUSE, join_desc);
        join_node->addChild($1); // Left table
        join_node->addChild(explicit_join_type); // The type node (created if was implicit)
        join_node->addChild($4); // Right table

        if ($5) { // ON or USING condition
            join_node->addChild($5);
        } else { // No condition
            // For INNER JOIN without ON/USING, it's a CROSS JOIN.
            // For other JOIN types (LEFT, RIGHT, FULL) without ON/USING, it's usually a syntax error.
            if (join_desc == "INNER JOIN") { // This covers implicit and explicit INNER
                 join_node->value = "CROSS JOIN"; // Semantically, it's a CROSS JOIN
                 // The explicit_join_type child still says "INNER", which might be fine or you could change it.
            } else if (parser_context) {
                // For LEFT/RIGHT/FULL JOIN, an ON or USING is typically mandatory.
                // The parser might accept it syntactically here, but it's semantically problematic.
                // MySQL might treat some cases as errors or default to CROSS JOIN like behavior.
                // This grammar doesn't strictly enforce ON/USING for LEFT/RIGHT/FULL here.
                // parser_context->internal_add_error(join_desc + " usually requires an ON or USING clause.");
            }
        }
        $$ = join_node;
    }
    | table_reference TOKEN_CROSS TOKEN_JOIN table_reference_inner {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_JOIN_CLAUSE, "CROSS JOIN");
        $$->addChild($1); // Left table
        $$->addChild($4); // Right table
    }
    | table_reference TOKEN_COMMA table_reference_inner { // Old style comma join implies CROSS JOIN
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_JOIN_CLAUSE, "CROSS JOIN");
        $$->addChild($1); // Left table
        $$->addChild($3); // Right table
    }
    ;

opt_join_condition:
    /* empty */ { $$ = nullptr; }
    | join_condition { $$ = $1; }
    ;

join_condition:
    TOKEN_ON expr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_JOIN_CONDITION_ON);
        $$->addChild($2); // expr
    }
    | TOKEN_USING TOKEN_LPAREN identifier_list TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_JOIN_CONDITION_USING);
        $$->addChild($3); // identifier_list
    }
    ;

identifier_list_args:
   identifier_list
   | '(' identifier_list ')' { $$ = $2; }

identifier_list:
    identifier_node {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_COLUMN_LIST); // Re-use for list of identifiers
        $$->addChild($1);
    }
    | identifier_list TOKEN_COMMA identifier_node {
        $1->addChild($3);
        $$ = $1;
    }
    ;

/* --- INSERT Statement Rules (Query 3) --- */
opt_column_list:
    /* empty */ { $$ = nullptr; }
    | TOKEN_LPAREN column_list_item_list TOKEN_RPAREN { $$ = $2; } // $2 is column_list_item_list
    ;

column_list_item_list:
    column_list_item {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_COLUMN_LIST);
        $$->addChild($1);
    }
    | column_list_item_list TOKEN_COMMA column_list_item {
        $1->addChild($3);
        $$ = $1;
    }
    ;

column_list_item:
    identifier_node { $$ = $1; }
    ;

value_row:
    TOKEN_LPAREN expression_list TOKEN_RPAREN { $$ = $2; }
    ;

value_row_list:
    value_row {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_EXPR, "value_row_list_wrapper");
        $$->addChild($1);
    }
    | value_row_list TOKEN_COMMA value_row {
        $1->addChild($3);
        $$ = $1;
    }
    ;

values_clause:
    TOKEN_VALUES value_row_list {
        // Create a specific node for VALUES clause for clarity in AST
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_EXPR, "VALUES_CLAUSE"); // Placeholder type
        // Consider creating NODE_VALUES_CLAUSE in mysql_ast.h
        $$->addChild($2); // Add the value_row_list_wrapper
    }
    ;

insert_statement:
    TOKEN_INSERT TOKEN_INTO table_name_spec opt_column_list values_clause optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INSERT_STATEMENT);
        $$->addChild($3); // table_name_spec
        if ($4) $$->addChild($4); // opt_column_list (which is column_list_item_list or null)
        else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_COLUMN_LIST)); // Add empty list if not present
        $$->addChild($5); // values_clause
    }
    // Add other forms of INSERT if needed (e.g., INSERT ... SELECT, INSERT ... SET)
    ;

value_for_insert:
    string_literal_node { $$ = $1; }
    | number_literal_node { $$ = $1; }
    // This rule is likely too simple and superseded by expression_list for actual values.
    // It might be used if there's a very constrained INSERT syntax variant.
    ;

/* --- DELETE Statement Rules --- */
delete_statement:
    TOKEN_DELETE opt_delete_options TOKEN_FROM table_name_spec // Use table_name_spec
                 opt_where_clause opt_order_by_clause opt_limit_clause optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_DELETE_STATEMENT);
        if ($2) $$->addChild($2); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($4); // table_name_spec
        if ($5) $$->addChild($5); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_WHERE_CLAUSE));
        if ($6) $$->addChild($6); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ORDER_BY_CLAUSE));
        if ($7) $$->addChild($7); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LIMIT_CLAUSE));
    }
    | TOKEN_DELETE opt_delete_options table_name_list_for_delete TOKEN_FROM table_reference // table_reference for multi-table
                 opt_where_clause optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_DELETE_STATEMENT, "MULTI_TABLE_TARGET_LIST_FROM");
        if ($2) $$->addChild($2); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($3); // table_name_list_for_delete
        MySQLParser::AstNode* from_wrapper = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_FROM_CLAUSE);
        from_wrapper->addChild($5); // table_reference
        $$->addChild(from_wrapper);
        if ($6) $$->addChild($6); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_WHERE_CLAUSE));
    }
    | TOKEN_DELETE opt_delete_options TOKEN_FROM table_name_list_for_delete TOKEN_USING table_reference // table_reference for multi-table
                 opt_where_clause optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_DELETE_STATEMENT, "MULTI_TABLE_FROM_USING");
        if ($2) $$->addChild($2); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($4); // table_name_list_for_delete
        MySQLParser::AstNode* using_wrapper = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_USING_CLAUSE);
        using_wrapper->addChild($6); // table_reference
        $$->addChild(using_wrapper);
        if ($7) $$->addChild($7); else $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_WHERE_CLAUSE));
    }
    ;

opt_delete_options:
    /* empty */ { $$ = nullptr; }
    | delete_option_item_list { $$ = $1; }
    ;

delete_option_item_list:
    delete_option {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_DELETE_OPTIONS);
        $$->addChild($1);
    }
    | delete_option_item_list delete_option {
        $1->addChild($2);
        $$ = $1;
    }
    ;

delete_option:
    TOKEN_LOW_PRIORITY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "LOW_PRIORITY"); }
    | TOKEN_QUICK      { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "QUICK"); }
    | TOKEN_IGNORE_SYM { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "IGNORE"); }
    ;

table_name_list_for_delete: // List of tables to delete FROM in multi-table delete
    table_name_spec { // Use table_name_spec here
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TABLE_NAME_LIST);
        $$->addChild($1);
    }
    | table_name_list_for_delete TOKEN_COMMA table_name_spec {
        $1->addChild($3);
        $$ = $1;
    }
    ;

/* --- SET Statement Rules --- */
// For Query 1: SET TRANSACTION ISOLATION LEVEL ...
isolation_level_spec:
    TOKEN_READ TOKEN_COMMITTED         { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "READ COMMITTED"); }
    | TOKEN_READ TOKEN_UNCOMMITTED     { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "READ UNCOMMITTED"); }
    | TOKEN_REPEATABLE TOKEN_READ      { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "REPEATABLE READ"); }
    | TOKEN_SERIALIZABLE              { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "SERIALIZABLE"); }
    ;

transaction_characteristic:
    TOKEN_ISOLATION TOKEN_LEVEL isolation_level_spec {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_EXPR, "ISOLATION_LEVEL");
        $$->addChild($3);
    }
    | TOKEN_READ TOKEN_WRITE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "READ WRITE"); }
    | TOKEN_READ TOKEN_ONLY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "READ ONLY"); }
    ;

transaction_characteristic_list:
    transaction_characteristic {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_EXPR, "TXN_CHAR_LIST");
        $$->addChild($1);
    }
    | transaction_characteristic_list TOKEN_COMMA transaction_characteristic {
        $1->addChild($3);
        $$ = $1;
    }
    ;

set_transaction_statement:
    TOKEN_SESSION TOKEN_TRANSACTION transaction_characteristic_list {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SET_STATEMENT, "SET_SESSION_TRANSACTION"); // Or more specific type
        // Consider NODE_SET_TRANSACTION_STATEMENT in mysql_ast.h
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "SESSION")); // Add scope
        $$->addChild($3); // transaction_characteristic_list
    }
    | TOKEN_GLOBAL TOKEN_TRANSACTION transaction_characteristic_list {
         $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SET_STATEMENT, "SET_GLOBAL_TRANSACTION");
         $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "GLOBAL"));
         $$->addChild($3);
    }
    | TOKEN_TRANSACTION transaction_characteristic_list { // Default to SESSION
         $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SET_STATEMENT, "SET_TRANSACTION");
         // Could add an implicit SESSION scope node if desired for AST consistency
         $$->addChild($2); // transaction_characteristic_list
    }
    ;

set_statement:
    TOKEN_SET set_names_stmt optional_semicolon { $$ = $2; }
    | TOKEN_SET set_charset_stmt optional_semicolon { $$ = $2; }
    | TOKEN_SET set_option_value_list optional_semicolon {
        // $2 is the "set_var_assignments" node.
        // The set_statement node should probably wrap this for consistency.
        MySQLParser::AstNode* set_vars_stmt = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SET_STATEMENT, "SET_VARIABLES");
        set_vars_stmt->addChild($2);
        $$ = set_vars_stmt;
    }
    | TOKEN_SET set_transaction_statement optional_semicolon { $$ = $2; }
    ;

set_names_stmt:
    TOKEN_NAMES charset_name_or_default {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SET_NAMES);
        $$->addChild($2);
    }
    | TOKEN_NAMES charset_name_or_default TOKEN_COLLATE collation_name_choice {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SET_NAMES);
        $$->addChild($2);
        $$->addChild($4);
    }
    ;

set_charset_stmt:
    TOKEN_CHARACTER TOKEN_SET charset_name_or_default {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SET_CHARSET);
        $$->addChild($3);
    }
    ;

charset_name_or_default:
    string_literal_node { $$ = $1; }
    | TOKEN_DEFAULT     { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "DEFAULT"); }
    | identifier_node   { $$ = $1; }
    ;

collation_name_choice:
    string_literal_node { $$ = $1; }
    | identifier_node   { $$ = $1; }
    ;

// List of variable assignments: @a=1, GLOBAL b=2
set_option_value_list:
    set_option_value {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SET_OPTION_VALUE_LIST);
        // $1 must be NODE_VARIABLE_ASSIGNMENT
        $$->addChild($1);
    }
    | set_option_value_list TOKEN_COMMA set_option_value {
        $1->addChild($3);
        $$ = $1;
    }
    ;

set_option_value:
    variable_to_set TOKEN_EQUAL expr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild($3);

        $$->val_init_pos = @3.first_column;
        $$->val_end_pos = @3.last_column;
    }
    | variable_to_set TOKEN_EQUAL TOKEN_DEFAULT {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VALUE_LITERAL, "DEFAULT"));

        $$->val_init_pos = @3.first_column;
        $$->val_end_pos = @3.last_column;
    }
    | variable_to_set TOKEN_EQUAL TOKEN_ON {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VALUE_LITERAL, "ON"));

        $$->val_init_pos = @3.first_column;
        $$->val_end_pos = @3.last_column;
    }
    | variable_to_set TOKEN_EQUAL TOKEN_ALL {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VALUE_LITERAL, "ALL"));

        $$->val_init_pos = @3.first_column;
        $$->val_end_pos = @3.last_column;
    }
    | variable_to_set TOKEN_EQUAL TOKEN_BINARY {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VALUE_LITERAL, "BINARY"));

        $$->val_init_pos = @3.first_column;
        $$->val_end_pos = @3.last_column;
    }
    | variable_to_set TOKEN_EQUAL TOKEN_ROW {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VALUE_LITERAL, "ROW"));

        $$->val_init_pos = @3.first_column;
        $$->val_end_pos = @3.last_column;
    }
    | variable_to_set TOKEN_EQUAL TOKEN_SYSTEM {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VALUE_LITERAL, "SYSTEM"));

        $$->val_init_pos = @3.first_column;
        $$->val_end_pos = @3.last_column;
    }
    ;

// Expression grammar rules:
expr:
    expr TOKEN_OR expr %prec TOKEN_OR {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "OR");
        $$->addChild($1);
        $$->addChild($3);
    }
    | expr TOKEN_XOR expr %prec TOKEN_XOR {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "XOR");
        $$->addChild($1);
        $$->addChild($3);
    }
    | expr TOKEN_AND expr %prec TOKEN_AND {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "AND");
        $$->addChild($1);
        $$->addChild($3);
    }
    | TOKEN_NOT expr %prec TOKEN_NOT {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "NOT");
        $$->addChild($2);
    }
    | boolean_primary_expr %prec TOKEN_SET
    ;

opt_not:
    /* empty */ { $$ = nullptr; }
    | TOKEN_NOT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "NOT "); }
    ;

truth_value:
    TOKEN_TRUE       { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "TRUE"); }
    | TOKEN_FALSE    { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "FALSE"); }
    | TOKEN_UNKNOWN  { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "UNKNOWN"); }
    ;

boolean_primary_expr:
    boolean_primary_expr TOKEN_IS TOKEN_NULL_KEYWORD %prec TOKEN_IS {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_IS_NULL_EXPRESSION);
        $$->addChild($1);
    }
    | boolean_primary_expr TOKEN_IS TOKEN_NOT TOKEN_NULL_KEYWORD %prec TOKEN_IS {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_IS_NOT_NULL_EXPRESSION);
        $$->addChild($1);
    }
    | boolean_primary_expr TOKEN_IS opt_not truth_value %prec TOKEN_IS {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_IS_NOT_NULL_EXPRESSION);
        $$->addChild($1);
    }
    | boolean_primary_expr comparison_operator predicate {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_COMPARISON_EXPRESSION, $2->value);
        delete $2;
        $$->addChild($1);
        $$->addChild($3);
    }
    | boolean_primary_expr comparison_operator all_or_any select_subexpr %prec TOKEN_EQUAL {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_COMPARISON_EXPRESSION, $2->value);
        delete $2;
        $$->addChild($1);
        $$->addChild($3);
        $$->addChild($4);
    }
    | predicate %prec TOKEN_SET
    ;

all_or_any:
      TOKEN_ALL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "ALL"); }
    | TOKEN_ANY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "ANY"); }
    ;

opt_of:
    /* empty */ { $$ = nullptr; }
    | TOKEN_OF  { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "OF "); }
    ;

opt_escape:
    /* empty */                                                 { $$ = nullptr; }
    | TOKEN_ESCAPE simple_bit_expr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ESCAPE_CLAUSE);
        // The escape character expression (usually a string literal)
        $$->addChild($2);
    }
    ;

predicate:
    bit_expr TOKEN_IN select_subexpr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "IN");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr TOKEN_NOT TOKEN_IN select_subexpr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "NOT IN");
        $$->addChild($1);
        $$->addChild($4);
    }
    | bit_expr TOKEN_IN TOKEN_LPAREN expression_list TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "IN");
        $$->addChild($1);
        $$->addChild($4);
    }
    | bit_expr TOKEN_NOT TOKEN_IN TOKEN_LPAREN expression_list TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "NOT IN");
        $$->addChild($1);
        $$->addChild($5);
    }
    | bit_expr opt_not TOKEN_LIKE simple_bit_expr {
        std::string op_name = ($2 ? "NOT LIKE" : "LIKE");
        if($2) delete $2;
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, op_name);
        $$->addChild($1);
        $$->addChild($4);
    }
    | bit_expr opt_not TOKEN_LIKE simple_bit_expr TOKEN_ESCAPE simple_bit_expr %prec TOKEN_LIKE {
        std::string op_name = ($2 ? "NOT LIKE" : "LIKE");
        if($2) delete $2;
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, op_name);
        $$->addChild($1);
        $$->addChild($4);
        $$->addChild($6);
    }
    | bit_expr opt_not TOKEN_REGEXP bit_expr {
        std::string op_name = ($2 ? "NOT REGEXP" : "REGEXP");
        if($2) delete $2;
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, op_name);
        $$->addChild($1);
        $$->addChild($4);
    }
    | bit_expr opt_not TOKEN_BETWEEN bit_expr TOKEN_AND bit_expr {
        std::string op_name = ($2 ? "NOT BETWEEN" : "BETWEEN");
        if($2) delete $2;
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, op_name);
        $$->addChild($1);
        $$->addChild($4);
        $$->addChild($6);
    }
    | bit_expr TOKEN_MEMBER opt_of '(' simple_bit_expr ')' {
        std::string op_name = ($3 ? "MEMBER OF" : "MEMBER");
        if($3) delete $3;
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, op_name);
        $$->addChild($1);
        $$->addChild($5);
    }
    | bit_expr TOKEN_SOUNDS TOKEN_LIKE bit_expr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "SOUNDS LIKE");
        $$->addChild($1);
        $$->addChild($4);
    }
    | bit_expr TOKEN_MEMBER TOKEN_OF TOKEN_LPAREN bit_expr TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "MEMBER OF");
        $$->addChild($1);
        $$->addChild($5);
    }
    | bit_expr TOKEN_MEMBER TOKEN_LPAREN bit_expr TOKEN_RPAREN { // Example 48: MEMBER (json_array_string)
        // Normalizing to MEMBER OF
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "MEMBER OF");
        $$->addChild($1);
        $$->addChild($4);
    }
    | bit_expr %prec TOKEN_SET
    ;

bit_expr:
    bit_expr '|' bit_expr %prec '|' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "|");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr '&' bit_expr %prec '%' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "&");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr TOKEN_BITWISE_LSHIFT bit_expr %prec TOKEN_BITWISE_LSHIFT {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "<<");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr TOKEN_BITWISE_RSHIFT bit_expr %prec TOKEN_BITWISE_RSHIFT {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, ">>");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr '+' bit_expr %prec '+' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "+");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr '+' TOKEN_INTERVAL expr interval %prec '+' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "+");
        $$->addChild($1);
        $$->addChild($4);
        $$->addChild($5);
    }
    | bit_expr '-' bit_expr %prec '-' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "-");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr '-' TOKEN_INTERVAL expr interval %prec '-' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "-");
        $$->addChild($1);
        $$->addChild($4);
        $$->addChild($5);
    }
    | bit_expr '*' bit_expr %prec '*' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "*");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr '/' bit_expr %prec '/' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "/");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr '%' bit_expr %prec '%' {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "%");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr TOKEN_DIV bit_expr %prec TOKEN_DIV {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "DIV");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr TOKEN_MOD bit_expr %prec TOKEN_MOD {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "MOD");
        $$->addChild($1);
        $$->addChild($3);
    }
    | bit_expr '^' bit_expr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "^");
        $$->addChild($1);
        $$->addChild($3);
    }
    | simple_bit_expr %prec TOKEN_SET                         { $$ = $1; }
    ;

literal_or_null:
    string_literal_node   { $$ = $1; }
    | number_literal_node { $$ = $1; }
    | TOKEN_TRUE          { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_BOOLEAN_LITERAL, "TRUE"); }
    | TOKEN_FALSE         { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_BOOLEAN_LITERAL, "FALSE"); }
    | TOKEN_NULL_KEYWORD  { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_NULL_LITERAL, "NULL"); }
    ;

timestamp:
      TOKEN_DAY         { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "DAY"); }
    | TOKEN_WEEK        { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "WEEK"); }
    | TOKEN_HOUR        { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "HOUR"); }
    | TOKEN_MINUTE      { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "MINUTE"); }
    | TOKEN_MONTH       { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "MONTH"); }
    | TOKEN_QUARTER     { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "QUARTER"); }
    | TOKEN_SECOND      { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "SECOND"); }
    | TOKEN_MICROSECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "MICROSECOND"); }
    | TOKEN_YEAR        { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TIMESTAMP, "YEAR"); }
    ;

interval:
      timestamp { $$ = $1; }
    | TOKEN_DAY_HOUR           { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "DAY_HOUR"); }
    | TOKEN_DAY_MICROSECOND    { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "DAY_MICROSECOND"); }
    | TOKEN_DAY_MINUTE         { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "DAY_MINUTE"); }
    | TOKEN_DAY_SECOND         { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "DAY_SECOND"); }
    | TOKEN_HOUR_MICROSECOND   { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "HOUR_MICROSECOND"); }
    | TOKEN_HOUR_MINUTE        { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "HOUR_MINUTE"); }
    | TOKEN_HOUR_SECOND        { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "HOUR_SECOND"); }
    | TOKEN_MINUTE_MICROSECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "MINUTE_MICROSECOND"); }
    | TOKEN_MINUTE_SECOND      { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "MINUTE_SECOND"); }
    | TOKEN_SECOND_MICROSECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "SECOND_MICROSECOND"); }
    | TOKEN_YEAR_MONTH         { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_INTERVAL, "YEAR_MONTH"); }
    ;

any_token:
    TOKEN_SELECT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_FROM { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_INSERT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_INTO { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_VALUES { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_QUIT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SET { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_NAMES { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_CHARACTER { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_GLOBAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SESSION { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_PERSIST { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_PERSIST_ONLY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DEFAULT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_COLLATE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SHOW { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DATABASES { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_BEGIN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_COMMIT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_IS { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_NULL_KEYWORD { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_TRUE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_FALSE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_UNKNOWN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_BINARY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ROW { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SYSTEM { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_NOT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_BETWEEN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MEMBER { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ESCAPE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_REGEXP { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_OFFSET { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DELETE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LOW_PRIORITY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_QUICK { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_IGNORE_SYM { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_USING { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ORDER { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_BY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LIMIT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ASC { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DESC { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_WHERE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_AS { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DISTINCT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_GROUP { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ALL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ANY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_HAVING { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_INTERVAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_OR { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_XOR { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_AND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_DIV { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MOD { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_JOIN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_INNER { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LEFT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_RIGHT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_FULL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_OUTER { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_CROSS { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_NATURAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ON { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_DAY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_WEEK { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_HOUR { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MINUTE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MONTH { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_QUARTER { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MICROSECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_YEAR { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DAY_HOUR { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DAY_MICROSECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DAY_MINUTE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DAY_SECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_HOUR_MICROSECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_HOUR_MINUTE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_HOUR_SECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MINUTE_MICROSECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MINUTE_SECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SECOND_MICROSECOND { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_YEAR_MONTH { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_OUTFILE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DUMPFILE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_FOR { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_UPDATE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SHARE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_OF { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_NOWAIT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SKIP { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LOCKED { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_TRANSACTION { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ISOLATION { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LEVEL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_READ { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_WRITE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_COMMITTED { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_UNCOMMITTED { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_REPEATABLE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SERIALIZABLE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MATCH { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_AGAINST { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_BOOLEAN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MODE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_IN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_FIELDS { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_TERMINATED { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_OPTIONALLY { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ENCLOSED { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_ESCAPED { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LINES { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_STARTING { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_COUNT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SUM { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_AVG { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MAX { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_MIN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_SOUNDS { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LIKE { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }

    | TOKEN_GLOBAL_VAR_PREFIX { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_PERSIST_ONLY_VAR_PREFIX { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DOUBLESPECIAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SPECIAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_IDENTIFIER { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | '*' { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | '+' { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | '-' { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | '/' { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | '%' { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | '^' { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_NEG { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
//  | TOKEN_LPAREN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
//  | TOKEN_RPAREN { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_SEMICOLON { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_DOT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_COMMA { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_EQUAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LESS { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_GREATER { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_LESS_EQUAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_GREATER_EQUAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_NOT_EQUAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_BITWISE_LSHIFT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_BITWISE_RSHIFT { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_NUMBER_LITERAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    | TOKEN_STRING_LITERAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_UNKNOWN, "PLACEHOLDER"); }
    ;

subquery_parts_args:
    subquery_part { $$ = $1; }
    | subquery_parts_args subquery_part { $$ = $2; }
    ;

subquery_part:
    any_token { $$ = $1; }
    | TOKEN_LPAREN subquery_parts_args TOKEN_RPAREN { $$ = $2; }
    // For functions like 'count()'; TODO: Can be improved
    | TOKEN_LPAREN TOKEN_RPAREN { $$ = nullptr; }
    ;

select_subexpr:
    TOKEN_LPAREN TOKEN_SELECT subquery_parts_args TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SELECT_RAW_SUBQUERY, "SELECT_SUBEXPR");
        $$->val_init_pos = @1.first_column;
        $$->val_end_pos = @4.last_column;
    }
    ;

simple_bit_expr:
    // Identifiers / Variables: Exprs can be other vars
    qualified_identifier_node                                   { $$ = $1; } // TODO: Can be improved
    | user_variable                                             { $$ = $1; }
    // Qualified system vars - @@GLOBAL.var, @@SESSION.var, @@var etc.
    | system_variable_qualified                                 { $$ = $1; }
    // Not qualified system vars - E.g: 'sql_mode'
    | system_variable_unqualified                               { $$ = $1; }
    // Functions
    | aggregate_function_call                                   { $$ = $1; }
    | function_call_placeholder                                 { $$ = $1; }
    // Parenthesized expression
    | TOKEN_LPAREN expr TOKEN_RPAREN                            { $$ = $2; }
    // Literal values
    | literal_or_null
    // Single operator bit_expr
    | '+' simple_bit_expr %prec TOKEN_NEG {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "+");
        $$->addChild($2);
    }
    | '-' simple_bit_expr %prec TOKEN_NEG {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "-");
        $$->addChild($2);
    }
    | TOKEN_NEG simple_bit_expr %prec TOKEN_NEG {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "~");
        $$->addChild($2);
    }
    // Select subexpressions -- NOTE: Simplified for now for SET statements
    | select_subexpr                                            { $$ = $1; }
    // MATCH-AGAINST
    | TOKEN_MATCH identifier_list_args TOKEN_AGAINST TOKEN_LPAREN bit_expr opt_search_modifier TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_EXPR, "MATCH_AGAINST");
        // identifier list (columns)
        $$->addChild($2);
        // bit_expr (string search)
        $$->addChild($5);
        // search modifier
        $$->addChild($6);
    }
    ;

// Update system_variable_qualified to include PERSIST and PERSIST_ONLY prefixes
system_variable_qualified:
    TOKEN_DOUBLESPECIAL identifier_node { // @@var (SESSION scope by DEFAULT or based on var type)
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        delete $2;
    }
    | TOKEN_GLOBAL_VAR_PREFIX identifier_node { // @@GLOBAL.var
        MySQLParser::AstNode* scope_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "GLOBAL");
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild(scope_node);
        delete $2;
    }
    | TOKEN_SESSION_VAR_PREFIX identifier_node { // @@SESSION.var or @@LOCAL.var
        MySQLParser::AstNode* scope_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "SESSION");
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild(scope_node);
        delete $2;
    }
    | TOKEN_PERSIST_VAR_PREFIX identifier_node { // @@PERSIST.var
        MySQLParser::AstNode* scope_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "PERSIST");
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild(scope_node);
        delete $2;
    }
    | TOKEN_PERSIST_ONLY_VAR_PREFIX identifier_node { // @@PERSIST_ONLY.var
        MySQLParser::AstNode* scope_node = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "PERSIST_ONLY");
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild(scope_node);
        delete $2;
    }
    ;

expression_list:
    expr {
        // Consider a more specific NodeType like NODE_EXPRESSION_LIST
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_EXPR, "expr_list_wrapper");
        $$->addChild($1);
    }
    | expression_list TOKEN_COMMA expr {
        $1->addChild($3);
        $$ = $1;
    }
    ;

variable_to_set:
    user_variable { $$ = $1; }
    | system_variable_qualified { $$ = $1; }
    | variable_scope system_variable_unqualified {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild($1);
        // $2's value copied, node itself deleted
        delete $2;
    }
    | system_variable_unqualified {
        // No explicit scope means session or implied context
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SYSTEM_VARIABLE, $1->value);
        // $1's value copied, node itself deleted
        delete $1;
    }
    ;

user_variable:
    TOKEN_SPECIAL TOKEN_IDENTIFIER {
        // TODO: Should we consider *always* moving the value?
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_USER_VARIABLE, std::move(*$2));
        // $2's value moved, node itself deleted
        delete $2;
    }
    ;

system_variable_unqualified:
    identifier_node { $$ = $1; } // Returns identifier_node
    ;

variable_scope:
    TOKEN_GLOBAL        { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "GLOBAL"); }
    | TOKEN_SESSION       { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "SESSION"); }
    | TOKEN_PERSIST       { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "PERSIST"); }
    | TOKEN_PERSIST_ONLY  { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_VARIABLE_SCOPE, "PERSIST_ONLY"); }
    ;

/* --- Common Optional Clauses --- */
opt_where_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_WHERE expr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_WHERE_CLAUSE);
        $$->addChild($2);
    }
    ;

opt_having_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_HAVING expr {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_HAVING_CLAUSE);
        $$->addChild($2);
    }
    ;

opt_order_by_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_ORDER TOKEN_BY order_by_list { $$ = $3; } // $3 is NODE_ORDER_BY_CLAUSE
    ;

order_by_list:
    order_by_item {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ORDER_BY_CLAUSE);
        $$->addChild($1);
    }
    | order_by_list TOKEN_COMMA order_by_item {
        $1->addChild($3);
        $$ = $1;
    }
    ;

order_by_item:
    expr opt_asc_desc {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ORDER_BY_ITEM);
        $$->addChild($1);

        if ($2) { // opt_asc_desc (ASC/DESC keyword node)
            $$->addChild($2);
        }
    }
    ;

opt_asc_desc:
    /* empty */       { $$ = nullptr; }
    | TOKEN_ASC       { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "ASC"); }
    | TOKEN_DESC      { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "DESC"); }
    ;

opt_limit_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_LIMIT number_literal_node { // LIMIT count
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LIMIT_CLAUSE);
        $$->addChild($2); // count
    }
    | TOKEN_LIMIT number_literal_node TOKEN_COMMA number_literal_node { // LIMIT offset, count
        // Standard SQL: LIMIT row_count OFFSET offset_row
        // MySQL legacy: LIMIT offset_row, row_count
        // Current AST: first child is offset, second is count for this form.
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LIMIT_CLAUSE, "OFFSET_COUNT");
        $$->addChild($2); // offset
        $$->addChild($4); // count
    }
    // MySQL also supports LIMIT count OFFSET offset, but that's more complex to add here without ambiguity
    // For now, sticking to the common forms.
    | TOKEN_LIMIT number_literal_node TOKEN_OFFSET number_literal_node { // LIMIT count OFFSET offset
        // Standard SQL: LIMIT row_count OFFSET offset_row
        // Current AST: first child is count, second is offset for this form.
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_LIMIT_CLAUSE, "COUNT_OFFSET");
        $$->addChild($2); // count
        $$->addChild($4); // offset
    }
    ;

opt_group_by_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_GROUP TOKEN_BY group_by_list { $$ = $3; } // $3 is NODE_GROUP_BY_CLAUSE
    ;

group_by_list:
    grouping_element {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_GROUP_BY_CLAUSE); // Main clause node
        $$->addChild($1); // grouping_element
    }
    | group_by_list TOKEN_COMMA grouping_element {
        $1->addChild($3); // Add to existing group_by_clause node
        $$ = $1;
    }
    ;

grouping_element:
    expr { $$ = $1; } // Can be column, expression
    // Add WITH ROLLUP if needed
    ;

/* --- SHOW Statement Rules --- */
show_statement:
    TOKEN_SHOW show_full_modifier show_what optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SHOW_STATEMENT);
        if ($2) $$->addChild($2); // show_full_modifier (can be null)
        $$->addChild($3);       // show_what
    }
    ;

show_full_modifier:
    /* empty */     { $$ = nullptr; }
    | TOKEN_FULL    { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SHOW_OPTION_FULL, "FULL"); }
    ;

show_what:
    TOKEN_DATABASES {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SHOW_TARGET_DATABASES, "DATABASES");
    }
    | TOKEN_FIELDS show_from_or_in table_specification {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_SHOW_OPTION_FIELDS, "FIELDS");
        // $2 is show_from_or_in which is just a keyword placeholder for now, so not adding as child.
        $$->addChild($3); // table_specification
    }
    // Add other SHOW variants as needed, e.g., SHOW TABLES, SHOW STATUS, etc.
    // Example: SHOW TABLES [FROM db_name] [LIKE 'pattern' | WHERE expr]
    // SHOW CREATE TABLE table_name
    ;

show_from_or_in:
    TOKEN_FROM { $$ = nullptr; /* keyword only, not stored as node */ }
    | TOKEN_IN   { $$ = nullptr; /* keyword only, not stored as node */ }
    ;

table_specification: // Used by SHOW FIELDS FROM table_name
    table_name_spec { // Re-use table_name_spec which handles identifier_node and qualified_identifier_node
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_TABLE_SPECIFICATION);
        $$->addChild($1); // table_name_spec node which contains table_name or schema.table_name
    }
    ;


/* --- BEGIN/COMMIT Statement Rules --- */
begin_statement:
    TOKEN_BEGIN optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_BEGIN_STATEMENT, "BEGIN");
    }
    ;
commit_statement:
    TOKEN_COMMIT optional_semicolon {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_COMMIT_STATEMENT, "COMMIT");
    }
    ;

opt_with_query_expansion:
    /* empty */ { $$ = nullptr; }
    | TOKEN_WITH TOKEN_QUERY TOKEN_EXPANSION {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "WITH QUERY EXPANSION");
    }

opt_search_modifier:
    TOKEN_IN TOKEN_BOOLEAN TOKEN_MODE {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "IN BOOLEAN MODE");
    }
    | TOKEN_IN TOKEN_NATURAL TOKEN_LANGUAGE TOKEN_MODE opt_with_query_expansion {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_KEYWORD, "IN NATURAL LANGUAGE MODE");
    }
    | opt_with_query_expansion
    ;

aggregate_function_call:
    TOKEN_COUNT TOKEN_LPAREN TOKEN_ASTERISK TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "COUNT");
        $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_ASTERISK, "*"));
    }
    | TOKEN_COUNT TOKEN_LPAREN expr TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "COUNT");
        $$->addChild($3);
    }
    | TOKEN_SUM TOKEN_LPAREN expr TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "SUM");
        $$->addChild($3);
    }
    | TOKEN_AVG TOKEN_LPAREN expr TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "AVG");
        $$->addChild($3);
    }
    | TOKEN_MAX TOKEN_LPAREN expr TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "MAX");
        $$->addChild($3);
    }
    | TOKEN_MIN TOKEN_LPAREN expr TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "MIN");
        $$->addChild($3);
    }
    ;

comparison_operator:
    TOKEN_EQUAL         { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "="); }
    | TOKEN_LESS          { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "<"); }
    | TOKEN_GREATER       { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, ">"); }
    | TOKEN_LESS_EQUAL    { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "<="); }
    | TOKEN_GREATER_EQUAL { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, ">="); }
    | TOKEN_NOT_EQUAL     { $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_OPERATOR, "!="); }
    ;

function_call_placeholder:
    identifier_node TOKEN_LPAREN opt_expr_list TOKEN_RPAREN {
        $$ = new MySQLParser::AstNode(MySQLParser::NodeType::NODE_EXPR, "FUNC_CALL:" + $1->value); // Placeholder type
        // Consider NODE_FUNCTION_CALL in mysql_ast.h
        $$->addChild($1);
        if ($3) {
            $$->addChild($3); // $3 is expression_list or null
        } else {
            // Add an empty list node for functions with no arguments, e.g., NOW()
            // This ensures the function call node always has a child for arguments, even if empty.
            $$->addChild(new MySQLParser::AstNode(MySQLParser::NodeType::NODE_EXPR, "empty_arg_list_wrapper"));
        }
    }
    ;

opt_expr_list:
    /* empty */ { $$ = nullptr; }
    | expression_list { $$ = $1; }
    ;

%%
/* C code to follow grammar rules */
