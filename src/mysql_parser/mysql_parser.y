%code requires {
    namespace MysqlParser {
      struct AstNode;
    }
    #include <string>
}

%{
#include "mysql_parser/mysql_parser.h"
#include "mysql_parser/mysql_ast.h"

union MYSQL_YYSTYPE;
int mysql_yylex(union MYSQL_YYSTYPE* yylval_param, yyscan_t yyscanner, MysqlParser::Parser* parser_context);
%}

%define api.prefix {mysql_yy}
%define api.pure full
%define parse.error verbose

%lex-param { yyscan_t yyscanner }
%lex-param { MysqlParser::Parser* parser_context }

%parse-param { yyscan_t yyscanner }
%parse-param { MysqlParser::Parser* parser_context }

%union {
    std::string* str_val;
    MysqlParser::AstNode* node_val;
}

// Tokens
%token TOKEN_SELECT TOKEN_FROM TOKEN_INSERT TOKEN_INTO TOKEN_VALUES
%token TOKEN_LPAREN TOKEN_RPAREN TOKEN_SEMICOLON TOKEN_ASTERISK
%token TOKEN_PLUS TOKEN_MINUS TOKEN_DIVIDE
%token TOKEN_SET TOKEN_NAMES TOKEN_CHARACTER TOKEN_GLOBAL TOKEN_SESSION TOKEN_PERSIST TOKEN_PERSIST_ONLY
%token TOKEN_DOT TOKEN_DEFAULT TOKEN_COLLATE TOKEN_COMMA
%token TOKEN_SPECIAL TOKEN_DOUBLESPECIAL
%token TOKEN_GLOBAL_VAR_PREFIX TOKEN_SESSION_VAR_PREFIX TOKEN_PERSIST_VAR_PREFIX

%token TOKEN_DELETE TOKEN_LOW_PRIORITY TOKEN_QUICK TOKEN_IGNORE_SYM
%token TOKEN_USING TOKEN_ORDER TOKEN_BY TOKEN_LIMIT TOKEN_ASC TOKEN_DESC TOKEN_WHERE
%token TOKEN_AS TOKEN_DISTINCT TOKEN_GROUP TOKEN_ALL TOKEN_HAVING TOKEN_AND

%token TOKEN_JOIN TOKEN_INNER TOKEN_LEFT TOKEN_RIGHT TOKEN_FULL TOKEN_OUTER TOKEN_CROSS TOKEN_NATURAL TOKEN_ON

%token TOKEN_EQUAL TOKEN_LESS TOKEN_GREATER TOKEN_LESS_EQUAL TOKEN_GREATER_EQUAL TOKEN_NOT_EQUAL

%token TOKEN_OUTFILE TOKEN_DUMPFILE TOKEN_FOR TOKEN_UPDATE TOKEN_SHARE TOKEN_OF
%token TOKEN_NOWAIT TOKEN_SKIP TOKEN_LOCKED
%token TOKEN_FIELDS TOKEN_TERMINATED TOKEN_OPTIONALLY TOKEN_ENCLOSED TOKEN_ESCAPED
%token TOKEN_LINES TOKEN_STARTING

%token TOKEN_COUNT TOKEN_SUM TOKEN_AVG TOKEN_MAX TOKEN_MIN

%token TOKEN_TRANSACTION TOKEN_ISOLATION TOKEN_LEVEL
%token TOKEN_READ TOKEN_WRITE // READ WRITE for transaction access mode
%token TOKEN_COMMITTED TOKEN_UNCOMMITTED TOKEN_SERIALIZABLE TOKEN_REPEATABLE // Isolation levels

%token TOKEN_MATCH TOKEN_AGAINST TOKEN_BOOLEAN TOKEN_MODE

%token TOKEN_IN // For IN BOOLEAN MODE, and potentially IN operator later
%token TOKEN_SHOW TOKEN_DATABASES /* Added for SHOW DATABASES */
/* TOKEN_FIELDS is already declared */
/* TOKEN_FULL is already declared */
%token TOKEN_BEGIN TOKEN_COMMIT /* Added for BEGIN/COMMIT */
%token TOKEN_IS TOKEN_NULL_KEYWORD TOKEN_NOT /* Added for IS NULL / IS NOT NULL */


%token <str_val> TOKEN_QUIT
%token <str_val> TOKEN_IDENTIFIER
%token <str_val> TOKEN_STRING_LITERAL
%token <str_val> TOKEN_NUMBER_LITERAL

// Types
%type <node_val> statement simple_statement command_statement select_statement insert_statement delete_statement
%type <node_val> identifier_node string_literal_node number_literal_node value_for_insert optional_semicolon show_statement begin_statement commit_statement
%type <node_val> set_statement set_option_list set_option set_transaction_statement transaction_characteristic_list transaction_characteristic isolation_level_spec
%type <node_val> variable_to_set user_variable system_variable_unqualified system_variable_qualified
%type <node_val> variable_scope
%type <node_val> expression_placeholder simple_expression aggregate_function_call function_call_placeholder match_against_expression opt_search_modifier
%type <node_val> opt_expression_placeholder_list // expression_placeholder_list is removed as it's replaced by expression_list for args
%type <node_val> set_names_stmt set_charset_stmt charset_name_or_default collation_name_choice

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
%type <node_val> identifier_list_for_using

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
%left TOKEN_OR
%left TOKEN_AND
%right TOKEN_NOT // For logical NOT

%left TOKEN_EQUAL TOKEN_LESS TOKEN_GREATER TOKEN_LESS_EQUAL TOKEN_GREATER_EQUAL TOKEN_NOT_EQUAL TOKEN_IS // Added TOKEN_IS

%left TOKEN_PLUS TOKEN_MINUS
%left TOKEN_ASTERISK TOKEN_DIVIDE

// For Unary Minus (Query 4)
%right UMINUS

%left TOKEN_ON TOKEN_USING
%left TOKEN_NATURAL
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

/*
// Original query_list (can be commented out or removed if no longer used as a start symbol by any entry point)
query_list:
    // empty  { if (parser_context) parser_context->internal_set_ast(nullptr); }
    | query_list statement { // This structure is for parsing multiple statements from one yyparse call.
                           // If parser.parse() is meant to handle one statement string at a time,
                           // this rule is not suitable as the main start symbol.
                           }
    ;
*/

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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COMMAND, std::move(*$1));
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IDENTIFIER, std::move(val));
    }
    ;

qualified_identifier_node: // For table.column or schema.table
    identifier_node TOKEN_DOT identifier_node {
        std::string qualified_name = $1->value + "." + $3->value;
        // Create a generic node; specific handling might be needed based on context
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_QUALIFIED_IDENTIFIER, std::move(qualified_name));
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
                    // MySQL also allows escaping % and _ for LIKE contexts, but that's usually handled by the expression evaluation, not lexing/parsing of the literal itself.
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
            } else if (quote_char != 0 && val_content[i] == quote_char && (i + 1 < val_content.length() && val_content[i+1] == quote_char) ) { // Handle '' or "" for literal quote (SQL Standard)
                unescaped_val += quote_char;
                i++; // Skip the second quote
            }
            else {
                unescaped_val += val_content[i];
            }
        }
        if(escaping) unescaped_val+='\\'; // if string ends with a single backslash

        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_STRING_LITERAL, std::move(unescaped_val));
    }
    ;

number_literal_node:
    TOKEN_NUMBER_LITERAL {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_NUMBER_LITERAL, std::move(*$1));
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_STATEMENT);
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_OPTIONS)); // Ensure options node exists
        $$->addChild($3); // select_item_list
        if ($4) $$->addChild($4); // opt_into_clause
        if ($5) $$->addChild($5); // opt_from_clause
        if ($6) $$->addChild($6); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
        if ($7) $$->addChild($7); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_GROUP_BY_CLAUSE));
        if ($8) $$->addChild($8); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_HAVING_CLAUSE));
        if ($9) $$->addChild($9); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_CLAUSE));
        if ($10) $$->addChild($10); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE));
        if ($11) $$->addChild($11); // opt_locking_clause_list
    }
    ;

opt_alias:
    /* empty */ { $$ = nullptr; }
    | TOKEN_AS identifier_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ALIAS, $2->value);
        delete $2;
    }
    | identifier_node { // Implicit AS
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ALIAS, $1->value);
        delete $1;
    }
    ;

select_item:
    identifier_node TOKEN_DOT TOKEN_ASTERISK { // table.*
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_ITEM);
        MysqlParser::AstNode* table_asterisk = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ASTERISK, $1->value + ".*");
        table_asterisk->addChild($1); // Store the table identifier
        $$->addChild(table_asterisk);
    }
    | TOKEN_ASTERISK { // *
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_ITEM);
        $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ASTERISK, "*"));
    }
    | expression_placeholder opt_alias {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_ITEM);
        $$->addChild($1);
        if ($2) {
            $$->addChild($2);
        }
    }
    ;

select_item_list:
    select_item {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_ITEM_LIST);
        $$->addChild($1);
    }
    | select_item_list TOKEN_COMMA select_item {
        $1->addChild($3);
        $$ = $1;
    }
    ;

select_option_item:
    TOKEN_DISTINCT { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "DISTINCT"); }
    | TOKEN_ALL { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "ALL"); }
    // Add other select options like SQL_CALC_FOUND_ROWS if needed
    ;

opt_select_options:
    /* empty */ { $$ = nullptr; }
    | select_option_item opt_select_options { // Allows multiple options like ALL DISTINCT (though not valid SQL, grammar might allow)
        MysqlParser::AstNode* options_node;
        if ($2 == nullptr) { // First option in the list
            options_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_OPTIONS);
            options_node->addChild($1);
        } else { // Subsequent options
            options_node = $2;
            // Prepend the new option to maintain order or just add
            std::vector<MysqlParser::AstNode*> temp_children = options_node->children;
            options_node->children.clear();
            options_node->addChild($1); // Add new option first
            for (MysqlParser::AstNode* child : temp_children) {
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INTO_OUTFILE);
        $$->addChild($3); // string_literal_node for filename
        if ($4) $$->addChild($4); // opt_into_outfile_options_list
    }
    | TOKEN_INTO TOKEN_DUMPFILE string_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INTO_DUMPFILE);
        $$->addChild($3); // string_literal_node for filename
    }
    | TOKEN_INTO user_var_list {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INTO_VAR_LIST);
        $$->addChild($2); // user_var_list
    }
    ;

user_var_list:
    user_variable {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COLUMN_LIST); // Re-use for list of user variables
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FILE_OPTIONS);
        MysqlParser::AstNode* charset_opt_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_CHARSET_OPTION);
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FILE_OPTIONS); // Wrapper for single/multiple options
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FIELDS_OPTIONS_CLAUSE);
        $$->addChild($2); // field_option_outfile_list
    }
    ;

field_option_outfile_list:
    field_option_outfile {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FILE_OPTIONS); // Re-using for list of field options
        $$->addChild($1);
    }
    | field_option_outfile_list field_option_outfile {
        $1->addChild($2);
        $$ = $1;
    }
    ;

field_option_outfile:
    TOKEN_TERMINATED TOKEN_BY string_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FIELDS_TERMINATED_BY);
        $$->addChild($3);
    }
    | TOKEN_OPTIONALLY TOKEN_ENCLOSED TOKEN_BY string_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FIELDS_OPTIONALLY_ENCLOSED_BY);
        $$->addChild($4);
    }
    | TOKEN_ENCLOSED TOKEN_BY string_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FIELDS_ENCLOSED_BY);
        $$->addChild($3);
    }
    | TOKEN_ESCAPED TOKEN_BY string_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FIELDS_ESCAPED_BY);
        $$->addChild($3);
    }
    ;

lines_options_clause:
    TOKEN_LINES line_option_outfile_list {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LINES_OPTIONS_CLAUSE);
        $$->addChild($2); // line_option_outfile_list
    }
    ;

line_option_outfile_list:
    line_option_outfile {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FILE_OPTIONS); // Re-using for list of line options
        $$->addChild($1);
    }
    | line_option_outfile_list line_option_outfile {
        $1->addChild($2);
        $$ = $1;
    }
    ;

line_option_outfile:
    TOKEN_STARTING TOKEN_BY string_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LINES_STARTING_BY);
        $$->addChild($3);
    }
    | TOKEN_TERMINATED TOKEN_BY string_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LINES_TERMINATED_BY);
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCKING_CLAUSE_LIST);
        $$->addChild($1);
    }
    | locking_clause_list locking_clause {
        $1->addChild($2);
        $$ = $1;
    }
    ;

locking_clause:
    TOKEN_FOR lock_strength opt_lock_table_list opt_lock_option {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCKING_CLAUSE);
        $$->addChild($2); // lock_strength
        if ($3) $$->addChild($3); // opt_lock_table_list
        if ($4) $$->addChild($4); // opt_lock_option
    }
    ;

lock_strength:
    TOKEN_UPDATE { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_STRENGTH, "UPDATE"); }
    | TOKEN_SHARE  { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_STRENGTH, "SHARE"); }
    ;

opt_lock_table_list:
    /* empty */ { $$ = nullptr; }
    | TOKEN_OF table_name_list_for_delete { // Re-use table_name_list_for_delete for simplicity
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_TABLE_LIST);
        $$->addChild($2); // table_name_list_for_delete
    }
    ;

opt_lock_option:
    /* empty */ { $$ = nullptr; }
    | TOKEN_NOWAIT { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_OPTION, "NOWAIT"); }
    | TOKEN_SKIP TOKEN_LOCKED { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_OPTION, "SKIP LOCKED"); }
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FROM_CLAUSE);
        $$->addChild($2);
    }
    ;

table_reference:
    table_reference_inner { $$ = $1; }
    | joined_table        { $$ = $1; }
    ;

table_reference_inner:
    table_name_spec opt_alias {
        MysqlParser::AstNode* ref_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_TABLE_REFERENCE);
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
        MysqlParser::AstNode* sub_ref_item = $2;
        if ($4) {
            MysqlParser::AstNode* aliased_sub_ref = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_TABLE_REFERENCE);
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SUBQUERY);
        $$->addChild($2); // select_statement
    }
    ;

derived_table:
    subquery { // Typically requires an alias, handled by table_reference_inner
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DERIVED_TABLE);
        $$->addChild($1); // subquery
    }
    ;

// Handles NATURAL [INNER|LEFT|RIGHT [OUTER]] JOIN
join_type_natural_spec:
    TOKEN_NATURAL opt_join_type {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_TYPE_NATURAL_SPEC);
        $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "NATURAL"));
        if ($2) { // opt_join_type (e.g. LEFT node)
            $$->addChild($2);
        } else { // Pure NATURAL implies INNER
            $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "INNER"));
        }
    }
    ;

opt_join_type: // For non-NATURAL joins: INNER, LEFT [OUTER], RIGHT [OUTER], FULL [OUTER]
    /* empty */ { $$ = nullptr; } // Implicitly INNER if only TOKEN_JOIN is used
    | TOKEN_INNER               { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "INNER"); }
    | TOKEN_LEFT                { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "LEFT"); }
    | TOKEN_LEFT TOKEN_OUTER    { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "LEFT OUTER"); }
    | TOKEN_RIGHT               { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "RIGHT"); }
    | TOKEN_RIGHT TOKEN_OUTER   { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "RIGHT OUTER"); }
    | TOKEN_FULL                { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "FULL"); }
    | TOKEN_FULL TOKEN_OUTER    { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "FULL OUTER"); }
    ;


joined_table:
    table_reference join_type_natural_spec TOKEN_JOIN table_reference_inner opt_join_condition {
        // table_ref NATURAL [INNER|LEFT|RIGHT] JOIN table_ref_inner [ON|USING]
        // $2 is NODE_JOIN_TYPE_NATURAL_SPEC
        MysqlParser::AstNode* join_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CLAUSE);
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
        MysqlParser::AstNode* join_node;
        std::string join_desc;
        MysqlParser::AstNode* explicit_join_type = $2; // opt_join_type node or nullptr

        if (explicit_join_type) {
            join_desc = explicit_join_type->value + " JOIN";
        } else { // Implicit INNER JOIN
            join_desc = "INNER JOIN"; // Default for JOIN without explicit type
            explicit_join_type = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "INNER"); // Create node for AST
        }
        join_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CLAUSE, join_desc);
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CLAUSE, "CROSS JOIN");
        $$->addChild($1); // Left table
        $$->addChild($4); // Right table
    }
    | table_reference TOKEN_COMMA table_reference_inner { // Old style comma join implies CROSS JOIN
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CLAUSE, "CROSS JOIN");
        $$->addChild($1); // Left table
        $$->addChild($3); // Right table
    }
    ;

opt_join_condition:
    /* empty */ { $$ = nullptr; }
    | join_condition { $$ = $1; }
    ;

join_condition:
    TOKEN_ON expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CONDITION_ON);
        $$->addChild($2); // expression_placeholder
    }
    | TOKEN_USING TOKEN_LPAREN identifier_list_for_using TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CONDITION_USING);
        $$->addChild($3); // identifier_list_for_using
    }
    ;

identifier_list_for_using:
    identifier_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COLUMN_LIST); // Re-use for list of identifiers
        $$->addChild($1);
    }
    | identifier_list_for_using TOKEN_COMMA identifier_node {
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COLUMN_LIST);
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

expression_list:
    expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "expr_list_wrapper");
        $$->addChild($1);
    }
    | expression_list TOKEN_COMMA expression_placeholder {
        $1->addChild($3);
        $$ = $1;
    }
    ;

value_row:
    TOKEN_LPAREN expression_list TOKEN_RPAREN { $$ = $2; }
    ;

value_row_list:
    value_row {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "value_row_list_wrapper");
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "VALUES_CLAUSE"); // Placeholder type
        // Consider creating NODE_VALUES_CLAUSE in mysql_ast.h
        $$->addChild($2); // Add the value_row_list_wrapper
    }
    ;

insert_statement:
    TOKEN_INSERT TOKEN_INTO table_name_spec opt_column_list values_clause optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INSERT_STATEMENT);
        $$->addChild($3); // table_name_spec
        if ($4) $$->addChild($4); // opt_column_list (which is column_list_item_list or null)
        else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COLUMN_LIST)); // Add empty list if not present
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_STATEMENT);
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($4); // table_name_spec
        if ($5) $$->addChild($5); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
        if ($6) $$->addChild($6); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_CLAUSE));
        if ($7) $$->addChild($7); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE));
    }
    | TOKEN_DELETE opt_delete_options table_name_list_for_delete TOKEN_FROM table_reference // table_reference for multi-table
                 opt_where_clause optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_STATEMENT, "MULTI_TABLE_TARGET_LIST_FROM");
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($3); // table_name_list_for_delete
        MysqlParser::AstNode* from_wrapper = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FROM_CLAUSE);
        from_wrapper->addChild($5); // table_reference
        $$->addChild(from_wrapper);
        if ($6) $$->addChild($6); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
    }
    | TOKEN_DELETE opt_delete_options TOKEN_FROM table_name_list_for_delete TOKEN_USING table_reference // table_reference for multi-table
                 opt_where_clause optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_STATEMENT, "MULTI_TABLE_FROM_USING");
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($4); // table_name_list_for_delete
        MysqlParser::AstNode* using_wrapper = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_USING_CLAUSE);
        using_wrapper->addChild($6); // table_reference
        $$->addChild(using_wrapper);
        if ($7) $$->addChild($7); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
    }
    ;

opt_delete_options:
    /* empty */ { $$ = nullptr; }
    | delete_option_item_list { $$ = $1; }
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

delete_option:
    TOKEN_LOW_PRIORITY { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "LOW_PRIORITY"); }
    | TOKEN_QUICK      { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "QUICK"); }
    | TOKEN_IGNORE_SYM { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "IGNORE"); }
    ;

table_name_list_for_delete: // List of tables to delete FROM in multi-table delete
    table_name_spec { // Use table_name_spec here
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_TABLE_NAME_LIST);
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
    TOKEN_READ TOKEN_COMMITTED         { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "READ COMMITTED"); }
    | TOKEN_READ TOKEN_UNCOMMITTED     { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "READ UNCOMMITTED"); }
    | TOKEN_REPEATABLE TOKEN_READ      { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "REPEATABLE READ"); }
    | TOKEN_SERIALIZABLE              { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "SERIALIZABLE"); }
    ;

transaction_characteristic:
    TOKEN_ISOLATION TOKEN_LEVEL isolation_level_spec {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "ISOLATION_LEVEL"); // Placeholder type
        // Consider NODE_TXN_ISOLATION_LEVEL in mysql_ast.h
        $$->addChild($3); // isolation_level_spec
    }
    // Add other characteristics like READ WRITE / READ ONLY if needed
    // | TOKEN_READ TOKEN_WRITE { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "READ WRITE"); }
    // | TOKEN_READ TOKEN_ONLY { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "READ ONLY"); } // Assuming TOKEN_ONLY exists
    ;

transaction_characteristic_list:
    transaction_characteristic {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "TXN_CHAR_LIST"); // Placeholder type
        // Consider NODE_TXN_CHARACTERISTIC_LIST in mysql_ast.h
        $$->addChild($1);
    }
    | transaction_characteristic_list TOKEN_COMMA transaction_characteristic {
        $1->addChild($3);
        $$ = $1;
    }
    ;

set_transaction_statement:
    TOKEN_SESSION TOKEN_TRANSACTION transaction_characteristic_list {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SET_STATEMENT, "SET_SESSION_TRANSACTION"); // Or more specific type
        // Consider NODE_SET_TRANSACTION_STATEMENT in mysql_ast.h
        $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "SESSION")); // Add scope
        $$->addChild($3); // transaction_characteristic_list
    }
    | TOKEN_GLOBAL TOKEN_TRANSACTION transaction_characteristic_list {
         $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SET_STATEMENT, "SET_GLOBAL_TRANSACTION");
         $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "GLOBAL"));
         $$->addChild($3);
    }
    | TOKEN_TRANSACTION transaction_characteristic_list { // Default to SESSION
         $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SET_STATEMENT, "SET_TRANSACTION");
         // Could add an implicit SESSION scope node if desired for AST consistency
         $$->addChild($2); // transaction_characteristic_list
    }
    ;

set_statement:
    TOKEN_SET set_names_stmt optional_semicolon { $$ = $2; }
    | TOKEN_SET set_charset_stmt optional_semicolon { $$ = $2; }
    | TOKEN_SET set_option_list optional_semicolon {
        // $2 is the "set_var_assignments" node.
        // The set_statement node should probably wrap this for consistency.
        MysqlParser::AstNode* set_vars_stmt = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SET_STATEMENT, "SET_VARIABLES");
        set_vars_stmt->addChild($2);
        $$ = set_vars_stmt;
    }
    | TOKEN_SET set_transaction_statement optional_semicolon { $$ = $2; }
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

charset_name_or_default:
    string_literal_node { $$ = $1; }
    | TOKEN_DEFAULT     { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "DEFAULT"); }
    | identifier_node   { $$ = $1; }
    ;

collation_name_choice:
    string_literal_node { $$ = $1; }
    | identifier_node   { $$ = $1; }
    ;

set_option_list: // List of variable assignments: @a=1, GLOBAL b=2
    set_option {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "set_var_assignments_list"); // Placeholder type
        // Consider NODE_VARIABLE_ASSIGNMENT_LIST in mysql_ast.h
        $$->addChild($1); // $1 is NODE_VARIABLE_ASSIGNMENT
    }
    | set_option_list TOKEN_COMMA set_option {
        $1->addChild($3); // Add next NODE_VARIABLE_ASSIGNMENT to the list
        $$ = $1;
    }
    ;

set_option:
    variable_to_set TOKEN_EQUAL expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_ASSIGNMENT);
        $$->addChild($1);
        $$->addChild($3);
    }
    ;

variable_to_set:
    user_variable { $$ = $1; }
    | system_variable_qualified { $$ = $1; }
    | variable_scope system_variable_unqualified {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value); // $2 is identifier_node
        $$->addChild($1); // scope node
        delete $2; // $2's value copied, node itself deleted
    }
    | system_variable_unqualified {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $1->value); // $1 is identifier_node
        // No explicit scope means session or implied context. AST can reflect this.
        delete $1; // $1's value copied, node itself deleted
    }
    ;

user_variable:
    TOKEN_SPECIAL TOKEN_IDENTIFIER {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_USER_VARIABLE, std::move(*$2)); // $2 is str_val
        delete $2;
    }
    ;

system_variable_unqualified:
    identifier_node { $$ = $1; } // Returns identifier_node
    ;

system_variable_qualified:
    TOKEN_DOUBLESPECIAL identifier_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        // Could add an implicit scope node if desired, e.g. "SESSION" if @@var implies session
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

variable_scope:
    TOKEN_GLOBAL        { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "GLOBAL"); }
    | TOKEN_SESSION       { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "SESSION"); }
    | TOKEN_PERSIST       { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "PERSIST"); }
    | TOKEN_PERSIST_ONLY  { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_VARIABLE_SCOPE, "PERSIST_ONLY"); }
    ;

/* --- Common Optional Clauses --- */
opt_where_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_WHERE expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE);
        $$->addChild($2);
    }
    ;

opt_having_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_HAVING expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_HAVING_CLAUSE);
        $$->addChild($2);
    }
    ;

opt_order_by_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_ORDER TOKEN_BY order_by_list { $$ = $3; } // $3 is NODE_ORDER_BY_CLAUSE
    ;

order_by_list:
    order_by_item {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_CLAUSE); // This is the main clause node
        $$->addChild($1); // order_by_item
    }
    | order_by_list TOKEN_COMMA order_by_item {
        $1->addChild($3); // Add to existing order_by_clause node
        $$ = $1;
    }
    ;

order_by_item:
    expression_placeholder opt_asc_desc {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_ITEM);
        $$->addChild($1); // expression_placeholder
        if ($2) { // opt_asc_desc (ASC/DESC keyword node)
            $$->addChild($2);
        }
    }
    ;

opt_asc_desc:
    /* empty */       { $$ = nullptr; }
    | TOKEN_ASC       { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "ASC"); }
    | TOKEN_DESC      { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "DESC"); }
    ;

opt_limit_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_LIMIT number_literal_node { // LIMIT count
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE);
        $$->addChild($2); // count
    }
    | TOKEN_LIMIT number_literal_node TOKEN_COMMA number_literal_node { // LIMIT offset, count
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE);
        $$->addChild($2); // offset
        $$->addChild($4); // count
    }
    // MySQL also supports LIMIT count OFFSET offset, but that's more complex to add here without ambiguity
    // For now, sticking to the common forms.
    ;

opt_group_by_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_GROUP TOKEN_BY group_by_list { $$ = $3; } // $3 is NODE_GROUP_BY_CLAUSE
    ;

group_by_list:
    grouping_element {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_GROUP_BY_CLAUSE); // Main clause node
        $$->addChild($1); // grouping_element
    }
    | group_by_list TOKEN_COMMA grouping_element {
        $1->addChild($3); // Add to existing group_by_clause node
        $$ = $1;
    }
    ;

grouping_element:
    expression_placeholder { $$ = $1; } // Can be column, expression
    // Add WITH ROLLUP if needed
    ;

/* --- SHOW Statement Rules --- */
show_statement:
    TOKEN_SHOW show_full_modifier show_what optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SHOW_STATEMENT);
        if ($2) $$->addChild($2); // show_full_modifier (can be null)
        $$->addChild($3);       // show_what
    }
    ;

show_full_modifier:
    /* empty */     { $$ = nullptr; }
    | TOKEN_FULL    { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SHOW_OPTION_FULL, "FULL"); }
    ;

show_what:
    TOKEN_DATABASES {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SHOW_TARGET_DATABASES, "DATABASES");
    }
    | TOKEN_FIELDS show_from_or_in table_specification {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SHOW_OPTION_FIELDS, "FIELDS");
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_TABLE_SPECIFICATION);
        $$->addChild($1); // table_name_spec node which contains table_name or schema.table_name
    }
    ;


/* --- BEGIN/COMMIT Statement Rules --- */
begin_statement:
    TOKEN_BEGIN optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_BEGIN_STATEMENT, "BEGIN");
    }
    ;
commit_statement:
    TOKEN_COMMIT optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COMMIT_STATEMENT, "COMMIT");
    }
    ;

/* --- Expression related rules --- */
expression_placeholder:
    simple_expression { $$ = $1; }
    | expression_placeholder TOKEN_AND expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOGICAL_AND_EXPRESSION);
        $$->addChild($1);
        $$->addChild($3);
    }
    | expression_placeholder comparison_operator expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COMPARISON_EXPRESSION, $2->value);
        delete $2;
        $$->addChild($1);
        $$->addChild($3);
    }
    | expression_placeholder TOKEN_IS TOKEN_NULL_KEYWORD { // Covers `expr IS NULL`
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IS_NULL_EXPRESSION);
        $$->addChild($1); // The expression part
    }
    | expression_placeholder TOKEN_IS TOKEN_NOT TOKEN_NULL_KEYWORD { // Covers `expr IS NOT NULL`
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_IS_NOT_NULL_EXPRESSION);
        $$->addChild($1); // The expression part
    }
    | match_against_expression { $$ = $1; }
    ;

simple_expression:
    string_literal_node     { $$ = $1; }
    | number_literal_node   { $$ = $1; }
    | qualified_identifier_node { $$ = $1; }
    | identifier_node       { $$ = $1; }
    | user_variable         { $$ = $1; }
    | system_variable_qualified { $$ = $1; }
    | TOKEN_DEFAULT         { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "DEFAULT"); }
    | aggregate_function_call { $$ = $1; }
    | function_call_placeholder {$$ = $1; }
    | TOKEN_LPAREN expression_placeholder TOKEN_RPAREN { $$ = $2; } // Important for `(expr IS NOT NULL)`
    | simple_expression TOKEN_PLUS simple_expression {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "+");
        $$->addChild($1); $$->addChild($3);
    }
    | simple_expression TOKEN_MINUS simple_expression {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "-");
        $$->addChild($1); $$->addChild($3);
    }
    | simple_expression TOKEN_ASTERISK simple_expression {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "*");
        $$->addChild($1); $$->addChild($3);
    }
    | simple_expression TOKEN_DIVIDE simple_expression {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "/");
        $$->addChild($1); $$->addChild($3);
    }
    | TOKEN_MINUS simple_expression %prec UMINUS {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "-");
        $$->addChild($2); // Child is the expression being negated
    }
    ;

opt_search_modifier:
    /* empty */ { $$ = nullptr; }
    | TOKEN_IN TOKEN_BOOLEAN TOKEN_MODE { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "IN BOOLEAN MODE"); }
    ;

match_against_expression:
    TOKEN_MATCH TOKEN_LPAREN expression_list TOKEN_RPAREN TOKEN_AGAINST TOKEN_LPAREN expression_placeholder opt_search_modifier TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "MATCH_AGAINST"); // Placeholder type
        // Consider NODE_MATCH_AGAINST_EXPRESSION in mysql_ast.h
        $$->addChild($3); // expression_list (columns)
        $$->addChild($7); // expression_placeholder (search string)
        if ($8) $$->addChild($8); // opt_search_modifier
    }
    ;

aggregate_function_call:
    TOKEN_COUNT TOKEN_LPAREN TOKEN_ASTERISK TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "COUNT");
        $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ASTERISK, "*"));
    }
    | TOKEN_COUNT TOKEN_LPAREN expression_placeholder TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "COUNT");
        $$->addChild($3);
    }
    | TOKEN_SUM TOKEN_LPAREN expression_placeholder TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "SUM");
        $$->addChild($3);
    }
    | TOKEN_AVG TOKEN_LPAREN expression_placeholder TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "AVG");
        $$->addChild($3);
    }
    | TOKEN_MAX TOKEN_LPAREN expression_placeholder TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "MAX");
        $$->addChild($3);
    }
    | TOKEN_MIN TOKEN_LPAREN expression_placeholder TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_AGGREGATE_FUNCTION_CALL, "MIN");
        $$->addChild($3);
    }
    ;

comparison_operator:
    TOKEN_EQUAL         { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "="); }
    | TOKEN_LESS          { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "<"); }
    | TOKEN_GREATER       { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, ">"); }
    | TOKEN_LESS_EQUAL    { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "<="); }
    | TOKEN_GREATER_EQUAL { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, ">="); }
    | TOKEN_NOT_EQUAL     { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "!="); }
    ;

function_call_placeholder:
    identifier_node TOKEN_LPAREN opt_expression_placeholder_list TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "FUNC_CALL:" + $1->value); // Placeholder type
        // Consider NODE_FUNCTION_CALL in mysql_ast.h
        $$->addChild($1);
        if ($3) {
            $$->addChild($3); // $3 is expression_list or null
        } else {
            // Add an empty list node for functions with no arguments, e.g., NOW()
            // This ensures the function call node always has a child for arguments, even if empty.
            $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "empty_arg_list_wrapper"));
        }
    }
    ;

opt_expression_placeholder_list:
    /* empty */ { $$ = nullptr; }
    | expression_list { $$ = $1; }
    ;

%%
/* C code to follow grammar rules */

// void mysql_yyerror(yyscan_t yyscanner, MysqlParser::Parser* parser_context, const char* msg) {
//    if (parser_context) {
//        parser_context->internal_add_error(msg);
//    } else {
//        fprintf(stderr, "Error: %s\n", msg);
//    }
// }
// The default yyerror or the one provided by %define parse.error verbose should be sufficient.
// If you need custom error formatting or location tracking, you'd define mysql_yyerror here.

