# Makefile
CXX = g++
LINKER = g++ 

CXXFLAGS = -std=c++17 -Wall -g 
CPPFLAGS = -I$(PROJECT_ROOT)/include

PROJECT_ROOT = .
INCLUDE_DIR = $(PROJECT_ROOT)/include
SRC_DIR = $(PROJECT_ROOT)/src

# --- PostgreSQL Parser Variables ---
PGSQL_PARSER_SRC_DIR = $(SRC_DIR)/pgsql_parser
PGSQL_PARSER_INCLUDE_DIR = $(INCLUDE_DIR)/pgsql_parser
PGSQL_TARGET_LIB_NAME = pgsqlparser
PGSQL_TARGET_LIB = $(PROJECT_ROOT)/lib$(PGSQL_TARGET_LIB_NAME).a
PGSQL_EXAMPLE_EXE = $(PROJECT_ROOT)/pgsql_example

PGSQL_BISON_C_FILE = pgsql_parser.tab.c
PGSQL_BISON_H_FILE = pgsql_parser.tab.h
PGSQL_FLEX_C_FILE = pgsql_lexer.yy.c

PGSQL_BISON_C = $(PGSQL_PARSER_SRC_DIR)/$(PGSQL_BISON_C_FILE)
PGSQL_BISON_H = $(PGSQL_PARSER_SRC_DIR)/$(PGSQL_BISON_H_FILE)
PGSQL_FLEX_C = $(PGSQL_PARSER_SRC_DIR)/$(PGSQL_FLEX_C_FILE)

PGSQL_LIB_OBJS = \
    $(PGSQL_BISON_C:.c=.o) \
    $(PGSQL_FLEX_C:.c=.o) \
    $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.o
PGSQL_EXAMPLE_OBJS = $(PROJECT_ROOT)/examples/main_pgsql_example.o

# --- MySQL Parser Variables ---
MYSQL_PARSER_SRC_DIR = $(SRC_DIR)/mysql_parser
MYSQL_PARSER_INCLUDE_DIR = $(INCLUDE_DIR)/mysql_parser
MYSQL_TARGET_LIB_NAME = mysqlparser
MYSQL_TARGET_LIB = $(PROJECT_ROOT)/lib$(MYSQL_TARGET_LIB_NAME).a
MYSQL_EXAMPLE_EXE = $(PROJECT_ROOT)/mysql_example
MYSQL_SET_EXAMPLE_EXE = $(PROJECT_ROOT)/set_mysql_example

MYSQL_BISON_C_FILE = mysql_parser.tab.c
MYSQL_BISON_H_FILE = mysql_parser.tab.h
MYSQL_FLEX_C_FILE = mysql_lexer.yy.c

MYSQL_BISON_C = $(MYSQL_PARSER_SRC_DIR)/$(MYSQL_BISON_C_FILE)
MYSQL_BISON_H = $(MYSQL_PARSER_SRC_DIR)/$(MYSQL_BISON_H_FILE)
MYSQL_FLEX_C = $(MYSQL_PARSER_SRC_DIR)/$(MYSQL_FLEX_C_FILE)

MYSQL_LIB_OBJS = \
    $(MYSQL_BISON_C:.c=.o) \
    $(MYSQL_FLEX_C:.c=.o) \
    $(MYSQL_PARSER_SRC_DIR)/mysql_parser.o # Renamed from mysql_sql_parser.o
MYSQL_EXAMPLE_OBJS = $(PROJECT_ROOT)/examples/main_mysql_example.o
MYSQL_SET_EXAMPLE_OBJS = $(PROJECT_ROOT)/examples/set_mysql_example.o


.PHONY: all clean examples pgsql mysql

all: pgsql mysql examples

pgsql: $(PGSQL_TARGET_LIB)
mysql: $(MYSQL_TARGET_LIB)

examples: $(PGSQL_EXAMPLE_EXE) $(MYSQL_EXAMPLE_EXE) $(MYSQL_SET_EXAMPLE_EXE)

# --- PostgreSQL Rules ---
$(PGSQL_TARGET_LIB): $(PGSQL_LIB_OBJS)
	ar rcs $@ $(PGSQL_LIB_OBJS)
	@echo "Created library $@"

$(PGSQL_EXAMPLE_EXE): $(PGSQL_EXAMPLE_OBJS) $(PGSQL_TARGET_LIB)
	$(LINKER) $(CXXFLAGS) -o $@ $(PGSQL_EXAMPLE_OBJS) -L$(PROJECT_ROOT) -l$(PGSQL_TARGET_LIB_NAME)
	@echo "Created PostgreSQL example $@"

$(PGSQL_BISON_H) $(PGSQL_BISON_C): $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.y $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_ast.h $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h
	cd $(PGSQL_PARSER_SRC_DIR) && bison -d -v --report=all pgsql_parser.y

$(PGSQL_FLEX_C): $(PGSQL_PARSER_SRC_DIR)/pgsql_lexer.l $(PGSQL_BISON_H)
	cd $(PGSQL_PARSER_SRC_DIR) && flex -o $(PGSQL_FLEX_C_FILE) pgsql_lexer.l

$(PGSQL_PARSER_SRC_DIR)/pgsql_parser.tab.o: $(PGSQL_BISON_C) $(PGSQL_BISON_H) $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

$(PGSQL_PARSER_SRC_DIR)/pgsql_lexer.yy.o: $(PGSQL_FLEX_C) $(PGSQL_BISON_H) $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

$(PGSQL_PARSER_SRC_DIR)/pgsql_parser.o: $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.cpp $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_ast.h $(PGSQL_BISON_H)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

$(PROJECT_ROOT)/examples/main_pgsql_example.o: $(PROJECT_ROOT)/examples/main_pgsql_example.cpp $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_ast.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

# --- MySQL Rules ---
$(MYSQL_TARGET_LIB): $(MYSQL_LIB_OBJS)
	ar rcs $@ $(MYSQL_LIB_OBJS)
	@echo "Created library $@"

$(MYSQL_EXAMPLE_EXE): $(MYSQL_EXAMPLE_OBJS) $(MYSQL_TARGET_LIB)
	$(LINKER) $(CXXFLAGS) -o $@ $(MYSQL_EXAMPLE_OBJS) -L$(PROJECT_ROOT) -l$(MYSQL_TARGET_LIB_NAME)
	@echo "Created MySQL example $@"

# Rule for MySQL SET example executable <<< NEW
$(MYSQL_SET_EXAMPLE_EXE): $(MYSQL_SET_EXAMPLE_OBJS) $(MYSQL_TARGET_LIB)
	$(LINKER) $(CXXFLAGS) -o $@ $(MYSQL_SET_EXAMPLE_OBJS) -L$(PROJECT_ROOT) -l$(MYSQL_TARGET_LIB_NAME)
	@echo "Created MySQL SET statement example $@"

$(MYSQL_BISON_H) $(MYSQL_BISON_C): $(MYSQL_PARSER_SRC_DIR)/mysql_parser.y $(MYSQL_PARSER_INCLUDE_DIR)/mysql_ast.h $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h
	cd $(MYSQL_PARSER_SRC_DIR) && bison -d -v --report=all -o $(MYSQL_BISON_C_FILE) --defines=$(MYSQL_BISON_H_FILE) mysql_parser.y

$(MYSQL_FLEX_C): $(MYSQL_PARSER_SRC_DIR)/mysql_lexer.l $(MYSQL_BISON_H)
	cd $(MYSQL_PARSER_SRC_DIR) && flex -o $(MYSQL_FLEX_C_FILE) mysql_lexer.l

$(MYSQL_PARSER_SRC_DIR)/mysql_parser.tab.o: $(MYSQL_BISON_C) $(MYSQL_BISON_H) $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

$(MYSQL_PARSER_SRC_DIR)/mysql_lexer.yy.o: $(MYSQL_FLEX_C) $(MYSQL_BISON_H) $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

$(MYSQL_PARSER_SRC_DIR)/mysql_parser.o: $(MYSQL_PARSER_SRC_DIR)/mysql_parser.cpp $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h $(MYSQL_PARSER_INCLUDE_DIR)/mysql_ast.h $(MYSQL_BISON_H)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

$(PROJECT_ROOT)/examples/main_mysql_example.o: $(PROJECT_ROOT)/examples/main_mysql_example.cpp $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h $(MYSQL_PARSER_INCLUDE_DIR)/mysql_ast.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

# Rule for MySQL SET example main.o <<< NEW
$(PROJECT_ROOT)/examples/set_mysql_example.o: $(PROJECT_ROOT)/examples/set_mysql_example.cpp $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h $(MYSQL_PARSER_INCLUDE_DIR)/mysql_ast.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@


clean:
	rm -f $(PGSQL_TARGET_LIB) $(PGSQL_EXAMPLE_EXE) $(MYSQL_TARGET_LIB) $(MYSQL_EXAMPLE_EXE) $(MYSQL_SET_EXAMPLE_EXE)
	rm -f $(PGSQL_LIB_OBJS) $(PGSQL_EXAMPLE_OBJS) $(MYSQL_LIB_OBJS) $(MYSQL_EXAMPLE_OBJS) $(MYSQL_SET_EXAMPLE_OBJS)
	rm -f $(PGSQL_BISON_C) $(PGSQL_BISON_H) $(PGSQL_FLEX_C)
	rm -f $(MYSQL_BISON_C) $(MYSQL_BISON_H) $(MYSQL_FLEX_C)
	rm -f $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.output $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.report
	rm -f $(MYSQL_PARSER_SRC_DIR)/mysql_parser.output $(MYSQL_PARSER_SRC_DIR)/mysql_parser.report
	rm -f $(PGSQL_PARSER_SRC_DIR)/lex.backup $(MYSQL_PARSER_SRC_DIR)/lex.backup
	@echo "Cleaned up project."
