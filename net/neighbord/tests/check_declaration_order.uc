#!/usr/bin/ucode
/*
 * ucode resolves a call to another top-level function by its declaration
 * position in the source, not by execution order: a function can only call
 * another top-level function whose "function" declaration appears earlier
 * in the file, even if the call itself only happens well after the later
 * declaration has executed (e.g. from a uloop callback). Calling a
 * forward-declared function raises "left-hand side is not a function" at
 * runtime. This check rejects any such forward reference.
 */

let fs = require("fs");

let path = ARGV[0];
if (!path) {
	warn("usage: check_declaration_order.uc <file>\n");
	exit(1);
}

let text = fs.readfile(path);
let lines = split(text, "\n");

let functions = [];
for (let i = 0; i < length(lines); i++) {
	let m = match(lines[i], /^function ([A-Za-z_][A-Za-z0-9_]*)\(/);
	if (m)
		push(functions, { name: m[1], line: i });
}

let declared_at = {};
for (let fn in functions)
	declared_at[fn.name] = fn.line;

let violations = [];
for (let idx = 0; idx < length(functions); idx++) {
	let fn = functions[idx];
	let end = (idx + 1 < length(functions)) ? functions[idx + 1].line : length(lines);
	let body = join("\n", slice(lines, fn.line + 1, end));

	for (let name, decl_line in declared_at) {
		if (name == fn.name || decl_line <= fn.line)
			continue;
		if (match(body, regexp("(^|[^A-Za-z0-9_])" + name + "\\(")))
			push(violations, sprintf("%s (line %d) calls %s, declared later at line %d",
			                          fn.name, fn.line + 1, name, decl_line + 1));
	}
}

if (length(violations)) {
	for (let v in violations)
		warn("not ok - forward reference: " + v + "\n");
	exit(1);
}

print("ok - no top-level function calls another declared later in the file\n");
