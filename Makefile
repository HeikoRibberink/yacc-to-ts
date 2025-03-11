ex = yacc-to-ts
srcs != find -iname "*.kk"
in = #Input files
flags =
tests != find tests/ -iname "*.y"

.PHONY: watch
watch:
	find -iname "*.kk" | entr make run

.PHONY: build
build: $(ex)

.PHONY: clean
clean:
	rm $(ex)

.PHONY: run
run: $(ex)
	chmod +x ./$<
	./$< $(in)
	
.PHONY: tests
tests: $(tests:.y=.js)
# Build rules

%: %.kk $(srcs)
	koka $(flags) -o $@ $<

tests/%.js: tests/%.y $(ex)
	./$(ex) $< $@

