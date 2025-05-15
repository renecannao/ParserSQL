#ifndef PGSQL_PARSER_PARSER_H
#define PGSQL_PARSER_PARSER_H

#include "pgsql_ast.h"
#include <string>
#include <vector>
#include <memory>

typedef void* yyscan_t;

namespace PgsqlParser {

class Parser {
public:
    Parser();
    ~Parser();

    std::unique_ptr<AstNode> parse(const std::string& sql_query);

    const std::vector<std::string>& getErrors() const;
    void clearErrors();

    void internal_set_ast(AstNode* root);
    void internal_add_error(const std::string& msg);
    void internal_add_error_at(const std::string& msg, int line, int column);

private:
    std::unique_ptr<AstNode> ast_root_;
    std::vector<std::string> errors_;
    yyscan_t scanner_state_;
};

} // namespace PgsqlParser

// Declaration for pgsql_yyerror, which is called by Bison's pgsql_yyparse.
// Since pgsql_yyparse is now compiled as C++, this can be a regular C++ declaration.
void pgsql_yyerror(yyscan_t yyscanner, PgsqlParser::Parser* parser_context, const char* msg); // REMOVED extern "C"

#endif // PGSQL_PARSER_PARSER_H
