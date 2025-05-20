%option reentrant noyywrap nounput noinput batch case-insensitive
%option prefix="mysql_yy"
%option extra-type="MysqlParser::Parser*"

%{
#define ECHO /* This makes ECHO do nothing */
// C++ code to be included in the generated lexer
#include "mysql_parser/mysql_parser.h"   // For MysqlParser::Parser, yyscan_t
#include "mysql_parser/mysql_ast.h"      // For MysqlParser::AstNode, etc.
#include "mysql_parser.tab.h"           // Bison-generated: token enums, defines union MYSQL_YYSTYPE
#include <string>
#include <vector>

union MYSQL_YYSTYPE;
#undef YY_DECL
#define YY_DECL int mysql_yylex (union MYSQL_YYSTYPE *yylval_param, yyscan_t yyscanner, MysqlParser::Parser* parser_context)

#define SAVE_TOKEN_STRING yylval_param->str_val = new std::string(yytext)
%}

%x COMMENT
%x SQSTRING
%x DQSTRING
%x BTIDENT

%%
 /* Rules for the lexer */

<INITIAL>{
  "/*"                  { BEGIN(COMMENT); }
  "-- ".* { /* MySQL -- comment (note space); ignore */ }
  "--\n"                { /* MySQL -- comment followed by newline; ignore */ }
  "#".* { /* MySQL # comment; ignore */ }

  [ \t\n\r]+            { /* Ignore whitespace and carriage returns */ }

  /* Keywords - Specific keywords must come BEFORE the generic identifier rule */
  "SELECT"              { return TOKEN_SELECT; }
  "FROM"                { return TOKEN_FROM; }
  "INSERT"              { return TOKEN_INSERT; }
  "INTO"                { return TOKEN_INTO; }
  "VALUES"              { return TOKEN_VALUES; }
  "QUIT"                { SAVE_TOKEN_STRING; return TOKEN_QUIT; }

  "SET"                 { return TOKEN_SET; }
  "NAMES"               { return TOKEN_NAMES; }
  "CHARACTER"           { return TOKEN_CHARACTER; }
  "GLOBAL"              { return TOKEN_GLOBAL; }
  "SESSION"             { return TOKEN_SESSION; }
  "PERSIST"             { return TOKEN_PERSIST; }
  "PERSIST_ONLY"        { return TOKEN_PERSIST_ONLY;}
  "DEFAULT"             { return TOKEN_DEFAULT; }
  "COLLATE"             { return TOKEN_COLLATE; }
  
  "SHOW"                { return TOKEN_SHOW; }
  /* FULL is already defined for JOINs, will be reused */
  /* FIELDS is already defined for INTO OUTFILE, will be reused */
  "DATABASES"           { return TOKEN_DATABASES; }
  "BEGIN"               { return TOKEN_BEGIN; }
  "COMMIT"              { return TOKEN_COMMIT; }
  "IS"                  { return TOKEN_IS; }
  "NULL"                { return TOKEN_NULL_KEYWORD; }
  "NOT"                 { return TOKEN_NOT; }


  "DELETE"              { return TOKEN_DELETE; }
  "LOW_PRIORITY"        { return TOKEN_LOW_PRIORITY; }
  "QUICK"               { return TOKEN_QUICK; }
  "IGNORE"              { return TOKEN_IGNORE_SYM; } /* Changed from TOKEN_IGNORE to avoid conflict if IGNORE is a general keyword */
  "USING"               { return TOKEN_USING; }
  "ORDER"               { return TOKEN_ORDER; }
  "BY"                  { return TOKEN_BY; }
  "LIMIT"               { return TOKEN_LIMIT; }
  "ASC"                 { return TOKEN_ASC; }
  "DESC"                { return TOKEN_DESC; }
  "WHERE"               { return TOKEN_WHERE; }
  "AS"                  { return TOKEN_AS; }
  "DISTINCT"            { return TOKEN_DISTINCT; }
  "GROUP"               { return TOKEN_GROUP; }
  "ALL"                 { return TOKEN_ALL; }
  "HAVING"              { return TOKEN_HAVING; }
  "AND"                 { return TOKEN_AND; }

  /* JOIN related keywords */
  "JOIN"                { return TOKEN_JOIN; }
  "INNER"               { return TOKEN_INNER; }
  "LEFT"                { return TOKEN_LEFT; }
  "RIGHT"               { return TOKEN_RIGHT; }
  "FULL"                { return TOKEN_FULL; }
  "OUTER"               { return TOKEN_OUTER; }
  "CROSS"               { return TOKEN_CROSS; }
  "NATURAL"             { return TOKEN_NATURAL; }
  "ON"                  { return TOKEN_ON; }

  /* New keywords for INTO, LOCKING */
  "OUTFILE"             { return TOKEN_OUTFILE; }
  "DUMPFILE"            { return TOKEN_DUMPFILE; }
  "FOR"                 { return TOKEN_FOR; }
  "UPDATE"              { return TOKEN_UPDATE; }
  "SHARE"               { return TOKEN_SHARE; }
  "OF"                  { return TOKEN_OF; }
  "NOWAIT"              { return TOKEN_NOWAIT; }
  "SKIP"                { return TOKEN_SKIP; }
  "LOCKED"              { return TOKEN_LOCKED; }

  /* Keywords for SET TRANSACTION (Query 1) */
  "TRANSACTION"         { return TOKEN_TRANSACTION; }
  "ISOLATION"           { return TOKEN_ISOLATION; }
  "LEVEL"               { return TOKEN_LEVEL; }
  "READ"                { return TOKEN_READ; }
  "WRITE"               { return TOKEN_WRITE; }
  "COMMITTED"           { return TOKEN_COMMITTED; }
  "UNCOMMITTED"         { return TOKEN_UNCOMMITTED; }
  "REPEATABLE"          { return TOKEN_REPEATABLE; }
  "SERIALIZABLE"        { return TOKEN_SERIALIZABLE; }

  /* Keywords for MATCH AGAINST (Query 5) */
  "MATCH"               { return TOKEN_MATCH; }
  "AGAINST"             { return TOKEN_AGAINST; }
  "BOOLEAN"             { return TOKEN_BOOLEAN; }
  "MODE"                { return TOKEN_MODE; }
  "IN"                  { return TOKEN_IN; } /* For IN BOOLEAN MODE and IN operator */

  /* Keywords for INTO OUTFILE options */
  "FIELDS"              { return TOKEN_FIELDS; }
  "TERMINATED"          { return TOKEN_TERMINATED; }
  "OPTIONALLY"          { return TOKEN_OPTIONALLY; }
  "ENCLOSED"            { return TOKEN_ENCLOSED; }
  "ESCAPED"             { return TOKEN_ESCAPED; }
  "LINES"               { return TOKEN_LINES; }
  "STARTING"            { return TOKEN_STARTING; }

  /* Aggregate function keywords */
  "COUNT"               { return TOKEN_COUNT; }
  "SUM"                 { return TOKEN_SUM; }
  "AVG"                 { return TOKEN_AVG; }
  "MAX"                 { return TOKEN_MAX; }
  "MIN"                 { return TOKEN_MIN; }


  /* Identifiers and Literals */
  "`"                   { yylval_param->str_val = new std::string(); BEGIN(BTIDENT); }

  "@@global."           { return TOKEN_GLOBAL_VAR_PREFIX; }
  "@@session."          { return TOKEN_SESSION_VAR_PREFIX; }
  "@@local."            { return TOKEN_SESSION_VAR_PREFIX; } /* local is alias for session */
  "@@persisted."        { return TOKEN_PERSIST_VAR_PREFIX; } /* MySQL 8 specific */
  "@@"                  { return TOKEN_DOUBLESPECIAL; } /* For @@varname */
  "@"                   { return TOKEN_SPECIAL; } /* For @uservar */

  /* Generic Identifier - MUST BE AFTER specific keywords */
  [a-zA-Z_][a-zA-Z0-9_]* {
                          SAVE_TOKEN_STRING;
                          return TOKEN_IDENTIFIER;
                        }

  "'"                   { yylval_param->str_val = new std::string("'"); BEGIN(SQSTRING); }
  "\""                  { yylval_param->str_val = new std::string("\""); BEGIN(DQSTRING); }

  /* Operators and Punctuation */
  "*"                   { return TOKEN_ASTERISK; } /* For SELECT * and also multiplication */
  "+"                   { return TOKEN_PLUS; }
  "-"                   { return TOKEN_MINUS; }
  "/"                   { return TOKEN_DIVIDE; }
  "("                   { return TOKEN_LPAREN; }
  ")"                   { return TOKEN_RPAREN; }
  ";"                   { return TOKEN_SEMICOLON; }
  "."                   { return TOKEN_DOT; }
  ","                   { return TOKEN_COMMA; }

  "="                   { return TOKEN_EQUAL; }
  "<"                   { return TOKEN_LESS; }
  ">"                   { return TOKEN_GREATER; }
  "<="                  { return TOKEN_LESS_EQUAL; }
  ">="                  { return TOKEN_GREATER_EQUAL; }
  "!="                  { return TOKEN_NOT_EQUAL; }
  "<>"                  { return TOKEN_NOT_EQUAL; }


  [0-9]+("."[0-9]+)?([eE][+-]?[0-9]+)? { SAVE_TOKEN_STRING; return TOKEN_NUMBER_LITERAL; }
  0x[0-9a-fA-F]+        { SAVE_TOKEN_STRING; return TOKEN_NUMBER_LITERAL; } /* Hex literal */
  X'[0-9a-fA-F]*'       { SAVE_TOKEN_STRING; return TOKEN_STRING_LITERAL; } /* Hex string literal X'...' */


  .                     {
                          char err_msg[100];
                          snprintf(err_msg, sizeof(err_msg), "Lexer: Unknown character: '%s'", yytext);
                          if (parser_context) {
                              parser_context->internal_add_error(err_msg);
                          } else {
                              fprintf(stderr, "%s\n", err_msg);
                          }
                        }
}

<COMMENT>{
  "*/"                  { BEGIN(INITIAL); }
  [^*\n]+               { /* Eat comment content */ }
  "*"                   { /* Eat isolated asterisks */ }
  \n                    { /* Newlines in comments */ }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated /* comment"); BEGIN(INITIAL); return YY_NULL; }
}

<SQSTRING>{
  "[^'\\\\]+"           { *(yylval_param->str_val) += yytext; }
  "\\'"                 { *(yylval_param->str_val) += "'"; }
  "\\\\"                { *(yylval_param->str_val) += "\\"; }
  /* Add other standard SQL escape sequences if needed e.g. \n, \t, \b, \r, \0, \Z */
  "\\n"                 { *(yylval_param->str_val) += "\n"; }
  "\\t"                 { *(yylval_param->str_val) += "\t"; }
  "\\r"                 { *(yylval_param->str_val) += "\r"; }
  "\\b"                 { *(yylval_param->str_val) += "\b"; }
  "\\0"                 { *(yylval_param->str_val) += "\0"; }
  "\\Z"                 { *(yylval_param->str_val) += "\x1a"; } /* Ctrl+Z */
  "''"                  { *(yylval_param->str_val) += "'"; } /* SQL standard for literal single quote */
  "'"                   { *(yylval_param->str_val) += "'"; BEGIN(INITIAL); return TOKEN_STRING_LITERAL; }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated single-quoted string"); BEGIN(INITIAL); return YY_NULL; }
}

<DQSTRING>{
  "[^\"\\\\]+"          { *(yylval_param->str_val) += yytext; }
  "\\\""                { *(yylval_param->str_val) += "\""; }
  "\\\\"                { *(yylval_param->str_val) += "\\"; }
  /* Add other standard SQL escape sequences if needed */
  "\\n"                 { *(yylval_param->str_val) += "\n"; }
  "\\t"                 { *(yylval_param->str_val) += "\t"; }
  "\\r"                 { *(yylval_param->str_val) += "\r"; }
  "\\b"                 { *(yylval_param->str_val) += "\b"; }
  "\\0"                 { *(yylval_param->str_val) += "\0"; }
  "\\Z"                 { *(yylval_param->str_val) += "\x1a"; }
  "\"\""                { *(yylval_param->str_val) += "\""; } /* SQL standard for literal double quote */
  "\""                  { *(yylval_param->str_val) += "\""; BEGIN(INITIAL); return TOKEN_STRING_LITERAL; }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated double-quoted string"); BEGIN(INITIAL); return YY_NULL; }
}

<BTIDENT>{
  "`"                   { BEGIN(INITIAL); return TOKEN_IDENTIFIER; }
  "``"                  { *(yylval_param->str_val) += '`'; } /* Escaped backtick inside identifier */
  [^`\n]+               { *(yylval_param->str_val) += yytext; }
  \n                    { if(parser_context) parser_context->internal_add_error("Newline in backticked identifier"); BEGIN(INITIAL); /* Error, but return to INITIAL */ }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated backticked identifier"); BEGIN(INITIAL); return YY_NULL; }
}

%%
/* C code to be included at the end of the lexer */

