# Makefile
CXX = g++
LINKER = g++

CXXFLAGS = -std=c++17 -Wall -g -O2 -DYYDEBUG=1
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
MYSQL_STDIN_EXAMPLE_EXE = $(PROJECT_ROOT)/mysql_stdin_parser_example

TEST_REGEXES_PARITY = $(PROJECT_ROOT)/tests/test_regexes_parity

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
MYSQL_STDIN_EXAMPLE_OBJS = $(PROJECT_ROOT)/examples/mysql_stdin_parser_example.o

PROXYSQL_IDIR := $(PROXYSQL_PATH)/include
PROXYSQL_LDIR := $(PROXYSQL_PATH)/lib

DEPS_PATH := $(PROXYSQL_PATH)/deps

MARIADB_PATH := $(DEPS_PATH)/mariadb-client-library/mariadb_client
MARIADB_IDIR := $(MARIADB_PATH)/include
MARIADB_LDIR := $(MARIADB_PATH)/libmariadb

POSTGRESQL_PATH := $(DEPS_PATH)/postgresql/postgresql/src
POSTGRESQL_IDIR := $(POSTGRESQL_PATH)/include -I$(POSTGRESQL_PATH)/interfaces/libpq
POSTGRESQL_LDIR := $(POSTGRESQL_PATH)/interfaces/libpq -L$(POSTGRESQL_PATH)/common -L$(POSTGRESQL_PATH)/port

JEMALLOC_PATH := $(DEPS_PATH)/jemalloc/jemalloc
JEMALLOC_IDIR := $(JEMALLOC_PATH)/include/jemalloc
JEMALLOC_LDIR := $(JEMALLOC_PATH)/lib

JSON_IDIR := $(DEPS_PATH)/json

RE2_PATH := $(DEPS_PATH)/re2/re2
RE2_IDIR := $(RE2_PATH)
RE2_LDIR := $(RE2_PATH)/obj

SQLITE3_PATH := $(DEPS_PATH)/sqlite3/sqlite3
SQLITE3_IDIR := $(SQLITE3_PATH)
SQLITE3_LDIR := $(SQLITE3_PATH)

LIBHTTPSERVER_DIR := $(DEPS_PATH)/libhttpserver/libhttpserver
LIBHTTPSERVER_IDIR := $(LIBHTTPSERVER_DIR)/src
LIBHTTPSERVER_LDIR := $(LIBHTTPSERVER_DIR)/build/src/.libs/

LIBCONFIG_PATH := $(DEPS_PATH)/libconfig/libconfig
LIBCONFIG_IDIR := $(LIBCONFIG_PATH)/lib
LIBCONFIG_LDIR := $(LIBCONFIG_PATH)/out

CURL_DIR := $(DEPS_PATH)/curl/curl
CURL_IDIR := $(CURL_DIR)/include
CURL_LDIR := $(CURL_DIR)/lib/.libs

DAEMONPATH := $(DEPS_PATH)/libdaemon/libdaemon
DAEMONPATH_IDIR := $(DAEMONPATH)
DAEMONPATH_LDIR := $(DAEMONPATH)/libdaemon/.libs

PCRE_PATH := $(DEPS_PATH)/pcre/pcre
PCRE_LDIR := $(PCRE_PATH)/.libs

MICROHTTPD_DIR := $(DEPS_PATH)/libmicrohttpd/libmicrohttpd/src
MICROHTTPD_IDIR := $(MICROHTTPD_DIR)/include
MICROHTTPD_LDIR := $(MICROHTTPD_DIR)/microhttpd/.libs

LIBINJECTION_DIR := $(DEPS_PATH)/libinjection/libinjection
LIBINJECTION_IDIR := $(LIBINJECTION_DIR)/src
LIBINJECTION_LDIR := $(LIBINJECTION_DIR)/src

EV_DIR := $(DEPS_PATH)/libev/libev/
EV_IDIR := $(EV_DIR)
EV_LDIR := $(EV_DIR)/.libs

PROMETHEUS_PATH := $(DEPS_PATH)/prometheus-cpp/prometheus-cpp
PROMETHEUS_IDIR := $(PROMETHEUS_PATH)/pull/include -I$(PROMETHEUS_PATH)/core/include
PROMETHEUS_LDIR := $(PROMETHEUS_PATH)/lib

CITYHASH_DIR := $(DEPS_PATH)/cityhash/cityhash/
CITYHASH_IDIR := $(CITYHASH_DIR)
CITYHASH_LDIR := $(CITYHASH_DIR)/src/.libs

COREDUMPER_DIR := $(DEPS_PATH)/coredumper/coredumper
COREDUMPER_IDIR := $(COREDUMPER_DIR)/include
COREDUMPER_LDIR := $(COREDUMPER_DIR)/src

POSTGRESQL_PATH := $(DEPS_PATH)/postgresql/postgresql/src
POSTGRESQL_IDIR := $(POSTGRESQL_PATH)/include -I$(POSTGRESQL_PATH)/interfaces/libpq
POSTGRESQL_LDIR := $(POSTGRESQL_PATH)/interfaces/libpq -L$(POSTGRESQL_PATH)/common -L$(POSTGRESQL_PATH)/port

LIBUSUAL_PATH := $(DEPS_PATH)/libusual/libusual
LIBUSUAL_IDIR := $(LIBUSUAL_PATH)
LIBUSUAL_LDIR := $(LIBUSUAL_PATH)/.libs/

LIBSCRAM_PATH := $(DEPS_PATH)/libscram/
LIBSCRAM_IDIR := $(LIBSCRAM_PATH)/include/
LIBSCRAM_LDIR := $(LIBSCRAM_PATH)/lib/

LIBPROXYSQLAR := $(PROXYSQL_LDIR)/libproxysql.a

ODIR := $(PROXYSQL_PATH)/obj

EXECUTABLE := proxysql

OBJ := $(PROXYSQL_PATH)/src/obj/proxysql_global.o $(PROXYSQL_PATH)/src/obj/main.o $(PROXYSQL_PATH)/src/obj/proxy_tls.o

IDIRS := -I$(RE2_IDIR) -I$(PROXYSQL_IDIR) -I$(JEMALLOC_IDIR) -I$(LIBCONFIG_IDIR) -I$(MARIADB_IDIR)\
		 -I$(DAEMONPATH_IDIR) -I$(MICROHTTPD_IDIR) -I$(LIBHTTPSERVER_IDIR) -I$(CURL_IDIR) -I$(EV_IDIR)\
		 -I$(PROMETHEUS_IDIR) -I$(SQLITE3_IDIR) -I$(JSON_IDIR) -I$(POSTGRESQL_IDIR) -I$(LIBSCRAM_IDIR)\
		 -I$(LIBUSUAL_IDIR)

LDIRS := -L$(RE2_LDIR) -L$(PROXYSQL_LDIR) -L$(JEMALLOC_LDIR) -L$(LIBCONFIG_LDIR) -L$(MARIADB_LDIR)\
		 -L$(DAEMONPATH_LDIR) -L$(MICROHTTPD_LDIR) -L$(LIBHTTPSERVER_LDIR) -L$(CURL_LDIR) -L$(EV_LDIR)\
		 -L$(PROMETHEUS_LDIR) -L$(PCRE_LDIR) -L$(LIBINJECTION_LDIR) -L$(POSTGRESQL_LDIR) -L$(LIBSCRAM_LDIR)\
		 -L$(LIBUSUAL_LDIR) -L$(PROJECT_ROOT)

UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
	LDIRS += -L$(COREDUMPER_LDIR)
endif

MYLIBS_DYNAMIC_PART := -Wl,--export-dynamic -Wl,-Bdynamic -lgnutls -lcurl -lssl -lcrypto -luuid
MYLIBS_STATIC_PART := -Wl,-Bstatic -lconfig -ldaemon -lconfig++ -lre2 -lpcrecpp -lpcre \
	-lmariadbclient -lhttpserver -lmicrohttpd -linjection -lev -lprometheus-cpp-pull \
	-lprometheus-cpp-core -l$(MYSQL_TARGET_LIB_NAME)
MYLIBS_PG_PART := -Wl,-Bstatic -lpq -lpgcommon -lpgport
MYLIBS_LAST_PART := -Wl,-Bdynamic -lpthread -lm -lz -lrt -ldl $(EXTRALINK)
MYLIBS := $(MYLIBS_DYNAMIC_PART) $(MYLIBS_STATIC_PART) $(MYLIBS_PG_PART) $(MYLIBS_LAST_PART)

.PHONY: all clean examples pgsql mysql

all: pgsql mysql examples tests

pgsql: $(PGSQL_TARGET_LIB)
mysql: $(MYSQL_TARGET_LIB)

examples: $(PGSQL_EXAMPLE_EXE) $(MYSQL_EXAMPLE_EXE) $(MYSQL_SET_EXAMPLE_EXE) $(MYSQL_STDIN_EXAMPLE_EXE)
tests: $(TEST_REGEXES_PARITY)

# --- PostgreSQL Rules ---
$(PGSQL_TARGET_LIB): $(PGSQL_LIB_OBJS)
	ar rcs $@ $(PGSQL_LIB_OBJS)
	@echo "Created library $@"

$(PGSQL_EXAMPLE_EXE): $(PGSQL_EXAMPLE_OBJS) $(PGSQL_TARGET_LIB)
	$(LINKER) $(CXXFLAGS) -o $@ $(PGSQL_EXAMPLE_OBJS) -L$(PROJECT_ROOT) -l$(PGSQL_TARGET_LIB_NAME)
	@echo "Created PostgreSQL example $@"

$(PGSQL_BISON_H) $(PGSQL_BISON_C): $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.y $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_ast.h $(PGSQL_PARSER_INCLUDE_DIR)/pgsql_parser.h
	cd $(PGSQL_PARSER_SRC_DIR) && bison -Wcounterexamples -d -v --report=all pgsql_parser.y

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

# Rule for MySQL SET example executable
$(MYSQL_SET_EXAMPLE_EXE): $(MYSQL_SET_EXAMPLE_OBJS) $(MYSQL_TARGET_LIB)
	$(LINKER) $(CXXFLAGS) -o $@ $(MYSQL_SET_EXAMPLE_OBJS) -L$(PROJECT_ROOT) -l$(MYSQL_TARGET_LIB_NAME)
	@echo "Created MySQL SET statement example $@"

$(PROJECT_ROOT)/tests/test_regexes_parity.o: $(PROJECT_ROOT)/tests/test_regexes_parity.cpp $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h $(MYSQL_PARSER_INCLUDE_DIR)/mysql_ast.h
	$(CXX) $(CXXFLAGS) $(IDIRS) $(CPPFLAGS) -c $< -o $@

$(TEST_REGEXES_PARITY): $(PROJECT_ROOT)/tests/test_regexes_parity.o $(MYSQL_TARGET_LIB)
	$(LINKER) $(CXXFLAGS) $(IDIRS) $(LDIRS) -o $@ $(PROJECT_ROOT)/tests/test_regexes_parity.o $(PROXYSQL_PATH)/lib/obj/MySQL_Set_Stmt_Parser.oo $(PROXYSQL_PATH)/lib/obj/c_tokenizer.oo $(MYLIBS)

# Rule for MySQL STDIN parser example executable
$(MYSQL_STDIN_EXAMPLE_EXE): $(MYSQL_STDIN_EXAMPLE_OBJS) $(MYSQL_TARGET_LIB)
	$(LINKER) $(CXXFLAGS) -o $@ $(MYSQL_STDIN_EXAMPLE_OBJS) -L$(PROJECT_ROOT) -l$(MYSQL_TARGET_LIB_NAME)
	@echo "Created MySQL STDIN parser example $@"

$(MYSQL_BISON_H) $(MYSQL_BISON_C): $(MYSQL_PARSER_SRC_DIR)/mysql_parser.y $(MYSQL_PARSER_INCLUDE_DIR)/mysql_ast.h $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h
	cd $(MYSQL_PARSER_SRC_DIR) && bison -Wcounterexamples -d -v --report=all -o $(MYSQL_BISON_C_FILE) --defines=$(MYSQL_BISON_H_FILE) mysql_parser.y

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

# Rule for MySQL SET example main.o
$(PROJECT_ROOT)/examples/set_mysql_example.o: $(PROJECT_ROOT)/examples/set_mysql_example.cpp $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h $(MYSQL_PARSER_INCLUDE_DIR)/mysql_ast.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@

# Rule for MySQL STDIN parser example main.o
$(PROJECT_ROOT)/examples/mysql_stdin_parser_example.o: $(PROJECT_ROOT)/examples/mysql_stdin_parser_example.cpp $(MYSQL_PARSER_INCLUDE_DIR)/mysql_parser.h $(MYSQL_PARSER_INCLUDE_DIR)/mysql_ast.h
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $< -o $@


clean:
	rm -f $(PGSQL_TARGET_LIB) $(PGSQL_EXAMPLE_EXE) $(MYSQL_TARGET_LIB) $(MYSQL_EXAMPLE_EXE) $(MYSQL_SET_EXAMPLE_EXE) $(MYSQL_STDIN_EXAMPLE_EXE)
	rm -f $(PGSQL_LIB_OBJS) $(PGSQL_EXAMPLE_OBJS) $(MYSQL_LIB_OBJS) $(MYSQL_EXAMPLE_OBJS) $(MYSQL_SET_EXAMPLE_OBJS) $(MYSQL_STDIN_EXAMPLE_OBJS)
	rm -f $(PGSQL_BISON_C) $(PGSQL_BISON_H) $(PGSQL_FLEX_C)
	rm -f $(MYSQL_BISON_C) $(MYSQL_BISON_H) $(MYSQL_FLEX_C)
	rm -f $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.output $(PGSQL_PARSER_SRC_DIR)/pgsql_parser.report
	rm -f $(MYSQL_PARSER_SRC_DIR)/mysql_parser.output $(MYSQL_PARSER_SRC_DIR)/mysql_parser.report
	rm -f $(PGSQL_PARSER_SRC_DIR)/lex.backup $(MYSQL_PARSER_SRC_DIR)/lex.backup
	@echo "Cleaned up project."
