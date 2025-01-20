
run: 
	zig build && ./zig-out/bin/tls

test: 
	zig test src/tests.zig
