#include "mysql_parser/mysql_parser.h" // Ensure this path is correct
#include "mysql_parser/mysql_ast.h"    // Ensure this path is correct
#include <iostream>
#include <vector>
#include <string>
#include <memory>    // Required for std::unique_ptr
#include <chrono>    // Required for timing
#include <iomanip>   // Required for std::fixed and std::setprecision
#include <sstream>   // Required for std::stringstream
#include <algorithm> // Required for std::all_of if used for whitespace check

// Function to parse command line arguments (same as before)
void parse_arguments(int argc, char* argv[], int& iterations, bool& print_ast_first_iteration) {
    iterations = 1; // Default value
    print_ast_first_iteration = false; // Default value

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "-i") {
            if (i + 1 < argc) {
                try {
                    iterations = std::stoi(argv[++i]);
                    if (iterations <= 0) {
                        std::cerr << "Warning: Number of iterations must be positive. Using default (1)." << std::endl;
                        iterations = 1;
                    }
                } catch (const std::invalid_argument& ia) {
                    std::cerr << "Warning: Invalid number for iterations. Using default (1)." << std::endl;
                    iterations = 1;
                } catch (const std::out_of_range& oor) {
                    std::cerr << "Warning: Iterations number out of range. Using default (1)." << std::endl;
                    iterations = 1;
                }
            } else {
                std::cerr << "Warning: -i option requires one argument." << std::endl;
            }
        } else if (arg == "-v") {
            print_ast_first_iteration = true;
        } else {
            std::cerr << "Warning: Unknown argument: " << arg << std::endl;
        }
    }
}

// Helper to trim whitespace from both ends of a string
std::string trim_string(const std::string &s) {
    auto wsfront = std::find_if_not(s.begin(), s.end(), [](int c){return std::isspace(c);});
    auto wsback = std::find_if_not(s.rbegin(), s.rend(), [](int c){return std::isspace(c);}).base();
    return (wsback <= wsfront ? std::string() : std::string(wsfront, wsback));
}

// Helper to check if a line is effectively empty (contains only whitespace)
bool is_line_empty(const std::string& s) {
    return std::all_of(s.begin(), s.end(), isspace);
}

extern int mysql_yydebug;

int main(int argc, char* argv[]) {
    mysql_yydebug = 1;
    int iterations_count;
    bool verbose_ast_first_iteration;
    parse_arguments(argc, argv, iterations_count, verbose_ast_first_iteration);

    std::vector<std::string> all_queries;
    std::cout << "Reading SQL queries from standard input. Press Ctrl+D (Linux/macOS) or Ctrl+Z then Enter (Windows) to end input." << std::endl;
    std::cout << "Queries can be optionally terminated by ';'. An empty line also acts as a delimiter for multi-line queries." << std::endl;
    
    std::string line;
    std::stringstream current_query_buffer;
    
    while (std::getline(std::cin, line)) {
        bool line_is_effectively_empty = is_line_empty(line);

        if (line_is_effectively_empty) {
            if (current_query_buffer.tellp() > 0) { // Check if buffer has content (tellp gives current put position)
                std::string query_candidate = current_query_buffer.str();
                current_query_buffer.str(""); // Clear buffer
                current_query_buffer.clear(); // Clear error flags

                std::string final_query = trim_string(query_candidate);
                if (!final_query.empty()) {
                    all_queries.push_back(final_query);
                }
            }
        } else {
            current_query_buffer << line << "\n"; // Append line and a newline

            // Check if the non-empty line ends with a semicolon
            std::string trimmed_current_line = trim_string(line); // Trim the current line for semicolon check
            if (!trimmed_current_line.empty() && trimmed_current_line.back() == ';') {
                if (current_query_buffer.tellp() > 0) {
                    std::string query_candidate = current_query_buffer.str();
                    current_query_buffer.str(""); 
                    current_query_buffer.clear();

                    std::string final_query = trim_string(query_candidate);
                    if (!final_query.empty()) {
                        all_queries.push_back(final_query);
                    }
                }
            }
        }
    }
    // Add any remaining content in the buffer as the last query (EOF)
    if (current_query_buffer.tellp() > 0) {
        std::string query_candidate = current_query_buffer.str();
        current_query_buffer.str("");
        current_query_buffer.clear();
        std::string final_query = trim_string(query_candidate);
        if (!final_query.empty()) {
            all_queries.push_back(final_query);
        }
    }

    if (all_queries.empty()) {
        std::cout << "No queries read from standard input. Exiting." << std::endl;
        return 0;
    }
    std::cout << all_queries.size() << " query/queries read from input. Starting parsing iterations." << std::endl;

    MySQLParser::Parser parser;
    long long successful_parses = 0;
    long long failed_parses = 0;

    // Start timer *after* reading input and *before* parsing loop
    auto total_start_time = std::chrono::high_resolution_clock::now();

    for (int iter = 0; iter < iterations_count; ++iter) {
        if (iterations_count > 1 && all_queries.size() > 0) { 
            std::cout << "Iteration " << (iter + 1) << "/" << iterations_count << std::endl;
        }
        for (const std::string& query_to_parse : all_queries) {
            // Output the query being parsed if verbose on first iteration, or for debugging
            // if (verbose_ast_first_iteration && iter == 0) {
            //     std::cout << "Parsing query: [" << query_to_parse << "]" << std::endl;
            // }

            parser.clear_errors();
            std::unique_ptr<MySQLParser::AstNode> ast = parser.parse(query_to_parse);

            if (ast) {
                successful_parses++;
                if (verbose_ast_first_iteration && iter == 0) {
                    std::cout << "------------------------------------------\n";
                    std::cout << "Query: " << query_to_parse << std::endl;
                    std::cout << "Parsing successful! AST:" << std::endl;
                    MySQLParser::print_ast(ast.get());
                    std::cout << "------------------------------------------\n\n";
                }
            } else {
                failed_parses++;
                if (verbose_ast_first_iteration && iter == 0) {
                    std::cout << "------------------------------------------\n";
                    std::cout << "Query: " << query_to_parse << std::endl;
                    std::cout << "Parsing failed." << std::endl;
                    const auto& errors = parser.get_errors();
                    if (errors.empty()) {
                        std::cout << "  (No specific error messages)" << std::endl;
                    } else {
                        for (const auto& error : errors) {
                            std::cout << "  Error: " << error << std::endl;
                        }
                    }
                    std::cout << "------------------------------------------\n\n";
                }
            }
        }
    }

    auto total_end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> total_duration = total_end_time - total_start_time;
    double total_seconds = total_duration.count();
    
    long long total_parsing_attempts = static_cast<long long>(iterations_count) * all_queries.size();

    double parsing_per_second = (total_seconds > 0 && total_parsing_attempts > 0) ? (total_parsing_attempts / total_seconds) : 0;

    std::cout << "\n======= SUMMARY =======\n";
    std::cout << "Unique queries read from input: " << all_queries.size() << std::endl;
    std::cout << "Iterations performed over these queries: " << iterations_count << std::endl;
    std::cout << "Total parsing attempts: " << total_parsing_attempts << std::endl;
    std::cout << "Successful parses: " << successful_parses << std::endl;
    std::cout << "Failed parses: " << failed_parses << std::endl;
    std::cout << "Total parsing time: " << std::fixed << std::setprecision(3) << total_seconds << " seconds" << std::endl;
    if (total_parsing_attempts > 0 && total_seconds > 0) {
        std::cout << "Average parsing speed: " << std::fixed << std::setprecision(2) << parsing_per_second << " queries/second" << std::endl;
    } else {
        std::cout << "Average parsing speed: N/A (no queries parsed or zero execution time)" << std::endl;
    }
    std::cout << "=======================\n";

    return 0;
}
