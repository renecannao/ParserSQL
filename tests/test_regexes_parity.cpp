#include "MySQL_Set_Stmt_Parser.h"
#include "c_tokenizer.h"

#include "mysql_parser/mysql_parser.h"
#include "tests_utils.h"

#include <unistd.h>
#include <sys/ioctl.h>

#include <deque>
#include <fstream>
#include <iostream>
#include <string>
#include <string.h>
#include <vector>

#include <nlohmann/json.hpp>
#include <re2/re2.h>

using std::fstream;
using std::pair;
using std::string;
using std::vector;

using loc_t = std::pair<size_t,size_t>;

vector<loc_t> ext_vals_locs(const vector<const MySQLParser::AstNode*>& vars_assigns) {
	vector<loc_t> res {};

	std::transform(std::begin(vars_assigns), std::end(vars_assigns), std::back_inserter(res),
		[] (const MySQLParser::AstNode* node) -> loc_t {
			return { node->val_init_pos, node->val_end_pos };
		}
	);

	return res;
}

rc_t<bool> check_sess_scope(const MySQLParser::AstNode* node) {
	using MySQLParser::NodeType;

	if (node->type != NodeType::NODE_VARIABLE_ASSIGNMENT) {
		return { -1, false };
	}

	const auto scope { get_node(node,
		{{ NodeType::NODE_UNKNOWN, 0 }, { NodeType::NODE_VARIABLE_SCOPE, 0 }})
	};

	if (scope.first == -1) {
		return { 0, true };
	} else {
		return { 0, scope.second->value == "SESSION" };
	}
}

rc_t<vector<string>> get_test_queries() {
	vector<string> test_qs {};

	int n { 0 };
	if (ioctl(STDIN_FILENO, FIONREAD, &n)) {
		std::cerr << "ioctl: Failed to read number of bytes in stdin   errno=" << errno << "\n";
		return { EXIT_FAILURE, {} };
	}

	if (n > 0) {
		string line {};
		string cin_query {};

		while (std::getline(std::cin, line)) {
			cin_query += line + "\n";
		}

		test_qs.push_back(cin_query);
	} else {
		std::copy(exhaustive_queries.begin(), exhaustive_queries.end(), std::back_inserter(test_qs));
		std::copy(set_queries.begin(), set_queries.end(), std::back_inserter(test_qs));
		std::copy(setparser_queries.begin(), setparser_queries.end(), std::back_inserter(test_qs));
		std::copy(valid_sql_mode_subexpr.begin(), valid_sql_mode_subexpr.end(), std::back_inserter(test_qs));
		std::copy(invalid_sql_mode_subexpr.begin(), invalid_sql_mode_subexpr.end(), std::back_inserter(test_qs));

		char* SET_TESTING_CSV_PATH { getenv("SET_TESTING_CSV_PATH") };

		if (SET_TESTING_CSV_PATH) {
			std::fstream logfile_fs {};

			printf("Openning log file   path:'%s'\n", SET_TESTING_CSV_PATH);
			// no scope found, defaults to session
			logfile_fs.open(SET_TESTING_CSV_PATH, std::fstream::in | std::fstream::out);

			if (!logfile_fs.is_open() || !logfile_fs.good()) {
				fprintf(stderr, "Failed to open '%s' file   path=\"%s\" error=%d\n",
					basename(SET_TESTING_CSV_PATH), SET_TESTING_CSV_PATH, errno
				);
				return { EXIT_FAILURE, {} };
			}

			string next_line {};

			while (std::getline(logfile_fs, next_line)) {
				nlohmann::json j_next_line = nlohmann::json::parse(next_line);
				test_qs.push_back(j_next_line["query"]);
			}
		}
	}

	return { 0, test_qs };
}

string ext_inner_val(const string& s) {
	if (s.empty()) {
		return {};
	} else {
		if (s.front() == '\'' || s.front() == '"' || s.front() == '`') {
			return s.substr(1, s.size() - 2);
		} else {
			return s;
		}
	}
}

char is_space_char(char c) {
	if(c == ' ' || c == '\t' || c == '\n' || c == '\r') {
		return 1;
	} else {
		return 0;
	}
}

string fold_spaces(char c, const string& s) {
	if (s.empty()) {
		return string { c };
	} else {
		if (is_space_char(s.back()) && is_space_char(c)) {
			return s;
		} else {
			return s + c;
		}
	}
}

char safe_tolower(char ch) {
    return static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
}

int main() {
	vector<string> failed_matches {};
	rc_t<vector<string>> test_qs { get_test_queries() };

	if (test_qs.first) {
		return test_qs.first;
	}

	// Current ProxySQL parser
	MySQL_Set_Stmt_Parser regex_parser("");

	for (const auto& q : test_qs.second) {
		std::cout << "------------------------------------------\n";
		std::cout << "Parsing MySQL SET query: " << q << std::endl;

		MySQLParser::Parser parser;
		std::unique_ptr<MySQLParser::AstNode> ast = parser.parse(q);

		if (ast) {
			MySQLParser::print_ast(ast.get());

			const auto vars_assigns { ext_vars_assigns(ast.get()) };
			const auto vals_locs { ext_vals_locs(vars_assigns) };

			regex_parser.set_query(q);
			auto regex_vals { regex_parser.parse1v2() };

			const auto str_acc = [] (const string& s1, const string& s2) -> string {
				return s2 + " " + s1;
			};

			for (auto va : vars_assigns) {
				using MySQLParser::NodeType;

				const loc_t loc { va->val_init_pos, va->val_end_pos };
				const string var_name { get_node(va, {{ NodeType::NODE_UNKNOWN, 0 }}).second->value };
				const bool is_str { get_node(va, {{ NodeType::NODE_STRING_LITERAL, 1 }}).first == 0 };
				const bool is_id { get_node(va, {{ NodeType::NODE_IDENTIFIER, 1 }}).first == 0 };
				const bool is_sess_scope { check_sess_scope(va).second };
				const bool is_user_def {
					get_node(va, {{ MySQLParser::NodeType::NODE_USER_VARIABLE, 0 }}).first == 0
				};

				const string p_val { q.substr(loc.first - 1, loc.second - loc.first) };
				const string d_val { is_id || is_str ? fold(fold_spaces, ext_inner_val(p_val)) : p_val };
				const string f_val { std::all_of(d_val.begin(), d_val.end(), is_space_char) ?  "" : d_val };

				std::cout << "Variable assignment details:\n";
				std::cout << "  - Name: " << var_name << "\n";
				std::cout << "  - Sess Scope: " << is_sess_scope << "\n";
				std::cout << "  - User Defined: " << is_user_def << "\n";
				std::cout << "  - Type: " << std::to_string((int)va->type) << "\n";
				std::cout << "  - Value (" << loc.first << "," << loc.second << "): " << p_val << "\n";

				if (var_name == "sql_mode") {
					const auto verf_err { verf_sql_mode_val(p_val) };
					std::cout << "  - SQL_MODE_VERF: (" << verf_err.first << ", '" << verf_err.second<< "')\n";
				}

				const string lower_name {
					std::accumulate(var_name.begin(), var_name.end(), string {},
						[] (const string& s, const char c) -> string {
							return s + safe_tolower(c);
						}
					)
				};
				const vector<string> re_vals { regex_vals[lower_name] };
				const string re_val { trim(fold(str_acc, re_vals)) };

				std::cout << "  - RE2 Parser map: _" << nlohmann::json(regex_vals).dump() << "_\n";
				std::cout << "  - RE2 Parser map: _" << nlohmann::json(regex_vals).dump() << "_\n";
				std::cout << "  - RE2 Parser Val: _" << re_val << "_\n";
				std::cout << "  - AST Parser Val: _" << p_val << "_\n";
				std::cout << "  - AST Digest Val: _" << d_val << "_\n";
				std::cout << "  - AST Final  Val: _" << f_val << "_\n";

				if (!is_user_def && is_sess_scope && re_val != f_val) {
					std::cout << "WARNING: Mismatch between Regex Parser and AST parser\n";
					failed_matches.push_back(q);
				}
			}

			// Special query 'SET NAMES' / 'SET CHARACTER SET' / etc
			if (
				vars_assigns.empty()
				&& (
					ast.get()->type == MySQLParser::NodeType::NODE_SET_NAMES
					|| ast.get()->type == MySQLParser::NodeType::NODE_SET_CHARSET
				)
			) {
				const string type {
					ast.get()->type == MySQLParser::NodeType::NODE_SET_NAMES ?
					"NAMES" : "CHARSET"
				};
				std::cout << type << " assignment details:\n";

				regex_parser.set_query(q);

				string re_val {};

				if (ast.get()->type == MySQLParser::NodeType::NODE_SET_NAMES) {
					auto re_map { regex_parser.parse1v2() };
					const auto re_vals { re_map["names"] };

					re_val = trim(fold(str_acc, re_vals));
				} else {
					re_val = regex_parser.parse_character_set();
				}

				auto acc_child_vals = [] (MySQLParser::AstNode* const n, const string& s) -> string {
					return s + " " + n->value;
				};
				const string p_val { trim(fold(acc_child_vals, ast.get()->children)) };

				std::cout << "  - RE2 Parser Val: " << re_val << "\n";
				std::cout << "  - AST Parser Val: " << p_val << "\n";

				if (re_val != p_val) {
					std::cout << "WARNING: Mismatch between Regex Parser and AST parser\n";
					failed_matches.push_back(q);
				}
			}

			std::cout << "'MySQL_Session' regexes equivalences:\n";

			char* q_digest { nullptr };
			{
				char* _cmt { nullptr };
				q_digest = mysql_query_digest_and_first_comment_2(q.c_str(), q.size(), &_cmt, nullptr);
			}

			// ProxySQL statement regexes
			{
				bool p_match_1 = p_match_regex_1(ast.get());
				bool r_match_1 = strncasecmp(q_digest, "SET ", 4) == 0 &&
					(
						match_regexes[0].match(const_cast<char*>(q_digest))
						|| strncasecmp(q_digest, "SET NAMES", strlen("SET NAMES")) == 0
						|| strcasestr(q_digest,"autocommit")
					);

				printf("  + Match 1   parser=%d regex=%d\n", p_match_1, r_match_1);

				if (p_match_1 != r_match_1) {
					failed_matches.push_back(q.c_str());
				}
			}

			{
				bool p_match_2 = p_match_regex_2(ast.get());
				bool r_match_2 = strncasecmp(q.c_str(), "SET ", 4) == 0 &&
					match_regexes[1].match(const_cast<char*>(q_digest));

				printf("  + Match 2   parser=%d regex=%d\n", p_match_2, r_match_2);

				if (p_match_2 != r_match_2) {
					failed_matches.push_back(q.c_str());
				}
			}

			{
				bool p_match_3 = p_match_regex_3(ast.get());
				bool r_match_3 = strncasecmp(q.c_str(), "SET ", 4) == 0 &&
					match_regexes[2].match(const_cast<char*>(q_digest));

				printf("  + Match 3   parser=%d regex=%d\n", p_match_3, r_match_3);

				if (p_match_3 != r_match_3) {
					failed_matches.push_back(q.c_str());
				}
			}
		} else {
			std::cout << "Parsing failed:" << std::endl;
			const auto& errors = parser.get_errors();

			if (errors.empty()) {
				std::cout << "  - No specific error, check parser logic or 'mysql_yyerror'." << std::endl;
			} else {
				for (const auto& error : errors) {
					std::cout << " - Error: " << error << std::endl;
				}
			}
		}
	}

	std::cout << "\n";

	for (const auto& f : failed_matches) {
		std::cout << "Match failure   q=\"" << f << "\"\n";
	}

	return failed_matches.size();
}
