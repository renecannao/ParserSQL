#ifndef MYSQL_PARSER_AST_H
#define MYSQL_PARSER_AST_H

#include <string>
#include <vector>
#include <iostream>
#include <algorithm> 

namespace MysqlParser { // Changed namespace

// NodeType enum can be identical for this stage, or diverge later
enum class NodeType {
    NODE_UNKNOWN,
    NODE_COMMAND,
    NODE_SELECT_STATEMENT,
    NODE_INSERT_STATEMENT,
    NODE_IDENTIFIER,
    NODE_STRING_LITERAL,
    NODE_ASTERISK,
    NODE_SET_STATEMENT,
    NODE_VARIABLE_ASSIGNMENT,   // for @var = expr or sysvar = expr
    NODE_USER_VARIABLE,         // for @varname
    NODE_SYSTEM_VARIABLE,       // for sysvar (can have scope)
    NODE_VARIABLE_SCOPE,        // GLOBAL, SESSION, PERSIST, PERSIST_ONLY
    NODE_EXPRESSION_PLACEHOLDER,// Placeholder for complex expressions
    NODE_SET_NAMES,             // for SET NAMES
    NODE_SET_CHARSET            // for SET CHARSET
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
        default: type_str = "UNHANDLED_TYPE(" + std::to_string(static_cast<int>(node->type)) + ")"; break;
    }
    std::cout << "Type: " << type_str << ", Value: '" << node->value << "'" << std::endl;
    for (const AstNode* child : node->children) {
        print_ast(child, indent + 1);
    }
}

} // namespace MysqlParser

#endif // MYSQL_PARSER_AST_H
