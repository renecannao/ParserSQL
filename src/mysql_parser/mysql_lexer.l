%option reentrant noyywrap nounput noinput batch case-insensitive
%option prefix="mysql_yy"
%option extra-type="MysqlParser::Parser*"

%{
#include "mysql_parser/mysql_parser.h"   // For MysqlParser::Parser, yyscan_t
#include "mysql_parser/mysql_ast.h"      // For MysqlParser::AstNode, etc.
#include "mysql_parser.tab.h"           // Bison-generated: token enums, defines union MYSQL_YYSTYPE and YYSTYPE
#include <string>
#include <vector>

// YY_DECL to control the signature of the generated mysql_yylex function.
// This signature MUST match how Bison calls it (influenced by %lex-param in .y file
// and the extern declaration of mysql_yylex in the .y file's prologue).
// We use the explicit union name as deduced from previous Bison error messages.
// The actual definition of 'union MYSQL_YYSTYPE' comes from "mysql_parser.tab.h".
union MYSQL_YYSTYPE; // Forward declare for YY_DECL (Bison defines this in mysql_parser.tab.h)
#undef YY_DECL
#define YY_DECL int mysql_yylex (union MYSQL_YYSTYPE *yylval_param, yyscan_t yyscanner, MysqlParser::Parser* parser_context)

// YY_USER_DATA can be used to access parser_context IF it's passed as yyextra,
// OR if parser_context from YY_DECL is directly used.
// Since parser_context is now a direct parameter to mysql_yylex via YY_DECL,
// we can use it directly in actions.
// #define YY_USER_DATA ((MysqlParser::Parser*)yyget_extra(yyscanner))
%}

%x COMMENT
%x SQSTRING
%x DQSTRING
%x BTIDENT

%%

<INITIAL>{
  "/*"                  { BEGIN(COMMENT); }
  "-- ".* { /* MySQL -- comment (note space); no action, just ignore */ }
  "--\n"                { /* MySQL -- comment followed by newline; no action */ }
  "#".* { /* MySQL # comment; no action */ }

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

  "DELETE"              { return TOKEN_DELETE; }
  "LOW_PRIORITY"        { return TOKEN_LOW_PRIORITY; }
  "QUICK"               { return TOKEN_QUICK; }
  "IGNORE"              { return TOKEN_IGNORE_SYM; }
  "USING"               { return TOKEN_USING; }
  "ORDER"               { return TOKEN_ORDER; }
  "BY"                  { return TOKEN_BY; }
  "LIMIT"               { return TOKEN_LIMIT; }
  "ASC"                 { return TOKEN_ASC; }
  "DESC"                { return TOKEN_DESC; }
  "WHERE"               { return TOKEN_WHERE; }
  "AS"                  { return TOKEN_AS; }


  "`"                   { yylval_param->str_val = new std::string(); BEGIN(BTIDENT); }

  "@@global."           { return TOKEN_GLOBAL_VAR_PREFIX; }
  "@@session."          { return TOKEN_SESSION_VAR_PREFIX; }
  "@@local."            { return TOKEN_SESSION_VAR_PREFIX; } /* Alias for session */
  "@@persisted."        { return TOKEN_PERSIST_VAR_PREFIX; } /* If you add specific handling */
  "@@"                  { return TOKEN_DOUBLESPECIAL; }
  "@"                   { return TOKEN_SPECIAL; }

  [a-zA-Z_][a-zA-Z0-9_]* {
                          yylval_param->str_val = new std::string(yytext);
                          return TOKEN_IDENTIFIER;
                        }

  "'"                   { yylval_param->str_val = new std::string("'"); BEGIN(SQSTRING); }
  "\""                  { yylval_param->str_val = new std::string("\""); BEGIN(DQSTRING); }

  "*"                   { return TOKEN_ASTERISK; }
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


  [0-9]+("."[0-9]+)?    { yylval_param->str_val = new std::string(yytext); return TOKEN_NUMBER_LITERAL;}

  .                     {
                          char err_msg[100];
                          snprintf(err_msg, sizeof(err_msg), "Lexer: Unknown character: '%s'", yytext);
                          if (parser_context) {
                              parser_context->internal_add_error(err_msg);
                          } else {
                              fprintf(stderr, "%s\n", err_msg); // Fallback
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
  "''"                  { *(yylval_param->str_val) += "'"; } /* MySQL: '' inside string is a literal ' */
  "'"                   { *(yylval_param->str_val) += "'"; BEGIN(INITIAL); return TOKEN_STRING_LITERAL; }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated single-quoted string"); BEGIN(INITIAL); return YY_NULL; /* Return 0 for EOF/error */ }
}

<DQSTRING>{
  "[^\"\\\\]+"          { *(yylval_param->str_val) += yytext; }
  "\\\""                { *(yylval_param->str_val) += "\""; }
  "\\\\"                { *(yylval_param->str_val) += "\\"; }
  "\"\""                { *(yylval_param->str_val) += "\""; } /* MySQL: "" inside string is a literal " */
  "\""                  { *(yylval_param->str_val) += "\""; BEGIN(INITIAL); return TOKEN_STRING_LITERAL; }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated double-quoted string"); BEGIN(INITIAL); return YY_NULL; }
}

<BTIDENT>{
  "`"                   { BEGIN(INITIAL); return TOKEN_IDENTIFIER; } /* Returns the accumulated string */
  "``"                  { *(yylval_param->str_val) += '`'; } /* `` inside backticks is a literal ` */
  [^`\n]+               { *(yylval_param->str_val) += yytext; }
  \n                    { if(parser_context) parser_context->internal_add_error("Newline in backticked identifier"); BEGIN(INITIAL); /* No explicit return, lexer will find next token or error */ }
  <<EOF>>               { if(parser_context) parser_context->internal_add_error("Unterminated backticked identifier"); BEGIN(INITIAL); return YY_NULL; }
}

%%

// yywrap is not strictly needed due to %option noyywrap
// int mysql_yywrap(yyscan_t scanner) { return 1; }

