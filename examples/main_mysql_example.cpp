#include "mysql_parser/mysql_parser.h" // Ensure this path is correct for your include setup
#include <iostream>
#include <vector>
#include <string>
#include <memory> // Required for std::unique_ptr

bool verbose_print = true;
unsigned long int queries = 0;

// Function to parse a query and print the AST or errors
void parse_and_print(MysqlParser::Parser& parser, const std::string& query_type, const std::string& query) {
	queries++;
	if (verbose_print) {
        std::cout << "------------------------------------------\n";
        std::cout << "Parsing MySQL " << query_type << " query: " << query << std::endl;
	}
	//std::cout << "AAA" << std::endl;
    parser.clearErrors(); // Clear any errors from previous parses
	//std::cout << "BBB" << std::endl;
    std::unique_ptr<MysqlParser::AstNode> ast = parser.parse(query);
	//std::cout << "CCC" << std::endl;

	if (verbose_print == false) {
		return;
	}
    if (ast) {
        std::cout << "Parsing successful!" << std::endl;
        MysqlParser::print_ast(ast.get()); // Print the AST
    } else {
        std::cout << "Parsing failed." << std::endl;
        const auto& errors = parser.getErrors();
        if (errors.empty()) {
            std::cout << "  (No specific error messages, check parser logic or mysql_yyerror implementation)" << std::endl;
        } else {
            for (const auto& error : errors) {
                std::cout << "  Error: " << error << std::endl;
            }
        }
    }
    std::cout << "------------------------------------------\n\n";
}

int main() {
    MysqlParser::Parser parser;

    std::vector<std::string> select_queries = {
        // Basic SELECTs (from original)
        "SELECT name FROM users;",
        "SELECT * FROM `orders`;",
        "SELECT `col1`, `col2` FROM tablenameB", // No semicolon

        // SELECT with ALIAS
        "SELECT column1 AS first_column, column2 AS second_column FROM my_table;",
        "SELECT column1 first_column, column2 second_column FROM my_table;", // Implicit AS

        // SELECT with WHERE
        "SELECT product_name, price FROM products WHERE category = 'Electronics';",
        "SELECT * FROM employees WHERE salary > 50000 AND department_id = 3;",

        // SELECT with ORDER BY
        "SELECT student_name, score FROM results ORDER BY score DESC;",
        "SELECT item, quantity FROM inventory ORDER BY item ASC, quantity DESC;",

        // SELECT with LIMIT
        "SELECT event_name FROM event_log LIMIT 10;",
        "SELECT message FROM messages ORDER BY created_at DESC LIMIT 5, 10;", // LIMIT offset, count

        // SELECT with GROUP BY
        "SELECT department, COUNT(*) AS num_employees FROM employees GROUP BY department;",
        "SELECT product_category, AVG(price) AS avg_price FROM products GROUP BY product_category;",

        // SELECT with GROUP BY and HAVING
        "SELECT department, COUNT(*) AS num_employees FROM employees GROUP BY department HAVING COUNT(*) > 10;",
        "SELECT product_category, AVG(price) AS avg_price FROM products GROUP BY product_category HAVING AVG(price) > 100.00;",

        // Basic JOIN clauses
        "SELECT c.customer_name, o.order_id FROM customers c JOIN orders o ON c.customer_id = o.customer_id;",
        "SELECT s.name, p.product_name FROM suppliers s INNER JOIN products p ON s.supplier_id = p.supplier_id;",
        "SELECT e.name, d.department_name FROM employees e LEFT JOIN departments d ON e.department_id = d.department_id;",
        "SELECT e.name, p.project_name FROM employees e RIGHT OUTER JOIN projects p ON e.employee_id = p.lead_employee_id;",
        "SELECT c1.name, c2.name AS city_pair FROM cities c1 CROSS JOIN cities c2 WHERE c1.id <> c2.id;", // Comma join will be CROSS JOIN
        "SELECT c1.name, c2.name AS city_pair_comma FROM cities c1, cities c2 WHERE c1.id <> c2.id;",
        "SELECT e.name, d.name FROM employees e NATURAL JOIN departments d;", // Natural Join
        "SELECT s.student_name, c.course_name FROM students s NATURAL LEFT JOIN courses c;",

        // JOIN with USING
        "SELECT c.customer_name, o.order_date FROM customers c JOIN orders o USING (customer_id);",
        "SELECT a.val, b.val FROM tableA a LEFT JOIN tableB b USING (id, common_column);",

        // More complex JOINs (multiple joins)
        "SELECT c.name, o.order_date, p.product_name, oi.quantity "
        "FROM customers c "
        "JOIN orders o ON c.customer_id = o.customer_id "
        "JOIN order_items oi ON o.order_id = oi.order_id "
        "JOIN products p ON oi.product_id = p.product_id "
        "WHERE c.country = 'USA' ORDER BY o.order_date DESC;",

        // Subquery in FROM clause (Derived Table)
        "SELECT dt.category_name, dt.total_sales "
        "FROM (SELECT category, SUM(sales_amount) AS total_sales FROM sales GROUP BY category) AS dt "
        "WHERE dt.total_sales > 10000;",

        "SELECT emp_details.name, emp_details.dept "
        "FROM (SELECT e.name, d.department_name AS dept FROM employees e JOIN departments d ON e.dept_id = d.id) emp_details "
        "ORDER BY emp_details.name;",
        
        "SELECT * FROM (SELECT id FROM t1) AS derived_t1 JOIN (SELECT id FROM t2) AS derived_t2 ON derived_t1.id = derived_t2.id;",


        // SELECT ... INTO OUTFILE / DUMPFILE
        "SELECT user_id, username, email INTO OUTFILE '/tmp/users.txt' FROM user_accounts WHERE is_active = 1;",
        "SELECT * INTO OUTFILE '/tmp/products_export.csv' FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' LINES TERMINATED BY '\\n' FROM products;",
        "SELECT data_column INTO DUMPFILE '/tmp/data_blob.dat' FROM large_objects WHERE id = 42;",
        "SELECT col1, col2 INTO OUTFILE 'test_char_set.txt' CHARACTER SET 'utf8mb4' FIELDS ENCLOSED BY '`' FROM my_data;",


        // SELECT ... INTO variables
        "SELECT COUNT(*), MAX(salary) INTO @user_count, @max_sal FROM employees;",
        "SELECT name, email INTO @emp_name, @emp_email FROM employees WHERE id = 101;",

        // SELECT ... FOR UPDATE / FOR SHARE
        "SELECT account_balance FROM accounts WHERE account_id = 123 FOR UPDATE;",
        "SELECT product_name, quantity FROM inventory WHERE product_id = 789 FOR SHARE;",
        "SELECT c.name, o.status FROM customers c JOIN orders o ON c.id = o.customer_id WHERE o.id = 500 FOR UPDATE OF c, o;",
        "SELECT item_name FROM stock_items WHERE category = 'electronics' FOR SHARE NOWAIT;",
        "SELECT * FROM pending_tasks FOR UPDATE SKIP LOCKED;",
        "SELECT id FROM users WHERE status = 'pending' FOR SHARE OF users SKIP LOCKED;",


        // Combined query
        "SELECT c.name AS customer_name, COUNT(o.order_id) AS total_orders, SUM(oi.price * oi.quantity) AS total_spent "
        "FROM customers AS c "
        "LEFT JOIN orders AS o ON c.customer_id = o.customer_id "
        "JOIN order_items AS oi ON o.order_id = oi.order_id "
        "WHERE c.registration_date > '2022-01-01' "
        "GROUP BY c.customer_id, c.name "
        "HAVING COUNT(o.order_id) > 2 AND SUM(oi.price * oi.quantity) > 500 "
        "ORDER BY total_spent DESC, customer_name ASC "
        "LIMIT 10, 5 "
        "FOR UPDATE OF c, o NOWAIT;"
    };

    std::vector<std::string> insert_queries = {
        "INSERT INTO products VALUES ('a new gadget');",
        "INSERT INTO logs VALUES (\"Error message with double quotes\")",
        "INSERT INTO `special-table` VALUES ('escaped value \\'single quote\\' and \\\\ backslash');"
    };

    std::vector<std::string> set_queries = {
        "SET @my_user_var = 'hello world';",
        "SET @anotherVar = 12345;",
        "SET global max_connections = 1000",
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
        "DELETE FROM events WHERE event_name = `expired-event`",

        // Multi-table DELETE statements
        "DELETE t1 FROM table1 AS t1, table2 AS t2 WHERE t1.id = t2.ref_id;",
        "DELETE FROM t1, t2 USING table1 AS t1 INNER JOIN table2 AS t2 ON t1.key = t2.key WHERE t1.value > 100;",
        "DELETE FROM old_records WHERE last_accessed < '2020-01-01'"
    };

    const int iterations = 10000;
    for (int i = 0; i < iterations; i++) {
        if (verbose_print == true) std::cout << "\n======= SELECT QUERIES =======\n";
        for (const auto& query : select_queries) {
            parse_and_print(parser, "SELECT", query);
        }
        if (verbose_print == true) std::cout << "\n======= INSERT QUERIES =======\n";
        for (const auto& query : insert_queries) {
            parse_and_print(parser, "INSERT", query);
        }
    
        if (verbose_print == true) std::cout << "\n======= SET QUERIES =======\n";
        for (const auto& query : set_queries) {
            parse_and_print(parser, "SET", query);
        }
    
        if (verbose_print == true) std::cout << "\n======= DELETE QUERIES =======\n";
        for (const auto& query : delete_queries) {
            parse_and_print(parser, "DELETE", query);
        }
    
        // Example of a known failing query (due to function call in expression_placeholder)
        if (verbose_print == true) std::cout << "\n======= KNOWN FAILING SET QUERY (Function Call) =======\n";
        parse_and_print(parser, "SET", "SET @myvar = some_function(1, 'a');");
    
        if (verbose_print == true) std::cout << "\n======= KNOWN FAILING SET QUERY (Invalid Identifier) =======\n";
        parse_and_print(parser, "SET", "SET global invalid-variable = 100;");
    	if (verbose_print == true) { verbose_print=false; }
		if ((i+1) % 1000 == 0) {
			std::cout << i+1 << std::endl;
		}
    }
	std::cout << "Queries: " << queries << std::endl;
    return 0;
}

