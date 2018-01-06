module rtf2any.rtf.writer;

import std.array;
import std.ascii;
import std.conv;

struct RTFWriter
{
	Appender!(char[]) buf;
	bool postDir = false;

	static private bool isTagChar(char c) { return c.isAlphaNum || c == '-' || c == '.'; }

	void putDir(Args...)(string dir, Args args)
	{
		buf.put("\\");
		buf.put(dir);
		foreach (arg; args)
			buf.put(arg.text);
		if (!args.length && !isTagChar(dir[$-1]))
			postDir = false;
		else
			postDir = true;
	}

	void newLine()
	{
		buf.put("\n");
		postDir = false;
	}

	private void putRawText(string s)
	{
		if (!s.length)
			return;
		if (postDir && (isTagChar(s[0]) || s[0] == ' '))
			buf.put(" ");
		buf.put(s);
		postDir = false;
	}

	void putText(string s)
	{
		foreach (dchar c; s)
			if (c == '\\' || c == '{' || c == '}')
				putDir(c.text);
			else
			if (c >= 0x80)
			{
				putDir("u", int(c));
				putRawText("?");
			}
			else
			if (c >= 0x20)
				putRawText(c.text);
			else
				throw new Exception("Control character in input: " ~ s);
	}

	void beginGroup() { buf.put("{"); postDir = false; }
	void endGroup() { buf.put("}"); postDir = false; }
}
