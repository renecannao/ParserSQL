#include "mysql_parser/mysql_parser.h"
#include <stdexcept>

// yyscan_t is defined as typedef void* yyscan_t; in mysql_parser.h
struct yy_buffer_state; // Forward declaration for the opaque Flex buffer type
typedef struct yy_buffer_state *YY_BUFFER_STATE;

// Flex utility functions are now from C++ compiled mysql_lexer.yy.c
// No extern "C" needed for these declarations as their definitions will also have C++ linkage.
extern int mysql_yylex_init_extra(MySQLParser::Parser* user_defined, yyscan_t* yyscanner_r);
extern int mysql_yylex_destroy(yyscan_t yyscanner); 
extern YY_BUFFER_STATE mysql_yy_scan_string(const char *yy_str, yyscan_t yyscanner);
extern void mysql_yy_delete_buffer(YY_BUFFER_STATE b, yyscan_t yyscanner);

// Bison-generated parser function (now compiled as C++, so C++ linkage)
// The api.prefix makes it mysql_yyparse.
// The %parse-param defines its arguments.
extern int mysql_yyparse(yyscan_t yyscanner, MySQLParser::Parser* parser_context);

// mysql_yyerror is called by mysql_yyparse.
// Since mysql_yyparse is C++, mysql_yyerror can also be regular C++.
// Its declaration is in mysql_parser.h (should also not be extern "C" there).
// The definition is at the bottom of this file.
void mysql_yyerror(yyscan_t yyscanner, MySQLParser::Parser* parser_context, const char* msg);
void mysql_yyerror(MYSQL_YYLTYPE* yyloc, yyscan_t yyscanner, MySQLParser::Parser* parser_context, const char* msg);

namespace MySQLParser {

Parser::Parser() : ast_root_(nullptr), scanner_state_(nullptr) {
    if (mysql_yylex_init_extra(this, &scanner_state_)) {
        throw std::runtime_error("MySQLParser: Failed to initialize Flex scanner.");
    }
}

Parser::~Parser() {
    if (scanner_state_) {
        mysql_yylex_destroy(scanner_state_);
    }
}

void Parser::clear_errors() {
    errors_.clear();
}

const std::vector<std::string>& Parser::get_errors() const {
    return errors_;
}

std::unique_ptr<AstNode> Parser::parse(const std::string& sql_query) {
    clear_errors();
    ast_root_.reset(); 

    if (!scanner_state_) {
        errors_.push_back("MySQLParser: Scanner not initialized.");
        return nullptr;
    }

    YY_BUFFER_STATE buffer_state = mysql_yy_scan_string(sql_query.c_str(), scanner_state_);
    if (!buffer_state) {
        errors_.push_back("MySQLParser: Error setting up scanner buffer for query.");
        return nullptr;
    }

    // Call mysql_yyparse (which is now a C++ function from the C++ compiled .tab.c)
    int parse_result = mysql_yyparse(scanner_state_, this);

    mysql_yy_delete_buffer(buffer_state, scanner_state_);

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

} // namespace MySQLParser


// This function is called by Bison-generated code (mysql_yyparse).
// Since mysql_yyparse is now compiled as C++, this can be a regular C++ function.
// The name must match what Bison expects (mysql_yyerror).
// Its declaration is in mysql_parser.h and should also not be extern "C".
void mysql_yyerror(yyscan_t yyscanner, MySQLParser::Parser* parser_context, const char* msg) {
    if (parser_context) {
        parser_context->internal_add_error(msg);
    } else {
        fprintf(stderr, "MySQLParser Error (yyerror - no context): %s\n", msg);
    }
}

void mysql_yyerror(MYSQL_YYLTYPE*, yyscan_t yyscanner, MySQLParser::Parser* parser_context, const char* msg) {
    if (parser_context) {
        parser_context->internal_add_error(msg);
    } else {
        fprintf(stderr, "MySQLParser Error (yyerror - no context): %s\n", msg);
    }
}
