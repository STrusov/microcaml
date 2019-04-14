TARGET = model1
SRCS = $(TARGET).ml
OBJS = *.cmi *.cmo

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(CRSC)
	ocamlc -o $(TARGET) $(SRCS)

clean:
	rm -rf $(TARGET) $(OBJS)
