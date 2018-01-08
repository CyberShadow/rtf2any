module rtf2any.tools.dumpnestedblocks;

import std.file;
import std.stdio;

import rtf2any.formatter.nested;
import rtf2any.rtf.parser;

void main(string[] args)
{
	auto rtf = cast(string)read(args[1]);
	auto blocks = parseRTF(rtf);
	NestedFormatter.preprocess(blocks);
	foreach (ref block; blocks)
		writeln(block);
}
