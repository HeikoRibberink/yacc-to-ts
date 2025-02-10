koka-dir = /home/heiko/Documents/code/koka

in = $(koka-dir)/koka/doc/spec/grammar/parser.y ./grammar.js
ex = yacc-to-ts
srcs != find -iname "*.kk"
flags =
include = $(koka-dir)/aoc24/lib/


%: %.kk $(srcs)
	koka --include=$(include) -o $@ $<

.PHONY: watch
watch:
	find -iname "*.kk" | entr make run

.PHONY: input
input:
	cat $(in)

.PHONY: run
run: $(ex)
	chmod +x ./$<
	./$< $(in)

