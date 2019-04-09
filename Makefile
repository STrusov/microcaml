TARGET = microcaml
PREFIX ?= /usr/local
SRCS = $(TARGET).asm
OBJS = $(SRCS:.asm=.o)
FASM = fasmg
LD = ld.bfd

.PHONY: all clean install uninstall

all: clean $(TARGET)

$(TARGET): $(OBJS)
#	$(LD) -pie -o $(TARGET) $(OBJS)
	$(LD) -o $(TARGET) $(OBJS)

$(OBJS):
	$(FASM) $(SRCS)

clean:
	rm -rf $(TARGET) $(OBJS)

install:
	install $(TARGET) $(PREFIX)/bin

uninstall:
	rm -rf $(PREFIX)/bin/$(TARGET)
