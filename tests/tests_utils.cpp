#include "tests_utils.h"
#include "re2/re2.h"

#include <array>
#include <deque>

#include <ctype.h>
#include <string.h>

using std::array;
using std::deque;
using std::string;
using std::vector;

//                              PROXYSQL SYMBOLS
////////////////////////////////////////////////////////////////////////////////

// Symbol required to avoid 'gen_utils.oo' which complicates linking
int remove_spaces(const char *s) {
	char *inp = (char *)s, *outp = (char *)s;
	bool prev_space = false;
	bool fns = false;
	while (*inp) {
		if (isspace(*inp)) {
			if (fns) {
				if (!prev_space) {
					*outp++ = ' ';
					prev_space = true;
				}
			}
		} else {
			*outp++ = *inp;
			prev_space = false;
			if (!fns) fns=true;
		}
		++inp;
	}
	if (outp>s) {
		if (prev_space) {
			outp--;
		}
	}
	*outp = '\0';
	return strlen(s);
}

// Required when linking 'c_tokenizer.oo' for digests
__thread int mysql_thread___query_digests_max_query_length = 65000;
__thread bool mysql_thread___query_digests_lowercase = false;
__thread bool mysql_thread___query_digests_replace_null = true;
__thread bool mysql_thread___query_digests_no_digits = false;
__thread bool mysql_thread___query_digests_keep_comment = false;
__thread int mysql_thread___query_digests_grouping_limit = 3;
__thread int mysql_thread___query_digests_groups_grouping_limit = 1;

////////////////////////////////////////////////////////////////////////////////

//                                 TEST QUERIES
////////////////////////////////////////////////////////////////////////////////

const vector<string> exhaustive_queries {
	"SET @my_user_variable = 123;", // 1
	"SET @my_user_variable = + 123;", // 1
	"SET @my_user_variable = - 123;", // 1
	"SET @my_user_variable = 123, @@GLOBAL.max_connections = 200;", // 2
	"SET @my_custom_var = 'Test Value';", // 3
	"SET P_param_name = 100;", // 4
	"SET my_local_variable = NOW();", // 5
	"SET GLOBAL sort_buffer_size = 512000;", // 6
	"SET @@GLOBAL.sort_buffer_size = 512000;", // 7
	"SET PERSIST max_allowed_packet = 1073741824;", // 8
	"SET @@PERSIST.max_allowed_packet = 1073741824;", // 9
	"SET PERSIST_ONLY sql_mode = 'STRICT_TRANS_TABLES';", // 10
	"SET @@PERSIST_ONLY.sql_mode = 'STRICT_TRANS_TABLES';", // 11
	"SET SESSION sql_select_limit = 100;", // 12
	"SET @@SESSION.sql_select_limit = 100;", // 13
	"SET @@sql_select_limit = 100;", // 14
	"SET sql_select_limit = 100;", // 15
	"SET @generic_var = TRUE OR FALSE;", // 16
	"SET @generic_var = TRUE XOR FALSE;", // 17
	"SET @generic_var = 1 AND 0;", // 18
	"SET @generic_var = NOT TRUE;", // 19
	"SET @generic_var = (5 > 1) IS TRUE;", // 20
	"SET @generic_var = (1 = 0) IS NOT TRUE;", // 21
	"SET @generic_var = (1 = 0) IS FALSE;", // 22
	"SET @generic_var = (5 > 1) IS NOT FALSE;", // 23
	"SET @generic_var = (NULL + 1) IS UNKNOWN;", // 24
	"SET @generic_var = (1 IS NOT NULL) IS NOT UNKNOWN;", // 25
	"SET @generic_var = (col_a < col_b);", // 26
	"SET @generic_var = (0/0) IS NULL;", // 29
	"SET @generic_var = 'hello' IS NOT NULL;", // 30
	"SET @generic_var = (1=1) = ('a' LIKE 'a%');", // 31
	"SET @generic_var = my_value > ALL (SELECT limit_value FROM active_limits WHERE group_id = 'A');", // 32
	"SET @generic_var = (5 BETWEEN 1 AND 10);", // 33
	"SET @generic_var = current_user_id IN (SELECT user_id FROM course_enrollments WHERE course_id = 789);", // 41
	"SET @generic_var = 'PROD123' NOT IN (SELECT product_sku FROM discontinued_products WHERE reason_code = 'OBSOLETE');", // 42
	"SET @generic_var = 5 IN (5);", // 43
	"SET @generic_var = 'apple' IN ('orange', 'apple', 'banana');", // 44
	"SET @generic_var = 10 NOT IN (5);", // 45
	"SET @generic_var = 'grape' NOT IN ('orange', 'apple', 'banana');", // 46
	"SET @generic_var = 'b' MEMBER OF ('[\"a\", \"b\", \"c\"]');", // 47
	"SET @generic_var = 'b' MEMBER ('[\"a\", \"b\", \"c\"]');", // 48
	"SET @generic_var = 7 BETWEEN 5 AND (5 + 5);", // 49
	"SET @generic_var = 3 NOT BETWEEN 5 AND (10 - 2);", // 50
	"SET @generic_var = 'knight' SOUNDS LIKE 'night';", // 51
	"SET @generic_var = 'banana' LIKE 'ba%';", // 52
	"SET @generic_var = 'data_value_100%' LIKE 'data\\_value\\_100\\%' ESCAPE '\\\\';", // 53
	"SET @generic_var = 'apple' NOT LIKE 'ora%';", // 54
	"SET @generic_var = 'test_string%' NOT LIKE 'prod\\_string\\%' ESCAPE '\\\\';", // 55
	"SET @generic_var = 'abcde' REGEXP '^a.c';", // 56
	"SET @generic_var = 'xyz123' NOT REGEXP '[0-9]$';", // 57
	"SET @generic_var = (100 + 200);", // 58
	"SET @generic_var = 5 | 2;", // 61
	"SET @generic_var = 5 & 2;", // 62
	"SET @generic_var = 5 << 1;", // 63
	"SET @generic_var = 10 >> 1;", // 64
	"SET @generic_var = 10.5 + 2;", // 65
	"SET @generic_var = 100 - 33;", // 66
	"SET @generic_var = NOW() + INTERVAL 1 DAY;", // 67
	"SET @generic_var = '2025-12-25' - INTERVAL 2 MONTH;", // 68
	"SET @generic_var = 7 * 6;", // 69
	"SET @generic_var = 100 / 4;", // 70
	"SET @generic_var = 10 % 3;", // 71
	"SET @generic_var = 10 DIV 3;", // 72
	"SET @generic_var = 10 MOD 3;", // 73
	"SET @generic_var = 5 ^ 2;", // 74
	"SET @generic_var = (SELECT SUM(amount) FROM sales WHERE sale_date = CURDATE());" // 75
};

const vector<string> set_queries {
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
};

// cases from 'setparser_test.cpp': extracted via 'ack -o "\"SET.*?\"," $path'
const vector<string> setparser_queries {
	"SET @@sql_mode = 'TRADITIONAL'",
	"SET SESSION sql_mode = 'TRADITIONAL'",
	"SET @@session.sql_mode = 'TRADITIONAL'",
	"SET @@local.sql_mode = 'TRADITIONAL'",
	"SET sql_mode = 'TRADITIONAL'",
	"SET SQL_MODE   ='TRADITIONAL'",
	"SET SQL_MODE  = \"TRADITIONAL\"",
	"SET SQL_MODE  = TRADITIONAL",
	"SET @@SESSION.sql_mode = CONCAT(CONCAT(@@sql_mode, ', STRICT_ALL_TABLES'), ', NO_AUTO_VALUE_ON_ZERO')",
	"SET @@LOCAL.sql_mode = CONCAT(CONCAT(@@sql_mode, ', STRICT_ALL_TABLES'), ', NO_AUTO_VALUE_ON_ZERO')",
	"SET sql_mode = 'NO_ZERO_DATE,STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY'",
	"SET @@sql_mode = CONCAT(@@sql_mode, ',', 'ONLY_FULL_GROUP_BY')",
	"SET @@sql_mode = REPLACE(REPLACE(REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY,', ''),',ONLY_FULL_GROUP_BY', ''),'ONLY_FULL_GROUP_BY', '')",
	"SET @@sql_mode = REPLACE( REPLACE( REPLACE( @@sql_mode, 'ONLY_FULL_GROUP_BY,', ''),',ONLY_FULL_GROUP_BY', ''),'ONLY_FULL_GROUP_BY', '')",
	"SET @@SESSION.sql_mode = CONCAT(CONCAT(@@sql_mode, ', STRICT_ALL_TABLES'), ', NO_AUTO_VALUE_ON_ZERO')",
	"SET SQL_MODE=IFNULL(@@sql_mode,'')",
	"SET SQL_MODE=IFNULL(@old_sql_mode,'')",
	"SET SQL_MODE=IFNULL(@OLD_SQL_MODE,'')",
	"SET sql_mode=(SELECT CONCAT(@@sql_mode, ',PIPES_AS_CONCAT,NO_ENGINE_SUBSTITUTION'))",
	"SET sql_mode=(SELECT CONCAT(@@sql_mode, ',PIPES_AS_CONCAT,NO_ENGINE_SUBSTITUTION')), time_zone = '+00:00', NAMES utf8mb4 COLLATE utf8mb4_unicode_ci",
	"SET sql_mode=''",
	"SET sql_mode=(SELECT CONCA(@@sql_mode, ',PIPES_AS_CONCAT,NO_ENGINE_SUBSTITUTION'))",
	"SET sql_mode=(SELECT CONCAT(@sql_mode, ',PIPES_AS_CONCAT,NO_ENGINE_SUBSTITUTION'))",
	"SET sql_mode=(SELECT CONCAT(@@sql_mode, ',PIPES_AS_CONCAT[,NO_ENGINE_SUBSTITUTION'))",
	"SET sql_mode=(SELCT CONCAT(@@sql_mode, ',PIPES_AS_CONCAT[,NO_ENGINE_SUBSTITUTION'))",
	"SET @@time_zone = 'Europe/Paris'",
	"SET @@time_zone = '+00:00'",
	"SET @@time_zone = \"Europe/Paris\"",
	"SET @@time_zone = \"+00:00\"",
	"SET @@time_zone = @OLD_TIME_ZONE",
	"SET @@TIME_ZONE = @OLD_TIME_ZONE",
	"SET @@session_track_gtids = OFF",
	"SET @@session_track_gtids = OWN_GTID",
	"SET @@SESSION.session_track_gtids = OWN_GTID",
	"SET @@LOCAL.session_track_gtids = OWN_GTID",
	"SET SESSION session_track_gtids = OWN_GTID",
	"SET @@session_track_gtids = ALL_GTIDS",
	"SET @@SESSION.session_track_gtids = ALL_GTIDS",
	"SET @@LOCAL.session_track_gtids = ALL_GTIDS",
	"SET SESSION session_track_gtids = ALL_GTIDS",
	"SET @@character_set_results = utf8",
	"SET @@character_set_results = NULL",
	"SET character_set_results = NULL",
	"SET @@session.character_set_results = NULL",
	"SET @@local.character_set_results = NULL",
	"SET session character_set_results = NULL",
	"SET NAMES utf8",
	"SET NAMES 'utf8'",
	"SET NAMES \"utf8\"",
	"SET NAMES utf8 COLLATE unicode_ci",
	"SET @@SESSION.SQL_SELECT_LIMIT= DEFAULT",
	"SET @@LOCAL.SQL_SELECT_LIMIT= DEFAULT",
	"SET @@SQL_SELECT_LIMIT= DEFAULT",
	"SET SESSION SQL_SELECT_LIMIT   = DEFAULT",
	"SET @@SESSION.SQL_SELECT_LIMIT= 1234",
	"SET @@LOCAL.SQL_SELECT_LIMIT= 1234",
	"SET @@SQL_SELECT_LIMIT= 1234",
	"SET SESSION SQL_SELECT_LIMIT   = 1234",
	"SET @@SESSION.SQL_SELECT_LIMIT= 1234",
	"SET @@LOCAL.SQL_SELECT_LIMIT= 1234",
	"SET @@SESSION.SQL_SELECT_LIMIT= @old_sql_select_limit",
	"SET @@LOCAL.SQL_SELECT_LIMIT= @old_sql_select_limit",
	"SET SQL_SELECT_LIMIT= @old_sql_select_limit",
	"SET @@SESSION.sql_auto_is_null = 0",
	"SET @@LOCAL.sql_auto_is_null = 0",
	"SET SESSION sql_auto_is_null = 1",
	"SET sql_auto_is_null = OFF",
	"SET @@sql_auto_is_null = ON",
	"SET @@SESSION.sql_safe_updates = 0",
	"SET @@LOCAL.sql_safe_updates = 0",
	"SET SESSION sql_safe_updates = 1",
	"SET SQL_SAFE_UPDATES = OFF",
	"SET @@sql_safe_updates = ON",
	"SET time_zone = 'Europe/Paris', sql_mode = 'TRADITIONAL'",
	"SET time_zone = 'Europe/Paris', sql_mode = IFNULL(NULL,\"STRICT_TRANS_TABLES\")",
	"SET sql_mode = 'TRADITIONAL', NAMES 'utf8 COLLATE 'unicode_ci'",
	"SET  @@SESSION.sql_mode = CONCAT(CONCAT(@@sql_mode, ',STRICT_ALL_TABLES'), ',NO_AUTO_VALUE_ON_ZERO'),  @@SESSION.sql_auto_is_null = 0, @@SESSION.wait_timeout = 2147483",
	"SET  @@LOCAL.sql_mode = CONCAT(CONCAT(@@sql_mode, ',STRICT_ALL_TABLES'), ',NO_AUTO_VALUE_ON_ZERO'),  @@SESSION.sql_auto_is_null = 0, @@SESSION.wait_timeout = 2147483",
	"SET NAMES utf8, @@SESSION.sql_mode = CONCAT(REPLACE(REPLACE(REPLACE(@@sql_mode, 'STRICT_TRANS_TABLES', ''), 'STRICT_ALL_TABLES', ''), 'TRADITIONAL', ''), ',NO_AUTO_VALUE_ON_ZERO'), @@SESSION.sql_auto_is_null = 0, @@SESSION.wait_timeout = 3600",
	"SET NAMES utf8, @@LOCAL.sql_mode = CONCAT(REPLACE(REPLACE(REPLACE(@@sql_mode, 'STRICT_TRANS_TABLES', ''), 'STRICT_ALL_TABLES', ''), 'TRADITIONAL', ''), ',NO_AUTO_VALUE_ON_ZERO'), @@LOCAL.sql_auto_is_null = 0, @@LOCAL.wait_timeout = 3600",
	"SET character_set_results=NULL, NAMES latin7, character_set_client='utf8mb4'",
	"SET character_set_results=NULL,NAMES latin7,character_set_client='utf8mb4'"
};

const vector<string> exp_failures {
	// Wrong identifier; should be a valid interval keyword
	"SET @generic_var = (SELECT '2025-12-10') - INTERVAL 2 foo;",
	// Test cases for potential errors or unsupported expressions
	"SET @myvar = some_function(1, 'a');", // 'some_function(...)' is just an identifier for expression_placeholder for now
	"SET global invalid-variable = 100;", // Invalid identifier char (if not quoted)
	"SET @unterminated_string = 'oops",
	"SET =", // Syntax error
	"SET names utf8 collate ;" // Missing collation name
};

const vector<string> valid_sql_mode_subexpr {
	// Valid cases FAILING under REGEX impl
	"SET sql_mode=(SELECT 'foo')",
	"SET sql_mode=(SELECT \"foo\")",
	"SET sql_mode=(SELECT 5)",
	"SET sql_mode=(SELECT NULL)",
	// Valid cases WORKING under REGEX impl
	"SET sql_mode=(SELECT CONCAT(@@sql_mode, NULL))",
	"SET sql_mode=(SELECT CONCAT(@@sql_mode, 'foo'))",
	// Valid cases FAILING under REGEX impl
	"SET sql_mode=(SELECT REPLACE(CONCAT(@@sql_mode, ''), '', (SELECT 'foo')))",
	"SET sql_mode=(SELECT REPLACE(CONCAT(@@sql_mode, ''), '', 5))"
};

// Invalid cases; correctly parsed but denied due to AST properties
const vector<string> invalid_sql_mode_subexpr {
	"SET sql_mode=(SELECT @user_var)",
	"SET sql_mode=(SELECT CONCAT(@@sys_var, 'foo')",
	"SET sql_mode=(SELECT REPLACE(CONCAT(@@sql_mode, ''), '', (SELECT @sys_var)))",
};

////////////////////////////////////////////////////////////////////////////////

//                           PROXYSQL BORROWED CODE
///////////////////////////////////////////////////////////////////////////////

Session_Regex::Session_Regex(char* p) {
	s = strdup(p);
	re2::RE2::Options* opt2 = new re2::RE2::Options(RE2::Quiet);
	opt2->set_case_sensitive(false);
	opt = (void*)opt2;
	re = (RE2*)new RE2(s, *opt2);
}

Session_Regex::~Session_Regex() {
	free(s);
	delete (RE2*)re;
	delete (re2::RE2::Options*)opt;
}

// Modified, should be const, doesn't modify 'this'
bool Session_Regex::match(char* m) const {
	bool rc = false;
	rc = RE2::PartialMatch(m, *(RE2*)re);
	return rc;
}

const array<Session_Regex, 3> match_regexes {
	const_cast<char*>("^SET (|SESSION |@@|@@session.|@@local.)`?(character_set_results|character_set_connection|character_set_client|character_set_database|collation_connection|placeholder|aurora_read_replica_read_committed|auto_increment_increment|auto_increment_offset|big_tables|default_storage_engine|default_tmp_storage_engine|foreign_key_checks|group_concat_max_len|group_replication_consistency|gtid_next|innodb_lock_wait_timeout|innodb_strict_mode|innodb_table_locks|join_buffer_size|lc_messages|lc_time_names|lock_wait_timeout|log_slow_filter|long_query_time|max_execution_time|max_heap_table_size|max_join_size|max_sort_length|max_statement_time|optimizer_prune_level|optimizer_search_depth|optimizer_switch|optimizer_use_condition_selectivity|profiling|query_cache_type|sort_buffer_size|sql_auto_is_null|sql_big_selects|sql_generate_invisible_primary_key|sql_log_bin|sql_mode|sql_quote_show_create|sql_require_primary_key|sql_safe_updates|sql_select_limit|time_zone|timestamp|tmp_table_size|unique_checks|wsrep_osu_method|wsrep_sync_wait|interactive_timeout|wait_timeout|net_read_timeout|net_write_timeout|net_buffer_length|read_buffer_size|read_rnd_buffer_size|session_track_schema|session_track_system_variables|SESSION_TRACK_GTIDS|TX_ISOLATION|TX_READ_ONLY|TRANSACTION_ISOLATION|TRANSACTION_READ_ONLY)`?( *)(:|)=( *)"),
	const_cast<char*>("^SET(?: +)(|SESSION +)TRANSACTION(?: +)(?:(?:(ISOLATION(?: +)LEVEL)(?: +)(REPEATABLE(?: +)READ|READ(?: +)COMMITTED|READ(?: +)UNCOMMITTED|SERIALIZABLE))|(?:(READ)(?: +)(WRITE|ONLY)))"),
	const_cast<char*>("^(set)(?: +)((charset)|(character +set))(?: )")
};

///////////////////////////////////////////////////////////////////////////////

//                             Generic Utilities
///////////////////////////////////////////////////////////////////////////////

string trim(const string& s) {
    string r { s };

    r.erase(0, r.find_first_not_of(" \n\r\t"));
    r.erase(r.find_last_not_of(" \n\r\t") + 1);

    return r;
}

string rm_outer_parens(const string& s) {
	if (s.size() < 2) {
		return s;
	} else {
		if (s.front() == '(' && s.back() == ')') {
			return s.substr(1, s.size() - 2);
		} else {
			return s;
		}
	}
}

///////////////////////////////////////////////////////////////////////////////

//                             SET parsing utils
///////////////////////////////////////////////////////////////////////////////

using MySQLParser::NodeType;

const s_vector<string> tracked_vars {
	"character_set_results",
	"character_set_connection",
	"character_set_client",
	"character_set_database",
	"collation_connection",
	"placeholder",
	"aurora_read_replica_read_committed",
	"auto_increment_increment",
	"auto_increment_offset",
	"big_tables",
	"default_storage_engine",
	"default_tmp_storage_engine",
	"foreign_key_checks",
	"group_concat_max_len",
	"group_replication_consistency",
	"gtid_next",
	"innodb_lock_wait_timeout",
	"innodb_strict_mode",
	"innodb_table_locks",
	"join_buffer_size",
	"lc_messages",
	"lc_time_names",
	"lock_wait_timeout",
	"log_slow_filter",
	"long_query_time",
	"max_execution_time",
	"max_heap_table_size",
	"max_join_size",
	"max_sort_length",
	"max_statement_time",
	"optimizer_prune_level",
	"optimizer_search_depth",
	"optimizer_switch",
	"optimizer_use_condition_selectivity",
	"profiling",
	"query_cache_type",
	"sort_buffer_size",
	"sql_auto_is_null",
	"sql_big_selects",
	"sql_generate_invisible_primary_key",
	"sql_log_bin",
	"sql_mode" ,
	"sql_quote_show_create",
	"sql_require_primary_key",
	"sql_safe_updates",
	"sql_select_limit",
	"time_zone",
	"timestamp",
	"tmp_table_size",
	"unique_checks",
	"wsrep_osu_method",
	"wsrep_sync_wait",
	"SESSION_TRACK_GTIDS",
	"TX_ISOLATION",
	"TX_READ_ONLY",
	"TRANSACTION_ISOLATION",
	"TRANSACTION_READ_ONLY",
	// mysql_ignored_variables
	"wait_timeout",
	"net_read_timeout",
	"net_write_timeout",
	"net_buffer_length",
	"read_buffer_size",
	"read_rnd_buffer_size",
};

vector<const MySQLParser::AstNode*> ext_vars_assigns(const MySQLParser::AstNode* root) {
	if (root == nullptr) { return {}; }

	vector<const MySQLParser::AstNode*> result {};
	deque<pair<const MySQLParser::AstNode*, size_t>> queue {{ root, 0 }};
	size_t target_depth { size_t(-1) };

	for (; !queue.empty(); queue.pop_front()) {
		const auto& current { queue.front() };
		const MySQLParser::AstNode* node = current.first;
		size_t depth = current.second;

		if (node->type == MySQLParser::NodeType::NODE_VARIABLE_ASSIGNMENT) {
			if (target_depth == size_t(-1)) {
				target_depth = depth;
				result.push_back(node);
			} else if (depth == target_depth) {
				result.push_back(node);
			} else if (depth < target_depth) {
				continue;
			} else {
				break;
			}
		}

		for (const auto& child : node->children) {
			queue.push_back({child, depth + 1});
		}
	}

	return result;
}

template <typename T>
using rc_t = std::pair<int,T>;
using child_idx_t = std::pair<NodeType, size_t>;

rc_t<const MySQLParser::AstNode*> get_node(
	const MySQLParser::AstNode* root, const vector<child_idx_t>& c_path
) {
	const MySQLParser::AstNode* cur_node { root };

	for (const auto& c_idx : c_path) {
		if (cur_node->children.size() && c_idx.second < cur_node->children.size()) {
			cur_node = cur_node->children[c_idx.second];

			if (c_idx.first == MySQLParser::NodeType::NODE_UNKNOWN) {
				continue;
			} else if (cur_node->type != c_idx.first) {
				return { -1, cur_node };
			}
		} else {
			return { -1, cur_node };
		}
	}

	return { 0, cur_node };
}

/**
 * @brief Checks if a var assign within a  'set statement' has 'session' scope.
 * @param node The NODE_VARIABLE_ASSIGNMENT from which to start the check.
 * @return A pair with shape { err_code, bool_res }.
 */
rc_t<bool> check_sys_var(const MySQLParser::AstNode* node) {
	using MySQLParser::NodeType;

	if (node->type != NodeType::NODE_VARIABLE_ASSIGNMENT) {
		return { -1, false };
	}

	const auto scope { get_node(node,
		{{ NodeType::NODE_SYSTEM_VARIABLE, 0 }, { NodeType::NODE_VARIABLE_SCOPE, 0 }})
	};

	if (!scope.second) {
		return { 0, false };
	} else {
		return {
			0,
			// no scope found; just check kind since scope defaults to SESSION
			scope.second->type == NodeType::NODE_SYSTEM_VARIABLE
			// found scope, match is required
			|| scope.second->value == "SESSION"
		};
	}
}

// Binary search with case-insensitive comparison
bool binary_search_ci(const std::vector<std::string>& vec, const std::string& key) {
	const auto it = std::lower_bound(vec.begin(), vec.end(), key,
		[] (const string& s1, const string& s2) -> bool {
			return strcasecmp(s1.c_str(), s2.c_str()) < 0;
		}
	);
	return it != vec.end() && strcasecmp(it->c_str(), key.c_str()) == 0;
}

bool p_match_regex_1(const MySQLParser::AstNode* node) {
	using MySQLParser::NodeType;

	if (node->type != NodeType::NODE_SET_STATEMENT && node->type != NodeType::NODE_SET_NAMES) {
		return false;
	}

	if (node->type == NodeType::NODE_SET_STATEMENT) {
		const auto vars_assings { ext_vars_assigns(node) };
		// Not a SET with assignments
		if (vars_assings.empty()) { return false; }

		for (const auto& v : vars_assings) {
			// Not a tracked system variable; user defined, etc...
			if (!check_sys_var(v).second) {
				return false;
			} else {
				const auto sys_var { get_node(v, {{ NodeType::NODE_SYSTEM_VARIABLE, 0 }}) };
				const auto is_tracked { binary_search_ci(tracked_vars.vals, sys_var.second->value) };

				if (!is_tracked && sys_var.second->value != "autocommit") {
					return false;
				}
			}
		}

		return true;
	} else {
		return node->type == NodeType::NODE_SET_NAMES;
	}
}

bool p_match_regex_2(const MySQLParser::AstNode* node) {
	using MySQLParser::NodeType;

	if (node->type != NodeType::NODE_SET_STATEMENT) {
		return false;
	} else {
		return node->value == "SET_SESSION_TRANSACTION"
			|| node->value == "SET_TRANSACTION";
	}
}

bool p_match_regex_3(const MySQLParser::AstNode* node) {
	using MySQLParser::NodeType;

	return node->type == NodeType::NODE_SET_CHARSET;
}

//                         Special Variable Handling
///////////////////////////////////////////////////////////////////////////////

// Mimic/Improve ProxySQL behavior for handling 'sql_mode'. Subselects for this specific variable
// should be verified by syntax. This will already improve the current handling, checking content is
// probably a non-worthy effort, since different MySQL versions allow different values. We could
// still hold a simple list and check that "all are known".

string acc_node_idx(const child_idx_t& c, const string& s) {
	const string res { "(" + to_string(c.first) + "," + std::to_string(c.second) + ")" };

	if (s.empty()) {
		return res;
	} else {
		return s + "," + res;
	}
}

// Any recurring structure of the following kind should be validated:
//
// SELECT_STMT
//  | SELECT_OPTIONS
//  | SELECT_ITEM_LIST
//  `-- SELECT_ITEM
//      `-- EXPR, Value: 'FUNC_CALL:REPLACE'
//      +   |-- IDENTIFIER, Value: 'REPLACE'
//      +   |-- EXPR, Value: 'expr_list_wrapper'
//      +       `-- Type: EXPR, Value: 'FUNC_CALL:CONCAT'
//      +       |   |-- Type: IDENTIFIER, Value: 'CONCAT'
//      +       |   |-- Type: EXPR, Value: 'expr_list_wrapper'
//      +       |   |   | -- Type: SYSTEM_VAR, Value: 'sql_mode'
//      +       |   |   ` -- Type: STRING_LITERAL, Value: ',PIPES_AS_CONCAT'
//      +       |-- Type: STRING_LITERAL
//      +       `-- Type: STRING_LITERAL
//      `-- SYSTEM_VAR, Value: sql_mode
pair<bool,string> verf_sql_mode_val(const string& subexpr) {
	MySQLParser::Parser parser;
	std::unique_ptr<MySQLParser::AstNode> ast { parser.parse(rm_outer_parens(subexpr)) };

	if (ast) {
		const vector<child_idx_t> sel_rte {
			{ NodeType::NODE_SELECT_ITEM_LIST, 1 },
			{ NodeType::NODE_SELECT_ITEM, 0 },
			{ NodeType::NODE_UNKNOWN, 0 }
		};
		const auto rc_child { get_node(ast.get(), sel_rte) };
		const auto valid_sys_var = [] (const MySQLParser::AstNode* n) -> bool {
			const auto scope { get_node(n, {{ NodeType::NODE_VARIABLE_SCOPE, 0 }}) };

			return
				n->type == NodeType::NODE_SYSTEM_VARIABLE
				&& n->value == "sql_mode"
				&& (scope.first == -1 || scope.second->value == "SESSION");
		};

		if (rc_child.first) {
			if (rc_child.second) {
				return { false, "Invalid subquery, expected SUB-SELECT   node=\"" + to_string(rc_child.second->type) + "\"" };
			} else {
				return { false, "Invalid subquery, expected SUB-SELECT" };
			}
		} else {
			const auto& type = rc_child.second->type;

			if (type == NodeType::NODE_EXPR) {
				const auto valid_fn_name = [] (const string& n) -> bool {
					return n == "REPLACE" || n == "CONCAT" || n == "IFNULL";
				};
				const auto valid_fn_expr = [&valid_fn_name] (const MySQLParser::AstNode* n) -> pair<bool,string> {
					// EXPR: (IDENTIFIER, EXPR ('expr_list_wrapper'))
					if (n->children.size() != 2) {
						return { false, "Invalid expr, function call expected   type=\"" + to_string(n->type) + "\"" };
					}

					const bool is_func_expr { n->value.substr(0, n->value.find(':')) == "FUNC_CALL" };
					const string fn_name { n->value.substr(n->value.find(':') + 1) };
					const bool allowed { valid_fn_name(fn_name) };

					if (!is_func_expr || !allowed) {
						return { false, "Invalid function   FN_NAME=\"" + fn_name + "\"" };
					} else {
						const rc_t<const MySQLParser::AstNode*> id { get_node(n, {{ NodeType::NODE_IDENTIFIER, 0 }}) };
						const rc_t<const MySQLParser::AstNode*> subexpr { get_node(n, {{ NodeType::NODE_EXPR, 1 }}) };
						const bool valid_ast { !id.first && !subexpr.first };

						const string err_msg { valid_ast ? "" :
							"Found invalid AST for function   "
								"fn_name=\"" + fn_name + "\""
								" id=\"" + std::to_string(id.first) + "\""
								" subexpr=\"" + std::to_string(subexpr.first) + "\""
						};

						return { valid_ast, err_msg };
					}
				};
				const auto valid_fn_param = [] (const MySQLParser::AstNode* c) -> bool {
					if (
						c->type != NodeType::NODE_STRING_LITERAL
						&& c->type != NodeType::NODE_NUMBER_LITERAL
						&& c->type != NodeType::NODE_BOOLEAN_LITERAL
						&& c->type != NodeType::NODE_NULL_LITERAL
						&& c->type != NodeType::NODE_VALUE_LITERAL
						&& c->type != NodeType::NODE_EXPR
					) {
						if (c->type != NodeType::NODE_SYSTEM_VARIABLE || c->value != "sql_mode") {
							return false;
						}
					}

					return true;
				};
				// Verifies simple subexpr selects - (SELECT 'str_literal')
				const auto valid_select_subexpr = [] (const string& q, const MySQLParser::AstNode* c) -> pair<bool,string> {
					if (c->type != NodeType::NODE_SELECT_RAW_SUBQUERY) {
						return { false, "Invalid node type found   type=\"" + to_string(c->type) + "\"" };
					} else {
						const string sub_select {
							q.substr(c->val_init_pos, c->val_end_pos - c->val_init_pos)
						};

						MySQLParser::Parser parser;
						std::unique_ptr<MySQLParser::AstNode> ast {
							parser.parse(rm_outer_parens(sub_select))
						};

						if (ast) {
							const auto rc_node {
								get_node(ast.get(), {
									{ NodeType::NODE_SELECT_ITEM_LIST, 1 },
									{ NodeType::NODE_SELECT_ITEM, 0 },
									{ NodeType::NODE_STRING_LITERAL, 0 }
								})
							};

							if (!rc_node.first) {
								return { true, "" };
							} else {
								return { false, "Not allowed AST found for SELECT SUBEXPR" };
							}
						} else {
							const auto acc_err = [] (const string& s1, const string s2) {
								return s2 + "," + s1;
							};
							return { false,
								"Failed to parse select subexpr"
									"   error=\"" + fold(acc_err, parser.get_errors()) + "\""
							};
						}
					}
				};

				// Check that exprs are a succession of function calls, allowing only '@@sql_mode'
				// and literals as external data source:
				// ...
				//  `-- SELECT_ITEM
				//      `-- EXPR, Value: 'FUNC_CALL:REPLACE'
				//      +   |-- IDENTIFIER, Value: 'REPLACE'
				//      +   `-- EXPR, Value: 'expr_list_wrapper'
				//      +       |-- Type: EXPR, Value: 'FUNC_CALL:CONCAT'
				//      +       |   |-- Type: IDENTIFIER, Value: 'CONCAT'
				//      +       |   `-- Type: EXPR, Value: 'expr_list_wrapper'
				//      +       |       | -- Type: SYSTEM_VAR, Value: 'sql_mode'
				//      +       |       ` -- Type: STRING_LITERAL, Value: ',PIPES_AS_CONCAT'
				//      +       |-- Type: STRING_LITERAL
				//      +       `-- Type: STRING_LITERAL
				// ...
				const auto verf_select_item = [&] (const MySQLParser::AstNode* n) -> pair<bool,string> {
					// Either SYS_VAR or FUNC_EXPR
					const bool is_func { n->value.substr(0, n->value.find(':')) == "FUNC_CALL" };
					const bool is_sys_var { n->type == NodeType::NODE_SYSTEM_VARIABLE };

					if (is_func) {
						const auto fn_expr_res { valid_fn_expr(n) };

						if (!fn_expr_res.first) {
							return fn_expr_res;
						}
					} else if (is_sys_var) {
						const auto sys_var_res { valid_sys_var(n) };

						if (!sys_var_res) {
							return { sys_var_res, "Invalid SYS_VAR found in SELECT expr" };
						}
					} else {
						return { false, "Invalid subexpr, expected SYS_VAR or FUNCTION call" };
					}

					deque<const MySQLParser::AstNode*> n_queue { n };

					while (n_queue.size()) {
						const MySQLParser::AstNode* cur { n_queue.front() };
						n_queue.pop_front();

						const bool is_func { cur->value.substr(0, cur->value.find(':')) == "FUNC_CALL" };

						if (cur->type == NodeType::NODE_SELECT_RAW_SUBQUERY) {
							const auto is_valid_subselect { valid_select_subexpr(subexpr, cur) };

							if (!is_valid_subselect.first) {
								return is_valid_subselect;
							}
						} else if (is_func) {
							const auto fn_expr_res { valid_fn_expr(cur) };

							if (!fn_expr_res.first) {
								return fn_expr_res;
							}
						} else {
							const auto is_valid_fn_param { valid_fn_param(cur) };

							if (!is_valid_fn_param) {
								return {
									false, "Found invalid fn param   type=\"" + to_string(cur->type) + "\""
								};
							}
						}

						// Jumping point to next verf state: S -> S1
						if (cur->type == NodeType::NODE_EXPR) {
							const auto rc_subexpr { get_node(cur, {{ NodeType::NODE_EXPR, 1 }}) };

							for (const MySQLParser::AstNode* c : rc_subexpr.second->children) {
								n_queue.push_back(c);
							}
						}
					}

					return { true, "" };
				};

				const auto verf_res { verf_select_item(rc_child.second) };

				return verf_res;
			} else if (type == NodeType::NODE_SYSTEM_VARIABLE) {
				const bool verf_res { valid_sys_var(rc_child.second) };
				const string err_msg { verf_res ? "" : "Failed to verify system variable" };

				return { verf_res, err_msg };
			} else if (type == NodeType::NODE_STRING_LITERAL) {
				// TODO: We assume a correct literal on user side; should we do better?
				const bool verf_res { valid_sys_var(rc_child.second) };
				const string err_msg { verf_res ? "" : "Failed to verify system variable" };

				return { true, "" };
			} else {
				const string s_route { fold(acc_node_idx, sel_rte) };
				return {
					false,
					"Invalid node found in subquery   "
						"type=\"" + to_string(type) + "\" route:\"" + s_route + "\""
				};
			}
		}
	} else {
		const auto& errors = parser.get_errors();

		if (errors.empty()) {
			return { false, "No specific error, check parser logic or 'mysql_yyerror'" };
		} else {
			string errs { "[" };

			for (const auto& error : errors) {
				errs += "`" + error + "`";

				if (&error != &errors.back()) {
					errs += ",";
				}
			}

			errs += "]";

			return { false, errs };
		}
	}

	return {};
}

///////////////////////////////////////////////////////////////////////////////
