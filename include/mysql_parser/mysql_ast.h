#ifndef MYSQL_PARSER_AST_H
#define MYSQL_PARSER_AST_H

#include <string>
#include <vector>
#include <iostream>
#include <algorithm>

namespace MysqlParser {

enum class NodeType {
    NODE_UNKNOWN,
    NODE_COMMAND,
    NODE_SELECT_STATEMENT,
    NODE_INSERT_STATEMENT,
    NODE_DELETE_STATEMENT,
    NODE_IDENTIFIER,
    NODE_STRING_LITERAL,
    NODE_ASTERISK,
    NODE_SET_STATEMENT,
    NODE_VARIABLE_ASSIGNMENT,
    NODE_USER_VARIABLE,
    NODE_SYSTEM_VARIABLE,
    NODE_VARIABLE_SCOPE,
    NODE_EXPRESSION_PLACEHOLDER,
    NODE_SET_NAMES,
    NODE_SET_CHARSET,
    NODE_DELETE_OPTIONS,
    NODE_TABLE_NAME_LIST,
    NODE_FROM_CLAUSE,
    NODE_USING_CLAUSE,
    NODE_WHERE_CLAUSE,
    NODE_ORDER_BY_CLAUSE,
    NODE_ORDER_BY_ITEM,
    NODE_LIMIT_CLAUSE,
    NODE_COMPARISON_EXPRESSION,
    NODE_OPERATOR,
    NODE_QUALIFIED_IDENTIFIER
};

struct AstNode {
    NodeType type;
    std::string value;
    std::vector<AstNode*> children;

    AstNode(NodeType t, const std::string& val = "") : type(t), value(val) {}
    AstNode(NodeType t, std::string&& val) : type(t), value(std::move(val)) {}

    ~AstNode() {
        for (AstNode* child : children) {
            delete child;
        }
    }

    AstNode(const AstNode&) = delete;
    AstNode& operator=(const AstNode&) = delete;
    AstNode(AstNode&&) = delete;
    AstNode& operator=(AstNode&&) = delete;

    void addChild(AstNode* child) {
        if (child) {
            children.push_back(child);
        }
    }
};

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
        case NodeType::NODE_ASTERISK: type_str = "ASTERISK"; break;
        case NodeType::NODE_SET_STATEMENT: type_str = "SET_STATEMENT"; break;
        case NodeType::NODE_VARIABLE_ASSIGNMENT: type_str = "VAR_ASSIGN"; break;
        case NodeType::NODE_USER_VARIABLE: type_str = "USER_VAR"; break;
        case NodeType::NODE_SYSTEM_VARIABLE: type_str = "SYSTEM_VAR"; break;
        case NodeType::NODE_VARIABLE_SCOPE: type_str = "VAR_SCOPE"; break;
        case NodeType::NODE_EXPRESSION_PLACEHOLDER: type_str = "EXPR_PLACEHOLDER"; break;
        case NodeType::NODE_SET_NAMES: type_str = "SET_NAMES"; break;
        case NodeType::NODE_SET_CHARSET: type_str = "SET_CHARSET"; break;
        case NodeType::NODE_DELETE_OPTIONS: type_str = "DELETE_OPTIONS"; break;
        case NodeType::NODE_TABLE_NAME_LIST: type_str = "TABLE_NAME_LIST"; break;
        case NodeType::NODE_FROM_CLAUSE: type_str = "FROM_CLAUSE"; break;
        case NodeType::NODE_USING_CLAUSE: type_str = "USING_CLAUSE"; break;
        case NodeType::NODE_WHERE_CLAUSE: type_str = "WHERE_CLAUSE"; break;
        case NodeType::NODE_ORDER_BY_CLAUSE: type_str = "ORDER_BY_CLAUSE"; break;
        case NodeType::NODE_ORDER_BY_ITEM: type_str = "ORDER_BY_ITEM"; break;
        case NodeType::NODE_LIMIT_CLAUSE: type_str = "LIMIT_CLAUSE"; break;
        case NodeType::NODE_COMPARISON_EXPRESSION: type_str = "COMPARISON_EXPR"; break;
        case NodeType::NODE_OPERATOR: type_str = "OPERATOR"; break; // <<< ADDED CASE
        case NodeType::NODE_QUALIFIED_IDENTIFIER: type_str = "QUALIFIED_IDENTIFIER"; break;
        default: type_str = "UNHANDLED_TYPE(" + std::to_string(static_cast<int>(node->type)) + ")"; break;
    }
    std::cout << "Type: " << type_str << ", Value: '" << node->value << "'" << std::endl;
    for (const AstNode* child : node->children) {
        print_ast(child, indent + 1);
    }
}

} // namespace MysqlParser

#endif // MYSQL_PARSER_AST_H
