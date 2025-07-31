#include "mysql_parser/mysql_parser.h" // Ensure this path is correct for your include setup
#include <iostream>
#include <vector>
#include <string>

#include <fstream>
#include <string.h>
#include <nlohmann/json.hpp>

namespace MySQLParser {

/**
 * @brief Reconstructs an expression string from an AST node.
 *
 * This function recursively traverses the AST starting from the given 'node'
 * and builds a string representation of the expression. Expression tokens
 * are separated by exactly one space unless context dictates otherwise (e.g., commas).
 *
 * @param node A pointer to the AstNode representing the root of the expression (or sub-expression).
 * @return std::string The reconstructed expression string.
 */
inline std::string build_str_expr(const AstNode* node) {
    if (!node) {
        return "";
    }
    std::string result = "";

    switch (node->type) {
        // Literals & Simple Identifiers: These nodes directly provide their string representation.
        case NodeType::NODE_STRING_LITERAL:       // e.g., "'hello'", value includes quotes. Parser must populate node->value.
        case NodeType::NODE_NUMBER_LITERAL:       // e.g., "123", "3.14"
        case NodeType::NODE_BOOLEAN_LITERAL:      // e.g., "TRUE", "FALSE"
        case NodeType::NODE_NULL_LITERAL:         // e.g., "NULL"
        case NodeType::NODE_TIMESTAMP:            // e.g., "'2024-05-30 10:00:00'"
        case NodeType::NODE_IDENTIFIER:           // e.g., "column_name" or function name if not part of FUNC_CALL structure
        case NodeType::NODE_ASTERISK:             // e.g., "*"
        case NodeType::NODE_VALUE_LITERAL:        // For keywords used as values, e.g. 'ON' in some contexts
        case NodeType::NODE_LEFT_SHIFT_OPERATOR:  // Value is "<<"
        case NodeType::NODE_RIGHT_SHIFT_OPERATOR: // Value is ">>"
        case NodeType::NODE_KEYWORD:              // For keywords like "DISTINCT" if part of an expression
            result = node->value;
            break;

        case NodeType::NODE_USER_VARIABLE:        // e.g., "@my_var"
            // The parser should ensure node->value contains the variable name without '@'
            // Or if it includes '@', this logic might need adjustment based on parser behavior.
            // Assuming node->value is "my_var"
            result = "@" + node->value;
            break;

        case NodeType::NODE_SYSTEM_VARIABLE:      // e.g., "@@global.var_name", "session var_name", "var_name"
            // node->value is the base variable name, e.g., "max_connections", "sort_buffer_size", "@@var", "var"
            // Children might contain VAR_SCOPE
            if (!node->children.empty() && node->children[0]->type == NodeType::NODE_VARIABLE_SCOPE) {
                // Case: Explicit scope child present (e.g., from "GLOBAL var" or "@@GLOBAL.var")
                // AST typically has node->value as base name (e.g., "sort_buffer_size")
                // and child VAR_SCOPE has scope value (e.g., "GLOBAL")
                const AstNode* scope_node = node->children[0];
                // Reconstruct as @@SCOPE.VAR_NAME for consistency.
                // This turns "GLOBAL sort_buffer_size" into "@@GLOBAL.sort_buffer_size".
                // "@@GLOBAL.sort_buffer_size" (if parsed to this AST structure) also becomes "@@GLOBAL.sort_buffer_size".
                result = "@@" + scope_node->value + "." + node->value;
            } else {
                // Case: No explicit scope child.
                // node->value could be "@@var_name" (e.g. "@@sql_select_limit")
                // or just "var_name" (e.g. "sql_select_limit", implying session scope usually).
                // These should be used as is from node->value.
                result = node->value;
            }
            break;

        case NodeType::NODE_OPERATOR:             // For operators like "+", "-", "=", "OR", "AND" if parsed as a single token node
        {
            if (node->children.size() > 1) { // Binary operator
                result = build_str_expr(node->children[0]) + " " + node->value + " " + build_str_expr(node->children[1]);
            } else if (node->children.size() == 1) { // Unary operator (assuming prefix, e.g. NOT expr, -expr)
                result = node->value + " " + build_str_expr(node->children[0]);
            } else { // Operator token itself, e.g. if it's part of a comparison expression like `node->children[1]` in `NODE_COMPARISON_EXPRESSION`
                 result = node->value;
            }
        }
        break;

        case NodeType::NODE_SET_STATEMENT:
        {
            result = "SET"; // The SET keyword
            if (!node->children.empty()) {
                // Expecting one child: typically a NODE_SET_OPTION_VALUE_LIST or a single NODE_VARIABLE_ASSIGNMENT
                std::string assignments_list_str = build_str_expr(node->children[0]);
                if (!assignments_list_str.empty()) {
                    result += " " + assignments_list_str;
                }
            }
            // If no children, it's just "SET", though usually invalid without assignments.
        }
        break;

        case NodeType::NODE_VARIABLE_ASSIGNMENT: // Handles individual 'variable = value' assignments
            // Expected children:
            // child[0]: variable name (e.g., NODE_IDENTIFIER, NODE_SYSTEM_VARIABLE, NODE_USER_VARIABLE)
            // child[1]: value (e.g., NODE_STRING_LITERAL, NODE_NUMBER_LITERAL, NODE_EXPR)
            if (node->children.size() == 2) {
                std::string var_name_str = build_str_expr(node->children[0]);
                std::string value_str = build_str_expr(node->children[1]);
                result = var_name_str + " = " + value_str;
            } else if (node->children.size() == 1) { // Potentially `SET variable` (e.g. boolean toggle if parser supports)
                result = build_str_expr(node->children[0]) + " = "; // Incomplete, but reflects AST
            }
            break;

        case NodeType::NODE_QUALIFIED_IDENTIFIER: // e.g., table.column or schema.table.column
            if (!node->children.empty()) {
                std::string qualified_name_parts = "";
                for (size_t i = 0; i < node->children.size(); ++i) {
                    qualified_name_parts += build_str_expr(node->children[i]);
                    if (i < node->children.size() - 1) {
                        qualified_name_parts += "."; // No spaces around the dot
                    }
                }
                result = qualified_name_parts;
            } else {
                result = node->value; // Fallback if the value itself contains the full qualified name
            }
            break;

        // For comma-separated lists like variable assignments in SET, or function arguments if parser uses these node types
        case NodeType::NODE_SIMPLE_EXPRESSION:
        case NodeType::NODE_SET_OPTION_VALUE_LIST: {
            std::string temp_expr_parts = "";
            for (const auto* child_item : node->children) {
                std::string part_str = build_str_expr(child_item);
                if (!part_str.empty()) {
                    if (!temp_expr_parts.empty()) {
                        temp_expr_parts += ", "; // Comma and space separator
                    }
                    temp_expr_parts += part_str;
                }
            }
            result = temp_expr_parts;
            break;
        }
        
        case NodeType::NODE_EXPR: // Generic expression, potentially a function call or other complex expression
            // Check for known patterns within NODE_EXPR, like function calls based on node->value
            // Example AST for NOW(): Type: EXPR, Value: 'FUNC_CALL:NOW'
            //                          Child 0: Type: IDENTIFIER, Value: 'NOW'
            //                          Child 1: Type: EXPR, Value: 'empty_arg_list_wrapper'
            if (node->value.rfind("FUNC_CALL:", 0) == 0 && // Check if node->value indicates a function call structure
                node->children.size() >= 1 && node->children[0]->type == NodeType::NODE_IDENTIFIER) {
                // Handle FUNC_CALL pattern
                std::string func_name_str = node->children[0]->value; // Function name from IDENTIFIER child
                std::string args_str = "";

                if (node->children.size() > 1) {
                    const AstNode* args_list_node = node->children[1];
                    // Check if it's the specific "empty_arg_list_wrapper"
                    if (args_list_node->type == NodeType::NODE_EXPR && args_list_node->value == "empty_arg_list_wrapper") {
                        // args_str remains empty, resulting in func_name()
                    } else {
                        // Recursively call build_str_expr for the arguments node.
                        // This relies on the args_list_node's own handler to format correctly
                        // (e.g., with commas if it's a NODE_SIMPLE_EXPRESSION or NODE_SET_OPTION_VALUE_LIST).
                        args_str = build_str_expr(args_list_node);
                    }
                }
                result = func_name_str + "(" + args_str + ")";
            } else {
                // Generic handling for other NODE_EXPR types (not matching FUNC_CALL pattern)
                // This logic is similar to the original 'default' case for expressions.
                if (!node->value.empty()) { // If the EXPR node itself has a value (e.g., an operator)
                    result = node->value;
                }

                if (!node->children.empty()) {
                    std::string children_expr_str = "";
                    for (const auto* child : node->children) {
                        std::string child_str = build_str_expr(child);
                        if (!child_str.empty()) {
                            if (!children_expr_str.empty()) {
                                children_expr_str += " "; // Default to space separation for generic expr children
                            }
                            children_expr_str += child_str;
                        }
                    }
                    if (!result.empty() && !children_expr_str.empty()) {
                        // Avoid double space if result ends with '(' or child starts with ')' or is empty
                        if (!result.empty() && result.back() != '(' && 
                            !children_expr_str.empty() && children_expr_str.front() != ')') {
                             result += " ";
                        }
                    }
                    result += children_expr_str;
                }
            }
            break;

        case NodeType::NODE_COMPARISON_EXPRESSION: // e.g., column = 5, name LIKE '%pattern%'
            if (node->children.size() == 3) { // left_operand, operator_node, right_operand
                std::string left = build_str_expr(node->children[0]);
                std::string op = build_str_expr(node->children[1]); // Operator node itself (e.g. NODE_OPERATOR with value "=")
                std::string right = build_str_expr(node->children[2]);
                result = left + " " + op + " " + right;
            } else { // Fallback, join children with spaces
                goto default_children_join_logic;
            }
            break;

        case NodeType::NODE_LOGICAL_AND_EXPRESSION:
        {
            std::string temp_result = "";
            for (size_t i = 0; i < node->children.size(); ++i) {
                std::string child_expr = build_str_expr(node->children[i]);
                if (!child_expr.empty()) {
                    if (!temp_result.empty()) {
                        temp_result += " AND ";
                    }
                    temp_result += child_expr;
                }
            }
            result = temp_result;
        }
            break;
        // Note: Similar logic would apply for NODE_LOGICAL_OR_EXPRESSION, NODE_LOGICAL_XOR_EXPRESSION

        case NodeType::NODE_IS_NULL_EXPRESSION: // expr IS NULL
            if (!node->children.empty()) {
                result = build_str_expr(node->children[0]) + " IS NULL";
            } else if (!node->value.empty()) { // Fallback
                result = node->value + " IS NULL";
            }
            break;

        case NodeType::NODE_IS_NOT_NULL_EXPRESSION: // expr IS NOT NULL
            if (!node->children.empty()) {
                result = build_str_expr(node->children[0]) + " IS NOT NULL";
            } else if (!node->value.empty()) { // Fallback
                result = node->value + " IS NOT NULL";
            }
            break;

        case NodeType::NODE_AGGREGATE_FUNCTION_CALL: // e.g., COUNT(*), SUM(column), AVG(DISTINCT col)
            // node->value is the function name (e.g. "COUNT")
            // node->children[0] is the argument expression (e.g. "*", "column", "DISTINCT col")
            if (!node->children.empty()) {
                result = node->value + "(" + build_str_expr(node->children[0]) + ")";
            } else { // For functions like COUNT() if parser allows, or if value is "NOW" and it's parsed as AGGREGATE
                result = node->value + "()";
            }
            break;

        case NodeType::NODE_INTERVAL_EXPRESSION: { // e.g., INTERVAL '1' DAY or INTERVAL expression unit
            result = "INTERVAL";
            if (node->children.size() >= 1) { // Value expression
                 std::string val_expr = build_str_expr(node->children[0]);
                 if (!val_expr.empty()) {
                    result += " " + val_expr;
                 }
                if (node->children.size() >= 2) { // Unit
                    std::string unit_expr = build_str_expr(node->children[1]); // Unit is often an IDENTIFIER or KEYWORD
                    if(!unit_expr.empty()){
                        result += " " + unit_expr;
                    }
                }
            } else if (!node->value.empty() && node->value != "INTERVAL") { // Fallback if value contains "1 DAY"
                result += " " + node->value;
            }
            break;
        }
        case NodeType::NODE_SUBQUERY: { // Represents (SELECT ...) or a parenthesized expression like (a + b)
            result = "(";
            std::string sub_content = "";
            for (size_t i = 0; i < node->children.size(); ++i) { // Usually one child: the statement or inner expression
                std::string child_expr = build_str_expr(node->children[i]);
                 if (!child_expr.empty()) {
                    if (!sub_content.empty()) { // If multiple children, join with space (depends on parser structure for subquery children)
                        sub_content += " ";
                    }
                    sub_content += child_expr;
                }
            }
            result += sub_content;
            result += ")";
            break;
        }

        default: {
        default_children_join_logic: // Label for goto from incomplete comparison expr, etc.
            // Default handling: use node's value, then append space-separated children.
            // This is a general fallback.
            if (!node->value.empty()) {
                result = node->value;
            }
            if (!node->children.empty()) {
                std::string children_expr_str = "";
                for (const auto* child : node->children) {
                    std::string child_str = build_str_expr(child);
                    if (!child_str.empty()) {
                        if (!children_expr_str.empty()) {
                            children_expr_str += " "; // Default to space separation
                        }
                        children_expr_str += child_str;
                    }
                }
                if (!result.empty() && !children_expr_str.empty()) {
                     // Avoid double space if result ends with '(' or child starts with ')' or is empty
                    if (!result.empty() && result.back() != '(' && 
                        !children_expr_str.empty() && children_expr_str.front() != ')') {
                            result += " ";
                    }
                }
                result += children_expr_str;
            }
            break;
        }
    }
    return result;
}

}

std::vector<std::string> exhaustive_queries {
    "SET @my_user_variable = 123;", // 1
    "SET @my_user_variable = + 123;", // 1
    "SET @my_user_variable = - 123;", // 1
    "SET @my_user_variable = 123, @@GLOBAL.max_connections = 200;", // 2
    "SET @my_custom_var = 'Test Value';", // 3
    "SET P_param_name = 100;", // 4
    "SET my_local_variable = NOW();", // 5
    "SET GLOBAL sort_buffer_size = 512000;", // 6
    "SET @@GLOBAL.sort_buffer_size = 512000;", // 7
    "SET PERSIST max_allowed_packet = 1073741824;", // 8
    "SET @@PERSIST.max_allowed_packet = 1073741824;", // 9
    "SET PERSIST_ONLY sql_mode = 'STRICT_TRANS_TABLES';", // 10
    "SET @@PERSIST_ONLY.sql_mode = 'STRICT_TRANS_TABLES';", // 11
    "SET SESSION sql_select_limit = 100;", // 12
    "SET @@SESSION.sql_select_limit = 100;", // 13
    "SET @@sql_select_limit = 100;", // 14
    "SET sql_select_limit = 100;", // 15
    "SET @generic_var = TRUE OR FALSE;", // 16
    "SET @generic_var = TRUE XOR FALSE;", // 17
    "SET @generic_var = 1 AND 0;", // 18
    "SET @generic_var = NOT TRUE;", // 19
    "SET @generic_var = (5 > 1) IS TRUE;", // 20
    "SET @generic_var = (1 = 0) IS NOT TRUE;", // 21
    "SET @generic_var = (1 = 0) IS FALSE;", // 22
    "SET @generic_var = (5 > 1) IS NOT FALSE;", // 23
    "SET @generic_var = (NULL + 1) IS UNKNOWN;", // 24
    "SET @generic_var = (1 IS NOT NULL) IS NOT UNKNOWN;", // 25
    "SET @generic_var = (col_a < col_b);", // 26
    "SET @generic_var = (0/0) IS NULL;", // 29
    "SET @generic_var = 'hello' IS NOT NULL;", // 30
    "SET @generic_var = (1=1) = ('a' LIKE 'a%');", // 31
    "SET @generic_var = my_value > ALL (SELECT limit_value FROM active_limits WHERE group_id = 'A');", // 32
    "SET @generic_var = (5 BETWEEN 1 AND 10);", // 33
    "SET @generic_var = current_user_id IN (SELECT user_id FROM course_enrollments WHERE course_id = 789);", // 41
    "SET @generic_var = 'PROD123' NOT IN (SELECT product_sku FROM discontinued_products WHERE reason_code = 'OBSOLETE');", // 42
    "SET @generic_var = 5 IN (5);", // 43
    "SET @generic_var = 'apple' IN ('orange', 'apple', 'banana');", // 44
    "SET @generic_var = 10 NOT IN (5);", // 45
    "SET @generic_var = 'grape' NOT IN ('orange', 'apple', 'banana');", // 46
    "SET @generic_var = 'b' MEMBER OF ('[\"a\", \"b\", \"c\"]');", // 47
    "SET @generic_var = 'b' MEMBER ('[\"a\", \"b\", \"c\"]');", // 48
    "SET @generic_var = 7 BETWEEN 5 AND (5 + 5);", // 49
    "SET @generic_var = 3 NOT BETWEEN 5 AND (10 - 2);", // 50
    "SET @generic_var = 'knight' SOUNDS LIKE 'night';", // 51
    "SET @generic_var = 'banana' LIKE 'ba%';", // 52
    "SET @generic_var = 'data_value_100%' LIKE 'data\\_value\\_100\\%' ESCAPE '\\\\';", // 53
    "SET @generic_var = 'apple' NOT LIKE 'ora%';", // 54
    "SET @generic_var = 'test_string%' NOT LIKE 'prod\\_string\\%' ESCAPE '\\\\';", // 55
    "SET @generic_var = 'abcde' REGEXP '^a.c';", // 56
    "SET @generic_var = 'xyz123' NOT REGEXP '[0-9]$';", // 57
    "SET @generic_var = (100 + 200);", // 58
    "SET @generic_var = 5 | 2;", // 61
    "SET @generic_var = 5 & 2;", // 62
    "SET @generic_var = 5 << 1;", // 63
    "SET @generic_var = 10 >> 1;", // 64
    "SET @generic_var = 10.5 + 2;", // 65
    "SET @generic_var = 100 - 33;", // 66
    "SET @generic_var = NOW() + INTERVAL 1 DAY;", // 67
    "SET @generic_var = '2025-12-25' - INTERVAL 2 MONTH;", // 68
    "SET @generic_var = 7 * 6;", // 69
    "SET @generic_var = 100 / 4;", // 70
    "SET @generic_var = 10 % 3;", // 71
    "SET @generic_var = 10 DIV 3;", // 72
    "SET @generic_var = 10 MOD 3;", // 73
    "SET @generic_var = 5 ^ 2;", // 74
    "SET @generic_var = (SELECT SUM(amount) FROM sales WHERE sale_date = CURDATE());" // 75
};

std::vector<std::string> exp_failures {
    // Wrong identifier; should be a valid interval keyword
    "SET @generic_var = (SELECT '2025-12-10') - INTERVAL 2 foo;"
};

int main() {
    MySQLParser::Parser parser; // Using the MysqlParser namespace

    std::vector<std::string> set_queries = {
        // Basic User Variable Assignments
        "SET @my_user_var = 'hello world';",
        "SET @anotherVar = 12345;",
        "SET @thirdVar = `ident_value`;", // Using identifier as value
        "SET @complex_var = @@global.max_connections;", // Setting user var to sys var value (expr placeholder)

        // System Variable Assignments
        "SET global max_connections = 1000;",
        "SET session sort_buffer_size = 200000;",
        "SET GLOBAL sort_buffer_size = 400000;", // Case-insensitivity for scope
        "SET SESSION wait_timeout = 180;",
        "SET @@global.tmp_table_size = 32000000;",
        "SET @@session.net_write_timeout = 120;",
        "SET @@net_read_timeout = 60;", // Implicit SESSION scope for @@
        "SET max_allowed_packet = 64000000;", // Implicit SESSION scope for simple sysvar

        // PERSIST / PERSIST_ONLY (if supported by your current grammar for scope)
        "SET persist character_set_server = 'utf8mb4';",
        "SET persist_only innodb_buffer_pool_size = '1G';", // String literal for value

        // SET NAMES and CHARACTER SET
        "SET NAMES 'utf8mb4';",
        "SET NAMES `latin1`;",
        "SET NAMES DEFAULT;",
        "SET NAMES 'gbk' COLLATE 'gbk_chinese_ci';",
        "SET CHARACTER SET 'utf8';",
        "SET CHARACTER SET DEFAULT;",

        // Comma-separated list (testing set_option_list)
        "SET @a = 1, @b = 'two', global max_heap_table_size = 128000000;",
        "SET sql_mode = 'STRICT_TRANS_TABLES', character_set_client = 'utf8mb4';",

        // Statements without trailing semicolon (should work with optional_semicolon)
        "SET @no_semicolon = 'works'",

        // Test cases for potential errors or unsupported expressions
        "SET @myvar = some_function(1, 'a');", // 'some_function(...)' is just an identifier for expression_placeholder for now
        "SET global invalid-variable = 100;", // Invalid identifier char (if not quoted)
        "SET @unterminated_string = 'oops",
        "SET =", // Syntax error
        "SET names utf8 collate ;" // Missing collation name
    };

// Enable to verify 'set_testing-240' queries
/*
    const std::string logfile_path { "examples/set_testing-240.csv" };
    std::fstream logfile_fs {};

    printf("Openning log file   path:'%s'\n", logfile_path.c_str());
    logfile_fs.open(logfile_path, std::fstream::in | std::fstream::out);

    if (!logfile_fs.is_open() || !logfile_fs.good()) {
        const char* c_f_path { logfile_path.c_str() };
        printf("Failed to open '%s' file: { path: %s, error: %d }\n", basename(c_f_path), c_f_path, errno);
        return EXIT_FAILURE;
    }

    exhaustive_queries.clear();
    std::string next_line {};

    while (std::getline(logfile_fs, next_line)) {
        nlohmann::json j_next_line = nlohmann::json::parse(next_line);
        exhaustive_queries.push_back(j_next_line["query"]);
    }
*/

    for (const auto& query : exhaustive_queries) {
        std::cout << "------------------------------------------\n";
        std::cout << "Parsing MySQL SET query: " << query << std::endl;

        parser.clear_errors();
        std::unique_ptr<MySQLParser::AstNode> ast = parser.parse(query);

        if (ast) {
            std::cout << "Parsing successful!" << std::endl;
            MySQLParser::print_ast(ast.get());
            std::cout << "QueryFromAST - " << build_str_expr(ast.get()) << "\n";
        } else {
            std::cout << "Parsing failed." << std::endl;
            const auto& errors = parser.get_errors();

            if (errors.empty()) {
                std::cout << "  (No specific error messages, check parser logic or mysql_yyerror)" << std::endl;
            } else {
                for (const auto& error : errors) {
                    std::cout << "  Error: " << error << std::endl;
                }
            }
        }
    }
    return 0;
}
