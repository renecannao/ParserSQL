#include "MySQL_Set_Stmt_Parser.h"
#include "c_tokenizer.h"

#include "mysql_parser/mysql_parser.h"
#include "tests_utils.h"

#include <chrono>
#include <fstream>
#include <iostream>
#include <random>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>
#include <re2/re2.h>

typedef std::chrono::high_resolution_clock hrc;
#define nano_cast(d) ( std::chrono::duration_cast<std::chrono::nanoseconds>(d) )

#define _TO_S(s) ( std::to_string(s) )

using std::pair;
using std::fstream;
using std::string;
using std::vector;

vector<string> get_tests_queries() {
	vector<string> test_qs {};

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
			return {};
		}

		string next_line {};

		while (std::getline(logfile_fs, next_line)) {
			nlohmann::json j_next_line = nlohmann::json::parse(next_line);
			test_qs.push_back(j_next_line["query"]);
		}
	}

	vector<string> r_test_qs { test_qs };

	// Increase the dataset size by a factor of N
	{
		r_test_qs.insert(r_test_qs.end(), test_qs.begin(), test_qs.end());
		r_test_qs.insert(r_test_qs.end(), test_qs.begin(), test_qs.end());
		r_test_qs.insert(r_test_qs.end(), test_qs.begin(), test_qs.end());
		r_test_qs.insert(r_test_qs.end(), test_qs.begin(), test_qs.end());

		std::random_device rd;
		std::mt19937 g(rd());

		std::shuffle(r_test_qs.begin(), r_test_qs.end(), g);
	}

	return r_test_qs;
}

vector<bool> gen_rnd_vec(size_t sz) {
	const size_t res_sz { sz % 2 == 0 ? sz : sz + 1 };
	vector<bool> res {};

	for (size_t i = 0; i < res_sz; i++) {
		if (i < res_sz / 2) {
			res.push_back(0);
		} else {
			res.push_back(1);
		}
	}

	{
		std::random_device rd;
		std::mt19937 g(rd());
		std::shuffle(res.begin(), res.end(), g);
	}

	return res;
}

vector<pair<const MySQLParser::AstNode*,string>> ext_parse_vals(MySQLParser::Parser& p, const string& q) {
	vector<pair<const MySQLParser::AstNode*,string>> res {};
	std::unique_ptr<MySQLParser::AstNode> ast { p.parse(q) };

	if (ast) {
		const auto var_assigns { ext_vars_assigns(ast.get()) };

		for (const MySQLParser::AstNode* v : var_assigns) {
			const string p_val { q.substr(v->val_init_pos - 1, v->val_end_pos - v->val_init_pos) };
			res.push_back({ v, std::move(p_val) });
		}
	}

	return res;
}

enum class regex_type {
	REGEX_MATCH_1,
	REGEX_MATCH_2,
	REGEX_MATCH_3
};

pair<vector<regex_type>,uint64_t> get_regex_bis_matches(const vector<string>& queries) {
	MySQLParser::Parser parser;

	vector<regex_type> res {};
	res.reserve(queries.size());

	hrc::time_point start;
	hrc::time_point end;

	const auto parse_and_match = [&parser,&res] (const vector<string>& queries) -> void {
		for (const string& q : queries) {
			std::unique_ptr<MySQLParser::AstNode> ast { parser.parse(q) };

			if (ast) {
				if (p_match_regex_1(ast.get())) {
					res.push_back(regex_type::REGEX_MATCH_1);
				} else if (p_match_regex_2(ast.get())) {
					res.push_back(regex_type::REGEX_MATCH_2);
				} else if (p_match_regex_3(ast.get())) {
					res.push_back(regex_type::REGEX_MATCH_3);
				}
			}
		}
	};

	const auto match_only = [&res] (const vector<std::unique_ptr<MySQLParser::AstNode>>& nodes) -> void {
		for (const auto& ast : nodes) {
			if (ast) {
				if (p_match_regex_1(ast.get())) {
					res.push_back(regex_type::REGEX_MATCH_1);
				} else if (p_match_regex_2(ast.get())) {
					res.push_back(regex_type::REGEX_MATCH_2);
				} else if (p_match_regex_3(ast.get())) {
					res.push_back(regex_type::REGEX_MATCH_3);
				}
			}
		}
	};

	const char* check_type = getenv("NO_PARSE_MEASUREMENT");
	vector<std::unique_ptr<MySQLParser::AstNode>> nodes {};

	if (check_type && strcasecmp(check_type, "1") == 0) {
		for (const string& q : queries) {
			nodes.push_back(parser.parse(q));
		}
	}

	start = hrc::now();

	if (check_type && strcasecmp(check_type, "1") == 0) {
		match_only(nodes);
	} else {
		parse_and_match(queries);
	}

	end = hrc::now();

	return { res, nano_cast(end - start).count() };
}

pair<vector<regex_type>,uint64_t> get_regex_re2_matches(const vector<string>& queries) {
	vector<regex_type> res {};
	res.reserve(queries.size());

	hrc::time_point start;
	hrc::time_point end;

	start = hrc::now();

	for (const string& q : queries) {
		if (
			strncasecmp(q.c_str(), "SET ", 4) == 0 &&
			(
				match_regexes[0].match(const_cast<char*>(q.c_str()))
				|| strncasecmp(q.c_str(), "SET NAMES", strlen("SET NAMES")) == 0
				|| strcasestr(q.c_str(),"autocommit")
			)
		) {
			res.push_back(regex_type::REGEX_MATCH_1);
		} else if (
			strncasecmp(q.c_str(), "SET ", 4) == 0 &&
			match_regexes[1].match(const_cast<char*>(q.c_str()))
		) {
			res.push_back(regex_type::REGEX_MATCH_2);
		} else if (
			strncasecmp(q.c_str(), "SET ", 4) == 0 &&
			match_regexes[2].match(const_cast<char*>(q.c_str()))
		) {
			res.push_back(regex_type::REGEX_MATCH_3);
		}
	}

	end = hrc::now();

	return { res, nano_cast(end - start).count() };
}

enum class perf_mode {
	PERF_PARSE,
	PERF_MATCH
};

void cmp_parse_perf(const vector<string>& tests_queries) {
	MySQLParser::Parser bis_parser;
	MySQL_Set_Stmt_Parser re2_parser("");

	vector<vector<pair<const MySQLParser::AstNode*,string>>> bis_res {};
	bis_res.reserve(tests_queries.size());

	vector<std::map<std::string,std::vector<std::string>>> re2_res {};
	re2_res.reserve(tests_queries.size());

	vector<uint64_t> bis_durs {};
	vector<uint64_t> re2_durs {};
	vector<bool> checks_order { gen_rnd_vec(10) };

	hrc::time_point start;
	hrc::time_point end;

	for (bool bis_first : checks_order) {
		if (bis_first) {
			start = hrc::now();

			for (const string& q : tests_queries) {
				bis_res.push_back(ext_parse_vals(bis_parser, q));
			}

			end = hrc::now();

			bis_durs.push_back(nano_cast(end - start).count());
		} else {
			start = hrc::now();

			for (const string& q : tests_queries) {
				re2_parser.set_query(q);
				re2_res.push_back(re2_parser.parse1v2());
			}

			end = hrc::now();

			re2_durs.push_back(nano_cast(end - start).count());
		}
	}

	double bis_avg { std::reduce(bis_durs.begin(), bis_durs.end()) / double(bis_durs.size()) };
	double re2_avg { std::reduce(re2_durs.begin(), re2_durs.end()) / double(re2_durs.size()) };

	std::cout << "QueryCount:    " << tests_queries.size() << "\n";
	std::cout << "BISON(ns):     " << bis_avg << "\n";
	std::cout << "RE2(ns):       " << re2_avg << "\n";
	std::cout << "RATIO(RE2/B):  " << double(re2_avg) / bis_avg  << "\n";
	std::cout << "BISON(ns/q):   " << bis_avg / tests_queries.size() << "\n";
	std::cout << "RE2(ns/q):     " << re2_avg / tests_queries.size() << "\n";
}

void cmp_match_perf(const vector<string>& tests_queries) {
	const auto get_digest = [](const string& q) {
		const char* q_digest { nullptr };

		{
			char* _cmt { nullptr };
			q_digest = mysql_query_digest_and_first_comment_2(q.c_str(), q.size(), &_cmt, nullptr);
		}

		return string { q_digest };
	};
	vector<string> tests_digests {};
	std::transform(
		tests_queries.begin(), tests_queries.end(), std::back_inserter(tests_digests), get_digest
	);

	vector<bool> checks_order { gen_rnd_vec(10) };
	vector<uint64_t> bis_durs {};
	vector<uint64_t> re2_durs {};

	for (bool bis_first : checks_order) {
		if (bis_first) {
			const auto bis_res { get_regex_bis_matches(tests_queries) };
			bis_durs.push_back(bis_res.second);
		} else {
			const auto re2_res { get_regex_re2_matches(tests_digests) };
			re2_durs.push_back(re2_res.second);
		}
	}

	double bis_avg { std::reduce(bis_durs.begin(), bis_durs.end()) / double(bis_durs.size()) };
	double re2_avg { std::reduce(re2_durs.begin(), re2_durs.end()) / double(re2_durs.size()) };

	std::cout << "QueryCount:    " << tests_queries.size() << "\n";
	std::cout << "BISON(ns):     " << bis_avg << "\n";
	std::cout << "RE2(ns):       " << re2_avg << "\n";
	std::cout << "RATIO(RE2/B):  " << double(re2_avg) / bis_avg  << "\n";
	std::cout << "BISON(ns/q):   " << bis_avg / tests_queries.size() << "\n";
	std::cout << "RE2(ns/q):     " << re2_avg / tests_queries.size() << "\n";
}

int main(int argc, char** argv) {
	perf_mode mode { perf_mode::PERF_PARSE };

	if (argc == 2 && strcasecmp(argv[1], "PARSE") == 0) {
		mode = perf_mode::PERF_PARSE;
	} else if (argc == 2 && strcasecmp(argv[1], "MATCH") == 0) {
		mode = perf_mode::PERF_MATCH;
	} else if (argc >= 2) {
		fprintf(stderr, "Invalid params supplied   mode=\"%s\"", argv[1]);
		return 1;
	}

	const auto tests_queries { get_tests_queries() };

	if (mode == perf_mode::PERF_PARSE) {
		cmp_parse_perf(tests_queries);
	} else {
		cmp_match_perf(tests_queries);
	}
}
