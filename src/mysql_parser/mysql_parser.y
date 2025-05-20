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
%token TOKEN_LPAREN TOKEN_RPAREN TOKEN_SEMICOLON TOKEN_ASTERISK // ASTERISK for SELECT * and multiplication
%token TOKEN_PLUS TOKEN_MINUS TOKEN_DIVIDE // TOKEN_MULTIPLY (use ASTERISK for now)
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

%token <str_val> TOKEN_QUIT
%token <str_val> TOKEN_IDENTIFIER
%token <str_val> TOKEN_STRING_LITERAL
%token <str_val> TOKEN_NUMBER_LITERAL

// Types
%type <node_val> statement simple_statement command_statement select_statement insert_statement delete_statement
%type <node_val> identifier_node string_literal_node number_literal_node value_for_insert optional_semicolon
%type <node_val> set_statement set_option_list set_option
%type <node_val> variable_to_set user_variable system_variable_unqualified system_variable_qualified
%type <node_val> variable_scope
%type <node_val> expression_placeholder simple_expression aggregate_function_call function_call_placeholder
%type <node_val> opt_expression_placeholder_list expression_placeholder_list // Reinstated for function_call_placeholder
%type <node_val> set_names_stmt set_charset_stmt charset_name_or_default collation_name_choice

%type <node_val> opt_delete_options delete_option delete_option_item_list
%type <node_val> opt_where_clause opt_having_clause
%type <node_val> opt_order_by_clause opt_limit_clause
%type <node_val> order_by_list order_by_item opt_asc_desc
%type <node_val> table_name_list_for_delete
%type <node_val> comparison_operator
%type <node_val> qualified_identifier_node

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
%type <node_val> subquery derived_table

// Precedence
%left TOKEN_OR  // Assuming OR might be added
%left TOKEN_AND
%right TOKEN_NOT // Assuming NOT might be added

%left TOKEN_EQUAL TOKEN_LESS TOKEN_GREATER TOKEN_LESS_EQUAL TOKEN_GREATER_EQUAL TOKEN_NOT_EQUAL

%left TOKEN_PLUS TOKEN_MINUS
%left TOKEN_ASTERISK TOKEN_DIVIDE // ASTERISK for multiplication

%left TOKEN_ON TOKEN_USING
%left TOKEN_NATURAL
%left TOKEN_LEFT TOKEN_RIGHT TOKEN_FULL
%left TOKEN_INNER TOKEN_CROSS
%left TOKEN_JOIN

%right TOKEN_FOR
%left TOKEN_COMMA

%start query_list

%%

query_list:
    /* empty */ { if (parser_context) parser_context->internal_set_ast(nullptr); }
    | query_list statement { /* Managed by parser_context */ }
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
        $$->addChild($1);
        $$->addChild($3);
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
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_OPTIONS));
        $$->addChild($3);
        if ($4) $$->addChild($4);
        if ($5) $$->addChild($5);
        if ($6) $$->addChild($6); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
        if ($7) $$->addChild($7); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_GROUP_BY_CLAUSE));
        if ($8) $$->addChild($8); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_HAVING_CLAUSE));
        if ($9) $$->addChild($9); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_CLAUSE));
        if ($10) $$->addChild($10); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE));
        if ($11) $$->addChild($11);
    }
    ;

opt_alias:
    /* empty */ { $$ = nullptr; }
    | TOKEN_AS identifier_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ALIAS, $2->value);
        delete $2;
    }
    | identifier_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ALIAS, $1->value);
        delete $1;
    }
    ;

select_item:
    identifier_node TOKEN_DOT TOKEN_ASTERISK {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_ITEM);
        MysqlParser::AstNode* table_asterisk = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ASTERISK, $1->value + ".*");
        table_asterisk->addChild($1);
        $$->addChild(table_asterisk);
    }
    | TOKEN_ASTERISK {
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
    ;

opt_select_options:
    /* empty */ { $$ = nullptr; }
    | select_option_item opt_select_options {
        MysqlParser::AstNode* options_node;
        if ($2 == nullptr) {
            options_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SELECT_OPTIONS);
            options_node->addChild($1);
        } else {
            options_node = $2;
            std::vector<MysqlParser::AstNode*> temp_children = options_node->children;
            options_node->children.clear();
            options_node->addChild($1);
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
        $$->addChild($3);
        if ($4) $$->addChild($4);
    }
    | TOKEN_INTO TOKEN_DUMPFILE string_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INTO_DUMPFILE);
        $$->addChild($3);
    }
    | TOKEN_INTO user_var_list {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INTO_VAR_LIST);
        $$->addChild($2);
    }
    ;

user_var_list:
    user_variable {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COLUMN_LIST);
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
        charset_opt_node->addChild($3);
        $$->addChild(charset_opt_node);
        if($4) {
            for(auto child : $4->children) {
                $$->addChild(child);
            }
            $4->children.clear();
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FILE_OPTIONS);
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
        $$->addChild($2);
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
        $$->addChild($2);
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
        $$->addChild($2);
        if ($3) $$->addChild($3);
        if ($4) $$->addChild($4);
    }
    ;

lock_strength:
    TOKEN_UPDATE { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_STRENGTH, "UPDATE"); }
    | TOKEN_SHARE  { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_STRENGTH, "SHARE"); }
    ;

opt_lock_table_list:
    /* empty */ { $$ = nullptr; }
    | TOKEN_OF table_name_list_for_delete {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_TABLE_LIST);
        $$->addChild($2);
    }
    ;

opt_lock_option:
    /* empty */ { $$ = nullptr; }
    | TOKEN_NOWAIT { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_OPTION, "NOWAIT"); }
    | TOKEN_SKIP TOKEN_LOCKED { $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LOCK_OPTION, "SKIP LOCKED"); }
    ;

/* --- FROM Clause and JOINs --- */
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
    identifier_node opt_alias {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_TABLE_REFERENCE, $1->value);
        delete $1;
        if ($2) { $$->addChild($2); }
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
            sub_ref_item->addChild($4);
        }
        $$ = sub_ref_item;
    }
    ;

subquery:
    TOKEN_LPAREN select_statement TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SUBQUERY);
        $$->addChild($2);
    }
    ;

derived_table:
    subquery {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DERIVED_TABLE);
        $$->addChild($1);
    }
    ;

// Handles NATURAL [INNER|LEFT|RIGHT [OUTER]] JOIN
join_type_natural_spec:
    TOKEN_NATURAL opt_join_type { // opt_join_type can be INNER, LEFT, RIGHT, FULL, etc.
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_TYPE_NATURAL_SPEC);
        $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_KEYWORD, "NATURAL"));
        if ($2) {
            $$->addChild($2); // e.g. LEFT node
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
        // This handles: table_ref NATURAL [INNER|LEFT|RIGHT] JOIN table_ref_inner [ON|USING]
        // $2 is NODE_JOIN_TYPE_NATURAL_SPEC
        MysqlParser::AstNode* join_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CLAUSE, $2->children[0]->value); // "NATURAL"
        if ($2->children.size() > 1) { // Has an explicit type like LEFT
            join_node->value += " " + $2->children[1]->value; // "NATURAL LEFT"
        } else {
            // join_node->value += " INNER"; // Implicit INNER
        }
        join_node->value += " JOIN";

        join_node->addChild($1); // Left table
        join_node->addChild($2); // The natural spec node itself
        join_node->addChild($4); // Right table
        if ($5) join_node->addChild($5); // Condition (should be null for pure natural)
        $$ = join_node;
    }
    | table_reference opt_join_type TOKEN_JOIN table_reference_inner opt_join_condition {
        // This handles: table_ref [INNER|LEFT|RIGHT|FULL [OUTER]] JOIN table_ref_inner [ON|USING]
        MysqlParser::AstNode* join_node;
        std::string join_desc;
        MysqlParser::AstNode* explicit_join_type = $2;

        if (explicit_join_type) {
            join_desc = explicit_join_type->value + " JOIN";
        } else { // Implicit INNER JOIN
            join_desc = "INNER JOIN";
            explicit_join_type = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "INNER");
        }
        join_node = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CLAUSE, join_desc);
        join_node->addChild($1); // Left table
        join_node->addChild(explicit_join_type); // The type node
        join_node->addChild($4); // Right table

        if ($5) { // ON or USING condition
            join_node->addChild($5);
        } else { // No condition
            if (explicit_join_type->value == "INNER" || (explicit_join_type->value.empty() && join_desc == "INNER JOIN")) {
                join_node->value = "CROSS JOIN"; // INNER JOIN without condition is CROSS JOIN
            } else if (parser_context) {
                parser_context->internal_add_error(join_desc + " requires an ON or USING clause.");
            }
        }
        $$ = join_node;
    }
    | table_reference TOKEN_CROSS TOKEN_JOIN table_reference_inner {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CLAUSE, "CROSS JOIN");
        $$->addChild($1);
        $$->addChild($4);
    }
    | table_reference TOKEN_COMMA table_reference_inner {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CLAUSE, "CROSS JOIN");
        $$->addChild($1);
        $$->addChild($3);
    }
    ;

opt_join_condition:
    /* empty */ { $$ = nullptr; }
    | join_condition { $$ = $1; }
    ;

join_condition:
    TOKEN_ON expression_placeholder {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CONDITION_ON);
        $$->addChild($2);
    }
    | TOKEN_USING TOKEN_LPAREN identifier_list_for_using TOKEN_RPAREN {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_JOIN_CONDITION_USING);
        $$->addChild($3);
    }
    ;

identifier_list_for_using:
    identifier_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_COLUMN_LIST);
        $$->addChild($1);
    }
    | identifier_list_for_using TOKEN_COMMA identifier_node {
        $1->addChild($3);
        $$ = $1;
    }
    ;

/* --- INSERT Statement Rules --- */
insert_statement:
    TOKEN_INSERT TOKEN_INTO identifier_node TOKEN_VALUES TOKEN_LPAREN value_for_insert TOKEN_RPAREN optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_INSERT_STATEMENT);
        $$->addChild($3);
        $$->addChild($6);
    }
    ;

value_for_insert:
    string_literal_node { $$ = $1; }
    | number_literal_node { $$ = $1; }
    ;

/* --- DELETE Statement Rules --- */
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
    | TOKEN_DELETE opt_delete_options table_name_list_for_delete TOKEN_FROM table_reference
                 opt_where_clause optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_STATEMENT, "MULTI_TABLE_TARGET_LIST_FROM");
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($3);
        MysqlParser::AstNode* from_wrapper = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_FROM_CLAUSE);
        from_wrapper->addChild($5);
        $$->addChild(from_wrapper);
        if ($6) $$->addChild($6); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_WHERE_CLAUSE));
    }
    | TOKEN_DELETE opt_delete_options TOKEN_FROM table_name_list_for_delete TOKEN_USING table_reference
                 opt_where_clause optional_semicolon {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_STATEMENT, "MULTI_TABLE_FROM_USING");
        if ($2) $$->addChild($2); else $$->addChild(new MysqlParser::AstNode(MysqlParser::NodeType::NODE_DELETE_OPTIONS));
        $$->addChild($4);
        MysqlParser::AstNode* using_wrapper = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_USING_CLAUSE);
        using_wrapper->addChild($6);
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

/* --- SET Statement Rules --- */
set_statement:
    TOKEN_SET set_names_stmt optional_semicolon { $$ = $2; }
    | TOKEN_SET set_charset_stmt optional_semicolon { $$ = $2; }
    | TOKEN_SET set_option_list optional_semicolon { $$ = $2; }
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $2->value);
        $$->addChild($1);
        delete $2;
    }
    | system_variable_unqualified {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_SYSTEM_VARIABLE, $1->value);
        delete $1;
    }
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
    | TOKEN_ORDER TOKEN_BY order_by_list { $$ = $3; }
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

order_by_item:
    expression_placeholder opt_asc_desc {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_ORDER_BY_ITEM);
        $$->addChild($1);
        if ($2) {
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
    | TOKEN_LIMIT number_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE);
        $$->addChild($2);
    }
    | TOKEN_LIMIT number_literal_node TOKEN_COMMA number_literal_node {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE);
        $$->addChild($2);
        $$->addChild($4);
    }
    | TOKEN_LIMIT number_literal_node TOKEN_BY number_literal_node {
         if (parser_context) parser_context->internal_add_error("Warning: LIMIT X BY Y is non-standard. Interpreting as LIMIT Y, X (offset, count).");
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_LIMIT_CLAUSE);
        $$->addChild($4);
        $$->addChild($2);
    }
    ;

opt_group_by_clause:
    /* empty */ { $$ = nullptr; }
    | TOKEN_GROUP TOKEN_BY group_by_list { $$ = $3; }
    ;

group_by_list:
    grouping_element {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_GROUP_BY_CLAUSE);
        $$->addChild($1);
    }
    | group_by_list TOKEN_COMMA grouping_element {
        $1->addChild($3);
        $$ = $1;
    }
    ;

grouping_element:
    expression_placeholder { $$ = $1; }
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
    | function_call_placeholder {$$ = $1; } // For general functions
    | TOKEN_LPAREN expression_placeholder TOKEN_RPAREN { $$ = $2; }
    | simple_expression TOKEN_PLUS simple_expression {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "+");
        $$->addChild($1); $$->addChild($3);
    }
    | simple_expression TOKEN_MINUS simple_expression {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "-");
        $$->addChild($1); $$->addChild($3);
    }
    | simple_expression TOKEN_ASTERISK simple_expression { // Multiplication
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "*");
        $$->addChild($1); $$->addChild($3);
    }
    | simple_expression TOKEN_DIVIDE simple_expression {
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_OPERATOR, "/");
        $$->addChild($1); $$->addChild($3);
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
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "FUNC_CALL:" + $1->value);
        $$->addChild($1); // Function name
        if ($3) { // Argument list node
            $$->addChild($3);
        }
    }
    ;

opt_expression_placeholder_list:
    /* empty */ { $$ = nullptr; } // For functions with no arguments e.g. NOW()
    | expression_placeholder_list { $$ = $1; }
    ;

expression_placeholder_list:
    expression_placeholder {
        // This node will be a child of function_call_placeholder, representing the list of arguments
        $$ = new MysqlParser::AstNode(MysqlParser::NodeType::NODE_EXPRESSION_PLACEHOLDER, "arg_list_wrapper");
        $$->addChild($1); // First argument
    }
    | expression_placeholder_list TOKEN_COMMA expression_placeholder {
        $1->addChild($3); // Add next argument to the list wrapper
        $$ = $1;
    }
    ;

%%
/* C code to follow grammar rules */


