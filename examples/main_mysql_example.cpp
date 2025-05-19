#include "mysql_parser/mysql_parser.h" // Ensure this path is correct for your include setup
#include <iostream>
#include <vector>
#include <string>

void parse_and_print(MysqlParser::Parser& parser, const std::string& query_type, const std::string& query) {
    std::cout << "------------------------------------------\n";
    std::cout << "Parsing MySQL " << query_type << " query: " << query << std::endl;

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

int main() {
    MysqlParser::Parser parser;

    std::vector<std::string> select_queries = {
        "SELECT name FROM users;",
        "SELECT * FROM `orders`;",
        "SELECT * FROM tablenameB" // No semicolon
    };

    std::vector<std::string> insert_queries = {
        "INSERT INTO products VALUES ('a new gadget');",
        "INSERT INTO logs VALUES (\"Error message with double quotes\")", // No semicolon
        "INSERT INTO `special-table` VALUES ('escaped value \\'single quote\\' and \\\\ backslash');"
    };

    std::vector<std::string> set_queries = {
        "SET @my_user_var = 'hello world';",
        "SET @anotherVar = 12345;",
        "SET global max_connections = 1000", // No semicolon
        "SET @@session.net_write_timeout = 120;",
        "SET NAMES 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';",
        "SET CHARACTER SET DEFAULT",
        "SET @a = 1, @b = 'two', global max_heap_table_size = 128000000;"
    };

    std::vector<std::string> delete_queries = {
        // Single-table DELETE statements
        "DELETE FROM customers WHERE customer_id = 101;",
        "DELETE LOW_PRIORITY FROM orders WHERE order_date < '2023-01-01'",
        "DELETE QUICK IGNORE FROM logs WHERE log_level = 'DEBUG' ORDER BY timestamp DESC LIMIT 1000;",
        "DELETE FROM events WHERE event_name = `expired-event`", // Backticked identifier for value

        // Multi-table DELETE statements (simplified, based on current grammar)
        "DELETE t1 FROM table1 AS t1, table2 AS t2 WHERE t1.id = t2.ref_id;", // Needs table_reference_list_placeholder to be more robust
        "DELETE FROM t1, t2 USING table1 AS t1 INNER JOIN table2 AS t2 ON t1.key = t2.key WHERE t1.value > 100;", // Also simplified

        // DELETE without semicolon
        "DELETE FROM old_records WHERE last_accessed < '2020-01-01'",

        // Potentially problematic or error cases for DELETE
        "DELETE quick low_priority from test_table", // Order of options might matter or not be fully supported yet
        "DELETE FROM table1 WHERE id = ", // Incomplete WHERE
        "DELETE tbl1 tbl2 FROM table_references" // Common MySQL multi-table, current grammar might simplify tbl1, tbl2 part
    };


    std::cout << "\n======= SELECT QUERIES =======\n";
    for (const auto& query : select_queries) {
        parse_and_print(parser, "SELECT", query);
    }

    std::cout << "\n======= INSERT QUERIES =======\n";
    for (const auto& query : insert_queries) {
        parse_and_print(parser, "INSERT", query);
    }

    std::cout << "\n======= SET QUERIES =======\n";
    for (const auto& query : set_queries) {
        parse_and_print(parser, "SET", query);
    }

    std::cout << "\n======= DELETE QUERIES =======\n";
    for (const auto& query : delete_queries) {
        parse_and_print(parser, "DELETE", query);
    }

    // Example of a known failing query (due to function call in expression_placeholder)
    std::cout << "\n======= KNOWN FAILING SET QUERY (Function Call) =======\n";
    parse_and_print(parser, "SET", "SET @myvar = some_function(1, 'a');");

    std::cout << "\n======= KNOWN FAILING SET QUERY (Invalid Identifier) =======\n";
    parse_and_print(parser, "SET", "SET global invalid-variable = 100;");


    return 0;
}
