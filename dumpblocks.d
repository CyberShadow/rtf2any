module rtf2any.dumpblocks;

import std.file;
import std.stdio;

import rtf2any.rtf;

void main(string[] args)
{
	auto rtf = cast(string)read(args[1]);
	auto blocks = parseRTF(rtf);
	foreach (ref block; blocks)
		writeln(block);
}
