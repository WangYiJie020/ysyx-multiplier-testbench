# Standalone build for the external NEMU Kconfig frontend.
CC ?= gcc
CFLAGS ?= -O2
CPPFLAGS += -DYYDEBUG=1 -I. -Ibuild $(shell pkg-config --cflags ncurses 2>/dev/null)
LDLIBS += $(shell pkg-config --libs ncurses 2>/dev/null || echo -lncurses)
COMMON := confdata.c expr.c preprocess.c symbol.c util.c build/lexer.lex.c build/parser.tab.c
SOURCES := $(COMMON) mconf.c $(wildcard lxdialog/*.c)
OBJECTS := $(patsubst %.c,build/%.o,$(SOURCES))

.PHONY: all clean
all: build/conf build/mconf

build/conf: $(patsubst %.c,build/%.o,$(COMMON)) build/conf.o
	$(CC) $(CFLAGS) $^ -o $@

build/mconf: $(OBJECTS)
	$(CC) $(CFLAGS) $^ $(LDLIBS) -o $@

build/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

build/lexer.lex.c: lexer.l build/parser.tab.h
	flex -o $@ $<

build/parser.tab.c build/parser.tab.h &: parser.y
	@mkdir -p build
	bison --defines=build/parser.tab.h -o build/parser.tab.c $<

clean:
	rm -rf build

-include $(OBJECTS:.o=.d)

$(OBJECTS) build/conf.o: ../../scripts/kconfig-build.mk
