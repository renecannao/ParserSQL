#ifndef __TEST_UTILS_H
#define __TEST_UTILS_H

#include "mysql_parser/mysql_parser.h"

#include <string.h>

#include <array>
#include <numeric>
#include <string>
#include <utility>
#include <vector>

using std::pair;
using std::string;
using std::vector;

//                              PROXYSQL SYMBOLS
////////////////////////////////////////////////////////////////////////////////

int remove_spaces(const char *s);

////////////////////////////////////////////////////////////////////////////////

//                                 TEST QUERIES
////////////////////////////////////////////////////////////////////////////////

extern const vector<string> exhaustive_queries;
extern const vector<string> set_queries;
extern const vector<string> setparser_queries;
extern const vector<string> exp_failures;
extern const vector<string> valid_sql_mode_subexpr;
extern const vector<string> invalid_sql_mode_subexpr;

////////////////////////////////////////////////////////////////////////////////

//                           PROXYSQL BORROWED CODE
///////////////////////////////////////////////////////////////////////////////

class Session_Regex {
private:
	void* opt;
	void* re;
	char* s;
public:
	Session_Regex(char* p);
	Session_Regex(const Session_Regex&) = delete;
	Session_Regex(Session_Regex&) = delete;
	~Session_Regex();
	Session_Regex& operator=(const Session_Regex&) = delete;
	Session_Regex& operator=(Session_Regex&) = delete;
	bool match(char* m) const;
};

extern const std::array<Session_Regex, 3> match_regexes;

///////////////////////////////////////////////////////////////////////////////

//                             Generic Utilities
///////////////////////////////////////////////////////////////////////////////

std::string trim(const std::string& s);
std::string rm_outer_parens(const std::string& s);

template<class T>
struct rm_cvref
{
    using type = std::remove_cv_t<std::remove_reference_t<T>>;
};

template< class T >
using rm_cvref_t = typename rm_cvref<T>::type;

template <class T>
struct _h_fold : _h_fold<decltype(&T::operator())>
{};

template <class C, class R, class B, class A>
struct _h_fold<R(C::*)(A, B) const>
{
	template <template <class> class T, typename F>
	R operator()(const F& f, const T<rm_cvref_t<A>>& v) {
		const auto r_args = [&f] (auto& a, auto& b) { return f(b, a); };
		return std::accumulate(v.begin(), v.end(), B {}, r_args);
	}
};

template <class F, class T>
inline constexpr auto fold(const F& f, T&& v) {
	return _h_fold<F>()(f, std::forward<T>(v));
}

template <class R, class A, class B, class T>
inline constexpr auto fold(R(*f)(A, B), T&& v) {
	const auto r_args = [&f] (auto& a, auto& b) { return f(b, a); };
	return std::accumulate(v.begin(), v.end(), B {}, r_args);
}

///////////////////////////////////////////////////////////////////////////////

//                             SET parsing utils
///////////////////////////////////////////////////////////////////////////////

template <class T>
vector<T> sort_vec(vector<T>&& s) {
	std::sort(s.begin(), s.end());
	return s;
}

inline vector<string> sort_vec(vector<string>&& s) {
	const auto f_str_cmp = [] (const auto& s1, const auto& s2) {
		return strcasecmp(s1.c_str(), s2.c_str()) < 0;
	};
	std::sort(s.begin(), s.end(), f_str_cmp);
	return s;
}

template <class T>
struct s_vector {
	const vector<T> vals;

	s_vector(std::initializer_list<T>&& i) : vals(sort_vec(vector<T>(std::move(i))))
	{}

	s_vector(vector<T>&& v) : vals(sort_vec(std::move(v)))
	{}

	s_vector(const vector<T>&) = delete;
	s_vector& operator=(const vector<T>&) = delete;
	s_vector& operator=(vector<T>&&) = delete;
};

extern const s_vector<string> tracked_vars;

///////////////////////////////////////////////////////////////////////////////

bool binary_search_ci(const std::vector<std::string>& vec, const std::string& key);
vector<const MySQLParser::AstNode*> ext_vars_assigns(const MySQLParser::AstNode* root);

template <typename T>
using rc_t = std::pair<int,T>;
using child_idx_t = std::pair<MySQLParser::NodeType, size_t>;

rc_t<const MySQLParser::AstNode*> get_node(
    const MySQLParser::AstNode* root, const vector<child_idx_t>& c_path
);

bool p_match_regex_1(const MySQLParser::AstNode* node);
bool p_match_regex_2(const MySQLParser::AstNode* node);
bool p_match_regex_3(const MySQLParser::AstNode* node);

//                         Special Variable Handling
///////////////////////////////////////////////////////////////////////////////

pair<bool,string> verf_sql_mode_val(const string& subexpr);

#endif // __TEST_UTILS_H
