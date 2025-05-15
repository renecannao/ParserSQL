#include "pgsql_parser/pgsql_parser.h"
#include <stdexcept>

// yyscan_t is defined as typedef void* yyscan_t; in pgsql_parser.h
struct yy_buffer_state; // Forward declaration
typedef struct yy_buffer_state *YY_BUFFER_STATE;

// Flex utility functions are now from C++ compiled pgsql_lexer.yy.c
// No extern "C" needed for these declarations if the definitions are also C++ linkage.
// Ensure these match the signatures Flex generates (which YY_DECL controls for pgsql_yylex)
extern int pgsql_yylex_init_extra(PgsqlParser::Parser* user_defined, yyscan_t* yyscanner_r);
extern int pgsql_yylex_destroy(yyscan_t yyscanner); 
extern YY_BUFFER_STATE pgsql_yy_scan_string(const char *yy_str, yyscan_t yyscanner);
extern void pgsql_yy_delete_buffer(YY_BUFFER_STATE b, yyscan_t yyscanner);

// Bison-generated parser function (now compiled as C++, so C++ linkage)
extern int pgsql_yyparse(yyscan_t yyscanner, PgsqlParser::Parser* parser_context);

// pgsql_yyerror is called by pgsql_yyparse.
// If pgsql_yyparse is C++, pgsql_yyerror can also be regular C++.
// Its declaration is in pgsql_parser.h.
// The actual definition for pgsql_yyerror will be linked from here.
// The extern "C" on its definition/declaration might be needed if other C code might call it.
// For now, let's remove extern "C" from its definition here and from pgsql_parser.h for consistency.
void pgsql_yyerror_definition_for_parser(yyscan_t yyscanner, PgsqlParser::Parser* parser_context, const char* msg);


namespace PgsqlParser {

Parser::Parser() : ast_root_(nullptr), scanner_state_(nullptr) {
    if (pgsql_yylex_init_extra(this, &scanner_state_)) {
        throw std::runtime_error("PgsqlParser: Failed to initialize Flex scanner.");
    }
}

Parser::~Parser() {
    if (scanner_state_) {
        pgsql_yylex_destroy(scanner_state_);
    }
}

void Parser::clearErrors() {
    errors_.clear();
}

const std::vector<std::string>& Parser::getErrors() const {
    return errors_;
}

std::unique_ptr<AstNode> Parser::parse(const std::string& sql_query) {
    clearErrors();
    ast_root_.reset(); 

    if (!scanner_state_) {
        errors_.push_back("PgsqlParser: Scanner not initialized.");
        return nullptr;
    }

    YY_BUFFER_STATE buffer_state = pgsql_yy_scan_string(sql_query.c_str(), scanner_state_);
    if (!buffer_state) {
        errors_.push_back("PgsqlParser: Error setting up scanner buffer for query.");
        return nullptr;
    }

    int parse_result = pgsql_yyparse(scanner_state_, this);

    pgsql_yy_delete_buffer(buffer_state, scanner_state_);

    if (parse_result == 0) { 
        return std::move(ast_root_); 
    }
    return nullptr;
}

void Parser::internal_set_ast(AstNode* root) {
    ast_root_.reset(root);
}

void Parser::internal_add_error(const std::string& msg) {
    errors_.push_back(msg);
}

void Parser::internal_add_error_at(const std::string& msg, int line, int column) {
    errors_.push_back("Line " + std::to_string(line) + ", Col " + std::to_string(column) + ": " + msg);
}

} // namespace PgsqlParser


// This function is called by Bison-generated code (pgsql_yyparse).
// Since pgsql_yyparse is now compiled as C++, this can be a regular C++ function.
// The name must match what Bison expects (pgsql_yyerror).
// Its declaration was in pgsql_parser.h.
void pgsql_yyerror(yyscan_t yyscanner, PgsqlParser::Parser* parser_context, const char* msg) {
    if (parser_context) {
        parser_context->internal_add_error(msg);
    } else {
        // This case should ideally not happen if parser_context is always passed.
        fprintf(stderr, "PgsqlParser Error (yyerror - no context): %s\n", msg);
    }
}
