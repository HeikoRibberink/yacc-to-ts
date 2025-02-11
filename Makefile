ex = yacc-to-ts
srcs != find -iname "*.kk"
in = #Input files
flags = 
TEST_FILES != find tests/ -iname "*.js"

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
tests: $(TEST_FILES)
# Build rules

%: %.kk $(srcs)
	koka $(flags) -o $@ $<

tests/%.js: tests/%.y $(ex)
	./$(ex) $< $@

