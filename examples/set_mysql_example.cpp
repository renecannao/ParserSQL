#include "mysql_parser/mysql_parser.h" // Ensure this path is correct for your include setup
#include <iostream>
#include <vector>
#include <string>

int main() {
    MysqlParser::Parser parser; // Using the MysqlParser namespace

    std::vector<std::string> set_queries = {
        // Basic User Variable Assignments
        "SET @my_user_var = 'hello world';",
        "SET @anotherVar = 12345;",
        "SET @thirdVar = `ident_value`;", // Using identifier as value
        "SET @complex_var = @@global.max_connections;", // Setting user var to sys var value (expr placeholder)

        // System Variable Assignments
        "SET global max_connections = 1000;",
        "SET session sort_buffer_size = 200000;",
        "SET GLOBAL sort_buffer_size = 400000;", // Case-insensitivity for scope
        "SET SESSION wait_timeout = 180;",
        "SET @@global.tmp_table_size = 32000000;",
        "SET @@session.net_write_timeout = 120;",
        "SET @@net_read_timeout = 60;", // Implicit SESSION scope for @@
        "SET max_allowed_packet = 64000000;", // Implicit SESSION scope for simple sysvar

        // PERSIST / PERSIST_ONLY (if supported by your current grammar for scope)
        "SET persist character_set_server = 'utf8mb4';",
        "SET persist_only innodb_buffer_pool_size = '1G';", // String literal for value

        // SET NAMES and CHARACTER SET
        "SET NAMES 'utf8mb4';",
        "SET NAMES `latin1`;",
        "SET NAMES DEFAULT;",
        "SET NAMES 'gbk' COLLATE 'gbk_chinese_ci';",
        "SET CHARACTER SET 'utf8';",
        "SET CHARACTER SET DEFAULT;",

        // Comma-separated list (testing set_option_list)
        "SET @a = 1, @b = 'two', global max_heap_table_size = 128000000;",
        "SET sql_mode = 'STRICT_TRANS_TABLES', character_set_client = 'utf8mb4';",

        // Statements without trailing semicolon (should work with optional_semicolon)
        "SET @no_semicolon = 'works'",

        // Test cases for potential errors or unsupported expressions
        "SET @myvar = some_function(1, 'a');", // 'some_function(...)' is just an identifier for expression_placeholder for now
        "SET global invalid-variable = 100;", // Invalid identifier char (if not quoted)
        "SET @unterminated_string = 'oops", 
        "SET =", // Syntax error
        "SET names utf8 collate ;" // Missing collation name
    };

    for (const auto& query : set_queries) {
        std::cout << "------------------------------------------\n";
        std::cout << "Parsing MySQL SET query: " << query << std::endl;
        
        parser.clearErrors(); 
        std::unique_ptr<MysqlParser::AstNode> ast = parser.parse(query);

        if (ast) {
            std::cout << "Parsing successful!" << std::endl;
            MysqlParser::print_ast(ast.get());
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
