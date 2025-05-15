#include "mysql_parser/mysql_parser.h" // Changed include path and namespace
#include <iostream>
#include <vector>
#include <string>

int main() {
    MysqlParser::Parser parser; // Changed namespace

    std::vector<std::string> queries = {
        "SELECT name FROM users;",
        "SELECT * FROM `orders`;", // MySQL backticked identifier
        "INSERT INTO products VALUES ('a new gadget');",
        "INSERT INTO logs VALUES (\"Error message with double quotes\");", // MySQL double quotes
        "INSERT INTO `special-table` VALUES ('escaped value \\'single quote\\' and \\\\ backslash');", // MySQL escapes
        "QUIT", // MySQL often doesn't require semicolon for last statement in a batch
        "SELECT * FROM WHERE;", 
        "INSERT INTO logs VALUES (no_quotes_here);" 
    };

    for (const auto& query : queries) {
        std::cout << "------------------------------------------\n";
        std::cout << "Parsing MySQL query: " << query << std::endl;
        
        parser.clearErrors(); 
        std::unique_ptr<MysqlParser::AstNode> ast = parser.parse(query); // Changed namespace

        if (ast) {
            std::cout << "Parsing successful!" << std::endl;
            MysqlParser::print_ast(ast.get()); // Changed namespace
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
