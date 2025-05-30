#include "mysql_parser/mysql_parser.h" // Ensure this path is correct for your include setup
#include <iostream>
#include <vector>
#include <string>

#include <fstream>
#include <string.h>
#include <nlohmann/json.hpp>

namespace MysqlParser {

/**
 * @brief Reconstructs an expression string from an AST node.
 *
 * This function recursively traverses the AST starting from the given 'node'
 * and builds a string representation of the expression. Expression tokens
 * are separated by exactly one space.
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
        case NodeType::NODE_STRING_LITERAL:       // e.g., "'hello'", value includes quotes
        case NodeType::NODE_NUMBER_LITERAL:       // e.g., "123", "3.14"
        case NodeType::NODE_BOOLEAN_LITERAL:      // e.g., "TRUE", "FALSE"
        case NodeType::NODE_NULL_LITERAL:         // e.g., "NULL"
        case NodeType::NODE_TIMESTAMP:            // e.g., "'2024-05-30 10:00:00'"
        case NodeType::NODE_IDENTIFIER:           // e.g., "column_name"
        case NodeType::NODE_SYSTEM_VARIABLE:      // e.g., "@@global.var_name"
        case NodeType::NODE_ASTERISK:             // e.g., "*"
        case NodeType::NODE_VALUE_LITERAL:        // For keywords used as values, e.g. 'ON' in some contexts
        case NodeType::NODE_LEFT_SHIFT_OPERATOR:  // Value is "<<"
        case NodeType::NODE_RIGHT_SHIFT_OPERATOR: // Value is ">>"
        case NodeType::NODE_KEYWORD:              // For keywords like "DISTINCT" if part of an expression
            result = node->value;
            break;

        case NodeType::NODE_USER_VARIABLE:        // e.g., "@my_var"
        {
            result = "@" + node->value;
        }
        break;
        case NodeType::NODE_OPERATOR:             // For operators like "+", "-", "=", "OR", "AND" if parsed as a single token node
        {
            if (node->children.size() > 1) {
                result = build_str_expr(node->children[0]) + " " + node->value + " " + build_str_expr(node->children[1]);
            } else {
                result = node->value + " " + build_str_expr(node->children[0]);
            }
        }
        break;
        case NodeType::NODE_SET_STATEMENT:
        {
            result = "SET"; // The SET keyword

            // Expecting one child: a NODE_EXPR that represents the list of variable assignments.
            if (node->children.size() == 1) {
                const AstNode* assignments_list_expr_node = node->children[0];
                // We expect this child to be the NODE_EXPR (set_var_assignments_list)
                // Calling build_str_expr on this node should yield the string for all assignments.
                std::string assignments_list_str = build_str_expr(assignments_list_expr_node);

                if (!assignments_list_str.empty()) {
                    result += " " + assignments_list_str;
                }
            } else if (node->children.empty()) {
                // Just "SET" if there are no assignments (e.g. "SET;" - though typically invalid without assignments)
            } else {
                // If there are multiple children directly under NODE_SET_STATEMENT,
                // this contradicts the structure you described (single NODE_EXPR child).
                // This fallback will join them with spaces, which won't produce commas.
                std::string fallback_str = "";
                for (const auto* child : node->children) {
                    std::string child_s = build_str_expr(child);
                    if (!child_s.empty()) {
                        if (!fallback_str.empty()) {
                            fallback_str += " ";
                        }
                        fallback_str += child_s;
                    }
                }
                if (!fallback_str.empty()) {
                    result += " " + fallback_str;
                }
            }
        }
        break;

        case NodeType::NODE_VARIABLE_ASSIGNMENT: // Handles individual 'variable = value' assignments
            // Expected children:
            // child[0]: variable name (e.g., NODE_IDENTIFIER, NODE_SYSTEM_VARIABLE)
            // child[1]: value (e.g., NODE_STRING_LITERAL, NODE_NUMBER_LITERAL, NODE_IDENTIFIER for keywords like OFF)
            if (node->children.size() == 2) {
                std::string var_name_str = build_str_expr(node->children[0]); // Reconstruct variable name
                std::string value_str = build_str_expr(node->children[1]);   // Reconstruct value (which is an expression)

                if (!var_name_str.empty()) {
                    // Standard SET syntax often has no spaces around '=' for variable assignments
                    result = var_name_str + " = " + value_str;
                }
            } else if (node->children.size() == 1) {
                // This might occur if the parser handles `SET variable` (implying a default or boolean toggle)
                // or if `variable = DEFAULT` is parsed with DEFAULT not as a separate value node.
                // For robust reconstruction, the AST should clearly distinguish these.
                // Assuming for now it's just the variable name, which is incomplete for `var=val`.
                result = build_str_expr(node->children[0]) + " = "; // Append '=' expecting a value, or adapt if semantics differ
            }
            // The node->value of NODE_VARIABLE_ASSIGNMENT itself is not used for the '=' here;
            // the structure and type imply the assignment operator.
            break;

        case NodeType::NODE_QUALIFIED_IDENTIFIER: // e.g., table.column or schema.table.column
            if (!node->children.empty()) {
                // Children are the parts of the identifier (e.g., schema, table, column nodes)
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

        case NodeType::NODE_SIMPLE_EXPRESSION: // A specific kind of expression
        // Simplified existing generic NODE_EXPR logic for when it has children
        case NodeType::NODE_SET_OPTION_VALUE_LIST: {
            // If the NODE_EXPR has children:
            std::string temp_expr_parts = "";

            for (const auto* child_of_expr : node->children) { // These are the NODE_VARIABLE_ASSIGNMENTs
                std::string part_str = build_str_expr(child_of_expr);
                if (!part_str.empty()) {
                    if (!temp_expr_parts.empty()) {
                        temp_expr_parts += ", "; // <<< This space is the current behavior
                    }
                    temp_expr_parts += part_str;
                }
            }
            result = temp_expr_parts;
            break;
        }

        case NodeType::NODE_COMPARISON_EXPRESSION: // e.g., column = 5, name LIKE '%pattern%'
            // Expects 3 children: left_operand, operator_node, right_operand
            if (node->children.size() == 3) {
                std::string left = build_str_expr(node->children[0]);
                std::string op = build_str_expr(node->children[1]); // Operator node itself
                std::string right = build_str_expr(node->children[2]);

                if (!left.empty() && !op.empty() && !right.empty()) {
                    result = left + " " + op + " " + right;
                } else { // Fallback for incomplete structures (should ideally not happen with a valid AST)
                    if (!left.empty()) result += left;
                    if (!op.empty()) { if (!result.empty()) result += " "; result += op; }
                    if (!right.empty()) { if (!result.empty()) result += " "; result += right; }
                }
            } else { // Fallback if not 3 children, process as a generic expression list
                std::string temp_expr_parts = "";
                for (const auto* child : node->children) {
                    std::string child_expr = build_str_expr(child);
                    if (!child_expr.empty()) {
                        if (!temp_expr_parts.empty()) temp_expr_parts += " ";
                        temp_expr_parts += child_expr;
                    }
                }
                result = temp_expr_parts;
            }
            break;

        case NodeType::NODE_LOGICAL_AND_EXPRESSION: // For multiple expressions joined by AND
        { // Scope for temp_result
            std::string temp_result = "";
            for (size_t i = 0; i < node->children.size(); ++i) {
                std::string child_expr = build_str_expr(node->children[i]);
                if (!child_expr.empty()) {
                    if (!temp_result.empty()) {
                        temp_result += " AND "; // "AND" with spaces
                    }
                    temp_result += child_expr;
                }
            }
            result = temp_result;
        }
            break;
        // Note: Similar logic would apply for NODE_LOGICAL_OR_EXPRESSION if it existed.
        // If OR/XOR use NODE_EXPR with an operator child, NODE_EXPR handles it.

        case NodeType::NODE_IS_NULL_EXPRESSION: // expr IS NULL
            if (!node->children.empty()) { // Expects one child (the expression)
                result = build_str_expr(node->children[0]) + " IS NULL";
            } else if (!node->value.empty()) { // Fallback if value holds the operand (unlikely for this structure)
                result = node->value + " IS NULL";
            }
            break;

        case NodeType::NODE_IS_NOT_NULL_EXPRESSION: // expr IS NOT NULL
            if (!node->children.empty()) { // Expects one child
                result = build_str_expr(node->children[0]) + " IS NOT NULL";
            } else if (!node->value.empty()) { // Fallback
                result = node->value + " IS NOT NULL";
            }
            break;

        case NodeType::NODE_AGGREGATE_FUNCTION_CALL: {// e.g., COUNT(*), SUM(column), AVG(DISTINCT col)
            if (node->children.size()) {
                result += node->value + "(" + build_str_expr(node->children[0]) + ")";
            } else {
                result += node->value + "()";
            }
            break;
        }
        case NodeType::NODE_INTERVAL_EXPRESSION: { // e.g., INTERVAL '1' DAY or INTERVAL expression unit
            // Assumes node->value might be "INTERVAL" or children provide full structure.
            // A common structure: "INTERVAL" expr unit
            result = "INTERVAL"; // The keyword
            // Child 0: the value expression (e.g., '1', 1+1)
            // Child 1: the unit (e.g., DAY, HOUR_MINUTE)
            if (!node->children.empty()) {
                 std::string val_expr = build_str_expr(node->children[0]);
                 if (!val_expr.empty()) {
                    result += " " + val_expr;
                 }
                if (node->children.size() > 1) {
                    std::string unit_expr = build_str_expr(node->children[1]);
                    if(!unit_expr.empty()){
                        result += " " + unit_expr;
                    }
                }
            } else if (!node->value.empty() && node->value != "INTERVAL") {
                // If node->value contains something like "1 DAY" and no children
                result += " " + node->value;
            }
            break;
        }
        case NodeType::NODE_SUBQUERY: { // Represents (SELECT ...) or a parenthesized expression like (a + b)
            // This node type explicitly adds parentheses around its content.
            result = "(";
            std::string sub_content = "";
            // Usually, a subquery node has one child: the actual statement or the inner expression.
            for (size_t i = 0; i < node->children.size(); ++i) {
                std::string child_expr = build_str_expr(node->children[i]);
                 if (!child_expr.empty()) {
                    if (!sub_content.empty()) {
                        // If multiple children form a list inside (), separate them by space.
                        // This depends on how the parser builds subquery children.
                        sub_content += " ";
                    }
                    sub_content += child_expr;
                }
            }
            result += sub_content;
            result += ")";
            break;
        }

        // Default case for other node types:
        // Attempt to construct from value and/or children if any.
        // This is a general fallback; ideally, all expression-relevant types are explicitly handled.
        default: {
            if (!node->value.empty()) {
                result = node->value;
            }
            if (!node->children.empty()) {
                std::string children_expr_str = "";
                for (const auto* child : node->children) {
                    std::string child_str = build_str_expr(child);
                    if (!child_str.empty()) {
                        if (!children_expr_str.empty()) {
                            children_expr_str += " ";
                        }
                        children_expr_str += child_str;
                    }
                }
                if (!result.empty() && !children_expr_str.empty()) {
                    result += " "; // Space if node has a value AND children contribute
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
    MysqlParser::Parser parser; // Using the MysqlParser namespace

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

        parser.clearErrors();
        std::unique_ptr<MysqlParser::AstNode> ast = parser.parse(query);

        if (ast) {
            std::cout << "Parsing successful!" << std::endl;
            MysqlParser::print_ast(ast.get());
            std::cout << "QueryFromAST - " << build_str_expr(ast.get()) << "\n";
        } else {
            std::cout << "Parsing failed." << std::endl;
            const auto& errors = parser.getErrors();
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
