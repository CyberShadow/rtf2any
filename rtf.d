module rtf2any.rtf;

import std.conv;
import std.utf;

import rtf2any.common;

struct ControlWord
{
	string word;
	int _num;
	bool haveNum;

	int num() { assert(haveNum); return _num; }
	void num(int value) { haveNum = true; _num = value; }

	bool flag()
	{
		if (haveNum)
		{
			assert (_num == 0);
			return false;
		}
		else
			return true;
	}
}

enum ElementType { Text, ControlWord, Group }

struct Element
{
	ElementType type;
	union
	{
		ControlWord word;
		Element[] group;
		string text;
	}
}

struct Lexer
{
	string rtf;
	int p;

	char peek()
	{
		return rtf[p];
	}

	char readChar()
	{
		//writef("%s", rtf[p]); stdout.flush();
		return rtf[p++];
	}

	void skipChar()
	{
		//writef("%s", rtf[p]); stdout.flush();
		p++;
	}

	void expect(char c)
	{
		char r = readChar();
		if (r != c)
			throw new Exception("Expected " ~ c ~ ", got " ~ r);
	}

	ControlWord readControlWord()
	{
		expect('\\');
		ControlWord word;
		bool inNum;
		string num;
		while (true)
		{
			char c = peek();
			if (!inNum && (c>='a' && c<='z') || (c>='A' && c<='Z'))
				word.word ~= c;
			else
			if (!inNum && c=='-')
			{
				inNum = true;
				num ~= c;
			}
			else
			if (c>='0' && c<='9')
			{
				inNum = true;
				num ~= c;
			}
			else
			if (c==' ')
			{
				skipChar();
				break;
			}
			else
			{
				if (word.word.length==0)
				{
					word.word = [c];
					skipChar();
				}
				break;
			}
			skipChar();
		}
		if (inNum)
			word.num = to!int(num);
		return word;
	}

	Element[] readGroup()
	{
		expect('{');
		Element[] elements;
		while (true)
		{
			char c = peek();
			switch (c)
			{
			case '\\':
			{
				auto e = Element(ElementType.ControlWord);
				e.word = readControlWord();
				elements ~= e;
				break;
			}
			case '{':
			{
				auto e = Element(ElementType.Group);
				e.group = readGroup();
				elements ~= e;
				break;
			}
			case '}':
				skipChar();
				return elements;
			case '\r':
			case '\n':
				skipChar();
				break;
			default:
				if (elements.length && elements[$-1].type == ElementType.Text)
					elements[$-1].text ~= c;
				else
				{
					auto e = Element(ElementType.Text);
					e.text = [c];
					elements ~= e;
				}
				skipChar();
				break;
			}
		}
	}

	Element[] lex()
	{
		return readGroup();
	}
}

struct Parser
{
	Element[] elements;
	Block[] blocks;

	int[] colors;

	void parse(Element[] elements, BlockAttr initAttr)
	{
		BlockAttr attr = initAttr;
		// Parse special control words at the beginning of groups
		if (elements.length && elements[0].type == ElementType.ControlWord)
			switch (elements[0].word.word)
			{
			case "fonttbl":
				return;
			case "colortbl":
				int color = 0;
				foreach (ref e; elements[1..$])
				{
					if (e.type == ElementType.Text)
					{
						assert(e.text == ";");
						colors ~= color;
						color = 0;
					}
					else
					{
						assert(e.type == ElementType.ControlWord);
						switch(e.word.word)
						{
						case "red":
							color |= e.word.num << 16;
							break;
						case "green":
							color |= e.word.num <<  8;
							break;
						case "blue":
							color |= e.word.num;
							break;
						default:
							assert(0);
						}
					}
				}
				return;
			case "pntext": // compatibility bullet char
				return;
			case "pntxtb": // bullet char specifier
				return;
			case "*":
				if (elements.length>1 && elements[1].type == ElementType.ControlWord)
					switch (elements[1].word.word)
					{
					case "generator":
						return;
					default:
					}
				break;
			default:
			}
		foreach (i, ref e; elements)
			switch (e.type)
			{
			case ElementType.Text:
				blocks ~= Block(BlockType.Text, attr, e.text);
				break;
			case ElementType.Group:
				parse(e.group, attr);
				break;
			case ElementType.ControlWord:
				switch (e.word.word)
				{
				case "'":
					// Replace the hex characters from next text block
					assert(i+1 < elements.length && elements[i+1].type == ElementType.Text && elements[i+1].text.length >= 2);
					elements[i+1].text = toUTF8([cast(dchar)fromHex(elements[i+1].text[0..2])]) ~ elements[i+1].text[2..$];
					break;
				case "u":
					// Replace fallback question mark in next text block
					assert(i+1 < elements.length && elements[i+1].type == ElementType.Text && elements[i+1].text.length >= 1);
					assert(elements[i+1].text[0] == '?');
					elements[i+1].text = toUTF8([cast(dchar)e.word.num]) ~ elements[i+1].text[1..$];
					break;
				case "\\":
				case "{":
				case "}":
					blocks ~= Block(BlockType.Text, attr, e.word.word);
					break;
				case "tab"      : blocks ~= Block(BlockType.Text, attr, "\t"      ); break;
				case "emdash"   : blocks ~= Block(BlockType.Text, attr, "\&mdash;"); break;
				case "endash"   : blocks ~= Block(BlockType.Text, attr, "\&ndash;"); break;
				case "lquote"   : blocks ~= Block(BlockType.Text, attr, "\&lsquo;"); break;
				case "rquote"   : blocks ~= Block(BlockType.Text, attr, "\&rsquo;"); break;
				case "ldblquote": blocks ~= Block(BlockType.Text, attr, "\&ldquo;"); break;
				case "rdblquote": blocks ~= Block(BlockType.Text, attr, "\&rdquo;"); break;
				case "par":
					BlockAttr parAttr;
					parAttr.listLevel = attr.listLevel; // discard all attributes except list level for endlines
					blocks ~= Block(BlockType.NewParagraph, parAttr);
					break;
				case "page":
					blocks ~= Block(BlockType.PageBreak);
					break;
				case "pard":
					attr.listLevel = initAttr.listLevel;
					break;
				case "cf":
					attr.fontColor = colors[e.word.num];
					break;
				case "fs":
					attr.fontSize = e.word.num;
					break;
				case "li":
					attr.listLevel = ((e.word.num) + 180) / 360; // HACK: W:A-readme-specific
					break;
				case "b":
					attr.bold = e.word.flag;
					break;
				case "i":
					attr.italic = e.word.flag;
					break;
				case "ul":
					attr.underline = true;
					break;
				case "ulnone":
					attr.underline = false;
					break;
				default:
					break;
				}
				break;
			default:
				assert(0);
			}
	}

	Block[] parse()
	{
		BlockAttr attr; // default attributes
		parse(elements, attr);
		return blocks;
	}
}

private uint fromHex(string s)
{
	uint n = 0;
	while (s.length)
	{
		int d;
		switch (s[0])
		{
			case '0':           d =  0; break;
			case '1':           d =  1; break;
			case '2':           d =  2; break;
			case '3':           d =  3; break;
			case '4':           d =  4; break;
			case '5':           d =  5; break;
			case '6':           d =  6; break;
			case '7':           d =  7; break;
			case '8':           d =  8; break;
			case '9':           d =  9; break;
			case 'a': case 'A': d = 10; break;
			case 'b': case 'B': d = 11; break;
			case 'c': case 'C': d = 12; break;
			case 'd': case 'D': d = 13; break;
			case 'e': case 'E': d = 14; break;
			case 'f': case 'F': d = 15; break;
			default: assert(0);
		}
		s = s[1..$];
		n = (n << 4) + d;
	}
	return n;
}

Block[] parseRTF(string rtf)
{
	return Parser(Lexer(rtf).lex()).parse();
}
