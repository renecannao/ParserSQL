%option reentrant noyywrap nounput noinput batch case-insensitive
%option prefix="pgsql_yy"
%option extra-type="PgsqlParser::Parser*"

%{
#include "pgsql_parser/pgsql_parser.h"   // Defines PgsqlParser::Parser, yyscan_t
#include "pgsql_parser/pgsql_ast.h"      // Defines PgsqlParser::AstNode, etc.
#include "pgsql_parser.tab.h"           // Defines tokens, AND the actual pgsql_yySTYPE/PGSQL_YYSTYPE union and YYSTYPE typedef
#include <string>

// Forward declare the union with the name Bison seems to use internally (based on previous errors)
// This might not be strictly necessary if pgsql_parser.tab.h defines it adequately before YY_DECL expansion,
// but can help if there are subtle ordering issues.
// union PGSQL_YYSTYPE; // Let's rely on pgsql_parser.tab.h to define this first.

#undef YY_DECL
// Use the explicit union name for yylval_param's type.
// This MUST match the extern declaration in pgsql_parser.y
#define YY_DECL int pgsql_yylex (union PGSQL_YYSTYPE *yylval_param, yyscan_t yyscanner, PgsqlParser::Parser* parser_context)

#define YY_USER_DATA ((PgsqlParser::Parser*)yyget_extra(yyscanner))
%}

%%

[ \t\n]+          { /* Ignore whitespace */ }

"SELECT"          { return TOKEN_SELECT; }
"FROM"            { return TOKEN_FROM; }
"INSERT"          { return TOKEN_INSERT; }
"INTO"            { return TOKEN_INTO; }
"VALUES"          { return TOKEN_VALUES; }

"QUIT"            { 
                    yylval_param->str_val = new std::string(yytext); 
                    return TOKEN_QUIT; 
                  }

[a-zA-Z_][a-zA-Z0-9_]* { 
                    yylval_param->str_val = new std::string(yytext); 
                    return TOKEN_IDENTIFIER; 
                  }

'[^'\n]+'         { 
                    yylval_param->str_val = new std::string(yytext); 
                    return TOKEN_STRING_LITERAL; 
                  }

"("               { return TOKEN_LPAREN; }
")"               { return TOKEN_RPAREN; }
";"               { return TOKEN_SEMICOLON; }

.                 { 
                    char err_msg[100];
                    snprintf(err_msg, sizeof(err_msg), "Lexer: Unknown character: '%s'", yytext);
                    if (parser_context) { // parser_context is a direct parameter now
                        parser_context->internal_add_error(err_msg);
                    } else {
                        fprintf(stderr, "%s\n", err_msg); 
                    }
                  }
%%
