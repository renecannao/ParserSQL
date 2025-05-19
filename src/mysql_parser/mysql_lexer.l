%option reentrant noyywrap nounput noinput batch case-insensitive
%option prefix="mysql_yy"
%option extra-type="MysqlParser::Parser*"

%{
#include "mysql_parser/mysql_parser.h"
#include "mysql_parser/mysql_ast.h"
#include "mysql_parser.tab.h" // Will be mysql_parser.tab.h
#include <string>
#include <vector>

// YY_DECL to control the signature of mysql_yylex
union MYSQL_YYSTYPE; // Forward declare for YY_DECL (Bison defines this in mysql_parser.tab.h)
#undef YY_DECL
#define YY_DECL int mysql_yylex (union MYSQL_YYSTYPE *yylval_param, yyscan_t yyscanner, MysqlParser::Parser* parser_context)

// #define YY_USER_DATA ((MysqlParser::Parser*)yyget_extra(yyscanner)) // Alternative way to access context
%}

/* Declare exclusive start conditions */
%x COMMENT
%x SQSTRING
%x DQSTRING
%x BTIDENT

%%

<INITIAL>{
  "/*"                  { BEGIN(COMMENT); }
  "-- ".* { /* MySQL -- comment (note space) */ }
  "--\n"                { /* MySQL -- comment followed by newline */ }
  "#".* { /* MySQL # comment */ }

  [ \t\n]+              { /* Ignore whitespace */ }

  "SELECT"              { return TOKEN_SELECT; }
  "FROM"                { return TOKEN_FROM; }
  "INSERT"              { return TOKEN_INSERT; }
  "INTO"                { return TOKEN_INTO; }
  "VALUES"              { return TOKEN_VALUES; }
  "QUIT"                { yylval_param->str_val = new std::string(yytext); return TOKEN_QUIT; }

  "SET"                 { return TOKEN_SET; }
  "NAMES"               { return TOKEN_NAMES; }
  "CHARACTER"           { return TOKEN_CHARACTER; }
  "GLOBAL"              { return TOKEN_GLOBAL; }
  "SESSION"             { return TOKEN_SESSION; }
  "PERSIST"             { return TOKEN_PERSIST; }
  "PERSIST_ONLY"        { return TOKEN_PERSIST_ONLY;}
  "DEFAULT"             { return TOKEN_DEFAULT; }
  "COLLATE"             { return TOKEN_COLLATE; }

  "`"                   { yylval_param->str_val = new std::string(); BEGIN(BTIDENT); }

  "@@global."           { return TOKEN_GLOBAL_VAR_PREFIX; }
  "@@session."          { return TOKEN_SESSION_VAR_PREFIX; }
  "@@local."            { return TOKEN_SESSION_VAR_PREFIX; } /* Alias for session */
  "@@persisted."        { /* Placeholder if you add specific handling */ return TOKEN_PERSIST_VAR_PREFIX; }
  "@@"                  { return TOKEN_DOUBLESPECIAL; }
  "@"                   { return TOKEN_SPECIAL; }

  [a-zA-Z_][a-zA-Z0-9_]* { /* Does not include hyphen for now */
                          yylval_param->str_val = new std::string(yytext);
                          return TOKEN_IDENTIFIER;
                        }

  "'"                   { yylval_param->str_val = new std::string("'"); BEGIN(SQSTRING); }
  "\""                  { yylval_param->str_val = new std::string("\""); BEGIN(DQSTRING); }

  "*"                   { return TOKEN_ASTERISK; }
  "("                   { return TOKEN_LPAREN; }
  ")"                   { return TOKEN_RPAREN; }
  ";"                   { return TOKEN_SEMICOLON; }
  "="                   { return TOKEN_EQUAL; }
  "."                   { return TOKEN_DOT; }
  ","                   { return TOKEN_COMMA; }

  [0-9]+("."[0-9]+)?    { yylval_param->str_val = new std::string(yytext); return TOKEN_NUMBER_LITERAL;}

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
}

<SQSTRING>{
  "[^'\\\\]+"           { *(yylval_param->str_val) += yytext; }
  "\\'"                 { *(yylval_param->str_val) += "'"; }
  "\\\\"                { *(yylval_param->str_val) += "\\"; }
  "''"                  { *(yylval_param->str_val) += "'"; }
  "'"                   { *(yylval_param->str_val) += "'"; BEGIN(INITIAL); return TOKEN_STRING_LITERAL; }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated single-quoted string"); BEGIN(INITIAL); return YY_NULL; }
}

<DQSTRING>{
  "[^\"\\\\]+"          { *(yylval_param->str_val) += yytext; }
  "\\\""                { *(yylval_param->str_val) += "\""; }
  "\\\\"                { *(yylval_param->str_val) += "\\"; }
  "\"\""                { *(yylval_param->str_val) += "\""; }
  "\""                  { *(yylval_param->str_val) += "\""; BEGIN(INITIAL); return TOKEN_STRING_LITERAL; }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated double-quoted string"); BEGIN(INITIAL); return YY_NULL; }
}

<BTIDENT>{
  "`"                   { BEGIN(INITIAL); return TOKEN_IDENTIFIER; } // Returns the accumulated string
  "``"                  { *(yylval_param->str_val) += '`'; }
  [^`\n]+               { *(yylval_param->str_val) += yytext; }
  \n                    { if(parser_context) parser_context->internal_add_error("Newline in backticked identifier"); BEGIN(INITIAL); /* No explicit return */ }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated backticked identifier"); BEGIN(INITIAL); return YY_NULL; }
}

%%

