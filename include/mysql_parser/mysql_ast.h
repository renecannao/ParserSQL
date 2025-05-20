#ifndef MYSQL_PARSER_AST_H
#define MYSQL_PARSER_AST_H

#include <string>
#include <vector>
#include <iostream>
#include <algorithm> // For std::move if not implicitly included by <string> or <vector>

namespace MysqlParser {

// Enum for Abstract Syntax Tree Node Types
enum class NodeType {
    NODE_UNKNOWN,
    NODE_COMMAND,               // General command like QUIT
    NODE_SELECT_STATEMENT,
    NODE_INSERT_STATEMENT,
    NODE_DELETE_STATEMENT,
    NODE_IDENTIFIER,
    NODE_STRING_LITERAL,
    NODE_NUMBER_LITERAL,        // For numeric values
    NODE_ASTERISK,              // For '*' in SELECT
    NODE_SET_STATEMENT,
    NODE_VARIABLE_ASSIGNMENT,
    NODE_USER_VARIABLE,         // e.g., @my_var
    NODE_SYSTEM_VARIABLE,       // e.g., @@global.var
    NODE_VARIABLE_SCOPE,        // GLOBAL, SESSION, PERSIST, etc.
    NODE_EXPRESSION_PLACEHOLDER,// Placeholder for more complex expressions (and functions)
    NODE_SIMPLE_EXPRESSION,     // More specific expression type
    NODE_AGGREGATE_FUNCTION_CALL, // For COUNT, SUM, AVG etc.
    NODE_SET_NAMES,
    NODE_SET_CHARSET,
    NODE_DELETE_OPTIONS,        // LOW_PRIORITY, QUICK, IGNORE for DELETE
    NODE_TABLE_NAME_LIST,       // For multi-table DELETE or other lists of tables
    NODE_FROM_CLAUSE,
    NODE_USING_CLAUSE,          // For JOIN ... USING (...)
    NODE_WHERE_CLAUSE,
    NODE_HAVING_CLAUSE,         // Added for HAVING
    NODE_ORDER_BY_CLAUSE,
    NODE_ORDER_BY_ITEM,
    NODE_LIMIT_CLAUSE,
    NODE_COMPARISON_EXPRESSION, // e.g., col = 5
    NODE_LOGICAL_AND_EXPRESSION, // For AND operator
    NODE_OPERATOR,              // e.g., =, <, +, -, JOIN type strings
    NODE_QUALIFIED_IDENTIFIER,  // e.g., table.column

    // For SELECT specific parts
    NODE_SELECT_OPTIONS,        // DISTINCT, SQL_CALC_FOUND_ROWS etc.
    NODE_SELECT_ITEM_LIST,      // List of expressions/columns in SELECT
    NODE_SELECT_ITEM,           // A single item in the SELECT list
    NODE_ALIAS,                 // For 'AS alias_name'
    NODE_TABLE_REFERENCE,       // Reference to a table (name, derived, join result)
    NODE_GROUP_BY_CLAUSE,
    NODE_GROUPING_ELEMENT,      // Item in GROUP BY

    // For JOIN clauses
    NODE_JOIN_CLAUSE,           // Represents a join operation (e.g., t1 JOIN t2)
    NODE_JOIN_TYPE_NATURAL_SPEC,// For 'NATURAL [LEFT|RIGHT|INNER] JOIN' specifier
    NODE_JOIN_CONDITION_ON,     // ON <expr>
    NODE_JOIN_CONDITION_USING,  // USING (col1, col2)
    NODE_COLUMN_LIST,           // For USING (col_list) or INTO (var_list)

    // Nodes for INTO, LOCKING, DERIVED TABLES
    NODE_INTO_CLAUSE,           // Wrapper for INTO ... variants
    NODE_INTO_VAR_LIST,         // INTO @var1, @var2
    NODE_INTO_OUTFILE,          // INTO OUTFILE 'filename' [options]
    NODE_INTO_DUMPFILE,         // INTO DUMPFILE 'filename'
    NODE_LOCKING_CLAUSE_LIST,   // Wrapper for one or more locking clauses
    NODE_LOCKING_CLAUSE,        // FOR UPDATE | FOR SHARE
    NODE_LOCK_STRENGTH,         // Stores "UPDATE" or "SHARE"
    NODE_LOCK_TABLE_LIST,       // Optional 'OF table_list' for locking
    NODE_LOCK_OPTION,           // Optional 'NOWAIT' or 'SKIP LOCKED'
    NODE_DERIVED_TABLE,         // Represents (SELECT ...) AS alias
    NODE_SUBQUERY,              // The (SELECT ...) part of a derived table or sub-expression

    // For INTO OUTFILE options
    NODE_FILE_OPTIONS,          // Wrapper for all file format options
    NODE_FIELDS_OPTIONS_CLAUSE, // Wrapper for FIELDS related options
    NODE_LINES_OPTIONS_CLAUSE,  // Wrapper for LINES related options
    NODE_FIELDS_TERMINATED_BY,
    NODE_FIELDS_ENCLOSED_BY,
    NODE_FIELDS_OPTIONALLY_ENCLOSED_BY,
    NODE_FIELDS_ESCAPED_BY,
    NODE_LINES_STARTING_BY,
    NODE_LINES_TERMINATED_BY,
    NODE_CHARSET_OPTION,        // For CHARACTER SET 'name' in OUTFILE

    NODE_KEYWORD                // For storing keywords like ALL, DISTINCT (as value) in some contexts
};

// Structure for an AST Node
struct AstNode {
    NodeType type;
    std::string value; // Stores identifier name, literal value, operator type, etc.
    std::vector<AstNode*> children;

    // Constructor
    AstNode(NodeType t, const std::string& val = "") : type(t), value(val) {}
    // Move constructor for value
    AstNode(NodeType t, std::string&& val) : type(t), value(std::move(val)) {}

    // Destructor to clean up children
    ~AstNode() {
        for (AstNode* child : children) {
            delete child;
        }
        children.clear();
    }

    // Prevent copying and assignment to manage memory explicitly
    AstNode(const AstNode&) = delete;
    AstNode& operator=(const AstNode&) = delete;
    AstNode(AstNode&&) = delete;
    AstNode& operator=(AstNode&&) = delete;

    // Method to add a child node
    void addChild(AstNode* child) {
        if (child) {
            children.push_back(child);
        }
    }
};

// Helper function to print the AST (for debugging)
inline void print_ast(const AstNode* node, int indent = 0) {
    if (!node) return;

    for (int i = 0; i < indent; ++i) std::cout << "  ";

    std::string type_str;
    switch(node->type) {
        case NodeType::NODE_UNKNOWN: type_str = "UNKNOWN"; break;
        case NodeType::NODE_COMMAND: type_str = "COMMAND"; break;
        case NodeType::NODE_SELECT_STATEMENT: type_str = "SELECT_STMT"; break;
        case NodeType::NODE_INSERT_STATEMENT: type_str = "INSERT_STMT"; break;
        case NodeType::NODE_DELETE_STATEMENT: type_str = "DELETE_STMT"; break;
        case NodeType::NODE_IDENTIFIER: type_str = "IDENTIFIER"; break;
        case NodeType::NODE_STRING_LITERAL: type_str = "STRING_LITERAL"; break;
        case NodeType::NODE_NUMBER_LITERAL: type_str = "NUMBER_LITERAL"; break;
        case NodeType::NODE_ASTERISK: type_str = "ASTERISK"; break;
        case NodeType::NODE_SET_STATEMENT: type_str = "SET_STATEMENT"; break;
        case NodeType::NODE_VARIABLE_ASSIGNMENT: type_str = "VAR_ASSIGN"; break;
        case NodeType::NODE_USER_VARIABLE: type_str = "USER_VAR"; break;
        case NodeType::NODE_SYSTEM_VARIABLE: type_str = "SYSTEM_VAR"; break;
        case NodeType::NODE_VARIABLE_SCOPE: type_str = "VAR_SCOPE"; break;
        case NodeType::NODE_EXPRESSION_PLACEHOLDER: type_str = "EXPR_PLACEHOLDER"; break;
        case NodeType::NODE_SIMPLE_EXPRESSION: type_str = "SIMPLE_EXPRESSION"; break;
        case NodeType::NODE_AGGREGATE_FUNCTION_CALL: type_str = "AGGREGATE_FUNC_CALL"; break;
        case NodeType::NODE_SET_NAMES: type_str = "SET_NAMES"; break;
        case NodeType::NODE_SET_CHARSET: type_str = "SET_CHARSET"; break;
        case NodeType::NODE_DELETE_OPTIONS: type_str = "DELETE_OPTIONS"; break;
        case NodeType::NODE_TABLE_NAME_LIST: type_str = "TABLE_NAME_LIST"; break;
        case NodeType::NODE_FROM_CLAUSE: type_str = "FROM_CLAUSE"; break;
        case NodeType::NODE_USING_CLAUSE: type_str = "USING_CLAUSE"; break;
        case NodeType::NODE_WHERE_CLAUSE: type_str = "WHERE_CLAUSE"; break;
        case NodeType::NODE_HAVING_CLAUSE: type_str = "HAVING_CLAUSE"; break;
        case NodeType::NODE_ORDER_BY_CLAUSE: type_str = "ORDER_BY_CLAUSE"; break;
        case NodeType::NODE_ORDER_BY_ITEM: type_str = "ORDER_BY_ITEM"; break;
        case NodeType::NODE_LIMIT_CLAUSE: type_str = "LIMIT_CLAUSE"; break;
        case NodeType::NODE_COMPARISON_EXPRESSION: type_str = "COMPARISON_EXPR"; break;
        case NodeType::NODE_LOGICAL_AND_EXPRESSION: type_str = "LOGICAL_AND_EXPR"; break;
        case NodeType::NODE_OPERATOR: type_str = "OPERATOR"; break;
        case NodeType::NODE_QUALIFIED_IDENTIFIER: type_str = "QUALIFIED_IDENTIFIER"; break;
        case NodeType::NODE_SELECT_OPTIONS: type_str = "SELECT_OPTIONS"; break;
        case NodeType::NODE_SELECT_ITEM_LIST: type_str = "SELECT_ITEM_LIST"; break;
        case NodeType::NODE_SELECT_ITEM: type_str = "SELECT_ITEM"; break;
        case NodeType::NODE_ALIAS: type_str = "ALIAS"; break;
        case NodeType::NODE_TABLE_REFERENCE: type_str = "TABLE_REFERENCE"; break;
        case NodeType::NODE_GROUP_BY_CLAUSE: type_str = "GROUP_BY_CLAUSE"; break;
        case NodeType::NODE_GROUPING_ELEMENT: type_str = "GROUPING_ELEMENT"; break;
        case NodeType::NODE_JOIN_CLAUSE: type_str = "JOIN_CLAUSE"; break;
        case NodeType::NODE_JOIN_TYPE_NATURAL_SPEC: type_str = "JOIN_TYPE_NATURAL_SPEC"; break;
        case NodeType::NODE_JOIN_CONDITION_ON: type_str = "JOIN_CONDITION_ON"; break;
        case NodeType::NODE_JOIN_CONDITION_USING: type_str = "JOIN_CONDITION_USING"; break;
        case NodeType::NODE_COLUMN_LIST: type_str = "COLUMN_LIST"; break;
        case NodeType::NODE_INTO_CLAUSE: type_str = "INTO_CLAUSE"; break;
        case NodeType::NODE_INTO_VAR_LIST: type_str = "INTO_VAR_LIST"; break;
        case NodeType::NODE_INTO_OUTFILE: type_str = "INTO_OUTFILE"; break;
        case NodeType::NODE_INTO_DUMPFILE: type_str = "INTO_DUMPFILE"; break;
        case NodeType::NODE_LOCKING_CLAUSE_LIST: type_str = "LOCKING_CLAUSE_LIST"; break;
        case NodeType::NODE_LOCKING_CLAUSE: type_str = "LOCKING_CLAUSE"; break;
        case NodeType::NODE_LOCK_STRENGTH: type_str = "LOCK_STRENGTH"; break;
        case NodeType::NODE_LOCK_TABLE_LIST: type_str = "LOCK_TABLE_LIST"; break;
        case NodeType::NODE_LOCK_OPTION: type_str = "LOCK_OPTION"; break;
        case NodeType::NODE_DERIVED_TABLE: type_str = "DERIVED_TABLE"; break;
        case NodeType::NODE_SUBQUERY: type_str = "SUBQUERY"; break;
        case NodeType::NODE_FILE_OPTIONS: type_str = "FILE_OPTIONS"; break;
        case NodeType::NODE_FIELDS_OPTIONS_CLAUSE: type_str = "FIELDS_OPTIONS_CLAUSE"; break;
        case NodeType::NODE_LINES_OPTIONS_CLAUSE: type_str = "LINES_OPTIONS_CLAUSE"; break;
        case NodeType::NODE_FIELDS_TERMINATED_BY: type_str = "FIELDS_TERMINATED_BY"; break;
        case NodeType::NODE_FIELDS_ENCLOSED_BY: type_str = "FIELDS_ENCLOSED_BY"; break;
        case NodeType::NODE_FIELDS_OPTIONALLY_ENCLOSED_BY: type_str = "FIELDS_OPTIONALLY_ENCLOSED_BY"; break;
        case NodeType::NODE_FIELDS_ESCAPED_BY: type_str = "FIELDS_ESCAPED_BY"; break;
        case NodeType::NODE_LINES_STARTING_BY: type_str = "LINES_STARTING_BY"; break;
        case NodeType::NODE_LINES_TERMINATED_BY: type_str = "LINES_TERMINATED_BY"; break;
        case NodeType::NODE_CHARSET_OPTION: type_str = "CHARSET_OPTION"; break;
        case NodeType::NODE_KEYWORD: type_str = "KEYWORD"; break;
        default: type_str = "UNHANDLED_TYPE(" + std::to_string(static_cast<int>(node->type)) + ")"; break;
    }
    std::cout << "Type: " << type_str;
    if (!node->value.empty()) {
        std::cout << ", Value: '" << node->value << "'";
    }
    std::cout << std::endl;

    for (const AstNode* child : node->children) {
        print_ast(child, indent + 1);
    }
}

} // namespace MysqlParser

#endif // MYSQL_PARSER_AST_H

