// include/pgsql_parser/pgsql_ast.h
#ifndef PGSQL_PARSER_AST_H
#define PGSQL_PARSER_AST_H

#include <string>
#include <vector>
#include <iostream>
#include <algorithm> // For potential string manipulations

namespace PgsqlParser {

// Enum for different types of AST nodes
enum class NodeType {
    NODE_UNKNOWN,
    NODE_COMMAND,
    NODE_SELECT_STATEMENT,
    NODE_INSERT_STATEMENT,
    NODE_IDENTIFIER,
    NODE_STRING_LITERAL,
    NODE_ASTERISK // New node type for '*' in SELECT
};

// Basic AST Node
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
        case NodeType::NODE_IDENTIFIER: type_str = "IDENTIFIER"; break;
        case NodeType::NODE_STRING_LITERAL: type_str = "STRING_LITERAL"; break;
        case NodeType::NODE_ASTERISK: type_str = "ASTERISK"; break; // Handle new type
        default: type_str = "UNHANDLED_TYPE(" + std::to_string(static_cast<int>(node->type)) + ")"; break;
    }
    std::cout << "Type: " << type_str << ", Value: '" << node->value << "'" << std::endl;
    for (const AstNode* child : node->children) {
        print_ast(child, indent + 1);
    }
}

} // namespace PgsqlParser

#endif // PGSQL_PARSER_AST_H
