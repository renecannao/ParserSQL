# Makefile
CXX = g++
LINKER = g++ 

CXXFLAGS = -std=c++17 -Wall -g 
CPPFLAGS = -I$(PROJECT_ROOT)/include

PROJECT_ROOT = .
INCLUDE_DIR = $(PROJECT_ROOT)/include
SRC_DIR = $(PROJECT_ROOT)/src

PGSQL_PARSER_SRC_DIR = $(SRC_DIR)/pgsql_parser
PGSQL_PARSER_INCLUDE_DIR = $(INCLUDE_DIR)/pgsql_parser

TARGET_LIB_NAME = pgsqlparser
TARGET_LIB = $(PROJECT_ROOT)/lib$(TARGET_LIB_NAME).a
EXAMPLE_EXE = $(PROJECT_ROOT)/pgsql_example

PGSQL_BISON_PARSER_C_FILE = pgsql_parser.tab.c
PGSQL_BISON_PARSER_H_FILE = pgsql_parser.tab.h
PGSQL_FLEX_LEXER_C_FILE = pgsql_lexer.yy.c

PGSQL_BISON_PARSER_C = $(PGSQL_PARSER_SRC_DIR)/$(PGSQL_BISON_PARSER_C_FILE)
PGSQL_BISON_PARSER_H = $(PGSQL_PARSER_SRC_DIR)/$(PGSQL_BISON_PARSER_H_FILE)
PGSQL_FLEX_LEXER_C = $(PGSQL_PARSER_SRC_DIR)/$(PGSQL_FLEX_LEXER_C_FILE)

PGSQL_LIB_OBJS = \
    $(PGSQL_BISON_PARSER_C:.c=.o) \
    $(PGSQL_FLEX_LEXER_C:.c=.o) \
    $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.o

EXAMPLE_OBJS = $(PROJECT_ROOT)/examples/main_pgsql_example.o

.PHONY: all clean examples

all: $(TARGET_LIB) examples

examples: $(EXAMPLE_EXE)

$(TARGET_LIB): $(PGSQL_LIB_OBJS)
	ar rcs $@ $(PGSQL_LIB_OBJS)
	@echo "Created library $@"

$(EXAMPLE_EXE): $(EXAMPLE_OBJS) $(TARGET_LIB)
	$(LINKER) $(CXXFLAGS) -o $@ $(EXAMPLE_OBJS) -L$(PROJECT_ROOT) -l$(TARGET_LIB_NAME)
	@echo "Created example $@"

$(PGSQL_BISON_PARSER_H) $(PGSQL_BISON_PARSER_C): $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.y $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_ast.h $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h
	cd $(PGSQL_PARSER_SRC_DIR) && bison -d -v --report=all pgsql_parser.y

$(PGSQL_FLEX_LEXER_C): $(PGSQL_PARSER_SRC_DIR)/pgsql_lexer.l $(PGSQL_BISON_PARSER_H)
	cd $(PGSQL_PARSER_SRC_DIR) && flex -o $(PGSQL_FLEX_LEXER_C_FILE) pgsql_lexer.l

# Rule to compile Bison-generated file (pgsql_parser.tab.c) AS C++
$(PGSQL_BISON_PARSER_C:.c=.o): $(PGSQL_BISON_PARSER_C) $(PGSQL_BISON_PARSER_H) $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

# Rule to compile Flex-generated file (pgsql_lexer.yy.c) AS C++
$(PGSQL_FLEX_LEXER_C:.c=.o): $(PGSQL_FLEX_LEXER_C) $(PGSQL_BISON_PARSER_H) $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

# Rule to compile pgsql_parser.cpp (C++ file)
$(PGSQL_PARSER_SRC_DIR)/pgsql_parser.o: $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.cpp $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_ast.h $(PGSQL_BISON_PARSER_H)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

$(PROJECT_ROOT)/examples/main_pgsql_example.o: $(PROJECT_ROOT)/examples/main_pgsql_example.cpp $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_ast.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

clean:
	rm -f $(TARGET_LIB) $(EXAMPLE_EXE)
	rm -f $(PGSQL_LIB_OBJS) $(EXAMPLE_OBJS)
	rm -f $(PGSQL_BISON_PARSER_C) $(PGSQL_BISON_PARSER_H) $(PGSQL_FLEX_LEXER_C)
	rm -f $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.output $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.report
	rm -f $(PGSQL_PARSER_SRC_DIR)/lex.backup
	@echo "Cleaned up project."
