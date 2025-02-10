ex = yacc-to-ts
srcs != find -iname "*.kk"
in = #Input files

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

%: %.kk $(srcs)
	koka -o $@ $<
