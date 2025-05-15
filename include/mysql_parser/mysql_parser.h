#ifndef MYSQL_PARSER_PARSER_H
#define MYSQL_PARSER_PARSER_H

#include "mysql_ast.h" // Uses MysqlParser::AstNode
#include <string>
#include <vector>
#include <memory>

typedef void* yyscan_t; // Should be the same opaque type for Flex

namespace MysqlParser { // Changed namespace

class Parser {
public:
    Parser();
    ~Parser();

    std::unique_ptr<AstNode> parse(const std::string& sql_query);

    const std::vector<std::string>& getErrors() const;
    void clearErrors();

    // Internal methods for Bison/Flex interaction
    void internal_set_ast(AstNode* root);
    void internal_add_error(const std::string& msg);
    void internal_add_error_at(const std::string& msg, int line, int column);


private:
    std::unique_ptr<AstNode> ast_root_;
    std::vector<std::string> errors_;
    yyscan_t scanner_state_;
};

} // namespace MysqlParser

// Declaration for mysql_yyerror, which is called by Bison's mysql_yyparse.
// As both generated parser and this definition will be C++, extern "C" not strictly needed here.
void mysql_yyerror(yyscan_t yyscanner, MysqlParser::Parser* parser_context, const char* msg); // Changed prefix

#endif // MYSQL_PARSER_PARSER_H
