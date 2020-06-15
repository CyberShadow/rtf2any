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
			switch (c)
			{
				case '\\':
				case '{':
				case '}':
					putDir(c.text);
					break;

				case '\&mdash;' : putDir("emdash"   ); break;
				case '\&ndash;' : putDir("endash"   ); break;
				case '\&lsquo;' : putDir("lquote"   ); break;
				case '\&rsquo;' : putDir("rquote"   ); break;
				case '\&ldquo;' : putDir("ldblquote"); break;
				case '\&rdquo;' : putDir("rdblquote"); break;
				case '\&bullet;': putDir("bullet"   ); break;
				case '\&nbsp;'  : putDir("~"        ); break;

				case 0x00:
					..
				case 0x1F:
					throw new Exception("Control character in input: " ~ s);

				default:
					if (c >= 0x80)
					{
						putDir("u", int(c));
						putRawText("?");
					}
					else
						putRawText(c.text);
			}
	}

	void beginGroup() { buf.put("{"); postDir = false; }
	void endGroup() { buf.put("}"); postDir = false; }
}
