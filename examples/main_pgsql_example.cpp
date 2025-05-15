#include "pgsql_parser/pgsql_parser.h" // Changed include path and namespace
#include <iostream>
#include <vector>
#include <string>

int main() {
    PgsqlParser::Parser parser; // Changed namespace

    std::vector<std::string> queries = {
        "SELECT name FROM users;",
        "INSERT INTO products VALUES ('a new gadget');",
        "QUIT;",
        "SELECT * FROM tablenameA;",
        "SELECT * FROM tablenameB",
        "SELECT * FROM;",
        "INSERT INTO logs VALUES (no_quotes_here);"
    };

    for (const auto& query : queries) {
        std::cout << "------------------------------------------\n";
        std::cout << "Parsing query: " << query << std::endl;
        
        parser.clearErrors(); 
        std::unique_ptr<PgsqlParser::AstNode> ast = parser.parse(query); // Changed namespace

        if (ast) {
            std::cout << "Parsing successful!" << std::endl;
            PgsqlParser::print_ast(ast.get()); // Changed namespace
        } else {
            std::cout << "Parsing failed." << std::endl;
            const auto& errors = parser.getErrors();
            if (errors.empty()) {
                std::cout << "  (No specific error messages, check parser logic or pgsql_yyerror)" << std::endl;
            } else {
                for (const auto& error : errors) {
                    std::cout << "  Error: " << error << std::endl;
                }
            }
        }
    }
    return 0;
}
