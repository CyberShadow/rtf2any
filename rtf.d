module rtf2any.rtf;

import std.conv;
import std.exception;
import std.string;
import std.utf;

import rtf2any.common;

struct ControlWord
{
	string word;
	int _num;
	bool haveNum;

	@property int num() { assert(haveNum); return _num; }
	@property void num(int value) { haveNum = true; _num = value; }

	@property bool flag()
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

	string toString()
	{
		final switch (type)
		{
			case ElementType.Text:
				return format("%(%s%)", [text]);
			case ElementType.ControlWord:
				return word.text;
			case ElementType.Group:
				return group.text;
		}
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
	Font[int] fonts;

	void parse(Element[] elements, BlockAttr initAttr, Element[] stack)
	{
		BlockAttr attr = initAttr;
		// Parse special control words at the beginning of groups
		if (elements.length && elements[0].type == ElementType.ControlWord)
			switch (elements[0].word.word)
			{
			case "fonttbl":
				fonts = null;
				foreach (ref e; elements[1..$])
				{
					enforce(e.type == ElementType.Group, "Group expected as fonttbl child");
					Font font;
					int fontIndex;

					foreach (i, ref f; e.group)
					{
						final switch (f.type)
						{
							case ElementType.Text:
								enforce(f.text.endsWith(";"), "Expected ';' fonttbl entry terminator");
								enforce(i+1 == e.group.length, "';' terminator not at the end");
								font.name = f.text[0..$-1];
								break;
							case ElementType.ControlWord:
								switch (f.word.word)
								{
								case "f":
									fontIndex = f.word.num;
									break;
								case "fprq":
									font.pitch = f.word.num;
									break;
								case "fcharset":
									font.charset = f.word.num;
									break;
								default:
									enforce(f.word.word.startsWith("f"), "Unknown font property");
									font.family = f.word.word[1..$];
								}
								break;
							case ElementType.Group:
								/// fallbacks - discard
								break;
						}
					}

					fonts[fontIndex] = font;
				}
				return;
			case "colortbl":
				int color = defaultColor;
				foreach (ref e; elements[1..$])
				{
					if (e.type == ElementType.Text)
					{
						enforce(e.text == ";", "Expected ';' colortbl terminator");
						colors ~= color;
						color = defaultColor;
					}
					else
					{
						enforce(e.type == ElementType.ControlWord, "Unexpected token type");
						if (color == defaultColor)
							color = 0;
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
							enforce(false, "Unknown color channel");
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
		{
			void preAppend()
			{
			}

			final switch (e.type)
			{
			case ElementType.Text:
				preAppend();
				blocks ~= Block(BlockType.Text, attr, e.text);
				break;
			case ElementType.Group:
				if (e.type == ElementType.Group && e.group[0].word.word == "pntext")
					attr.list = true;
				parse(e.group, attr, stack ~ e);
				break;
			case ElementType.ControlWord:
				switch (e.word.word)
				{
				case "'":
					// Replace the hex characters from next text block
					enforce(i+1 < elements.length && elements[i+1].type == ElementType.Text && elements[i+1].text.length >= 2, "Text block for hex escape expected");
					elements[i+1].text = toUTF8([cast(dchar)windows1252[fromHex(elements[i+1].text[0..2])]]) ~ elements[i+1].text[2..$];
					break;
				case "u":
					// Replace fallback question mark in next text block
					enforce(i+1 < elements.length && elements[i+1].type == ElementType.Text && elements[i+1].text.length >= 1, "Text block for Unicode expected");
					enforce(elements[i+1].text[0] == '?', "Question mark in Unicode expected");
					elements[i+1].text = toUTF8([cast(dchar)e.word.num]) ~ elements[i+1].text[1..$];
					break;
				case "\\":
				case "{":
				case "}":
					preAppend();
					blocks ~= Block(BlockType.Text, attr, e.word.word);
					break;
				case "emdash"   : preAppend(); blocks ~= Block(BlockType.Text, attr, "\&mdash;" ); break;
				case "endash"   : preAppend(); blocks ~= Block(BlockType.Text, attr, "\&ndash;" ); break;
				case "lquote"   : preAppend(); blocks ~= Block(BlockType.Text, attr, "\&lsquo;" ); break;
				case "rquote"   : preAppend(); blocks ~= Block(BlockType.Text, attr, "\&rsquo;" ); break;
				case "ldblquote": preAppend(); blocks ~= Block(BlockType.Text, attr, "\&ldquo;" ); break;
				case "rdblquote": preAppend(); blocks ~= Block(BlockType.Text, attr, "\&rdquo;" ); break;
				case "bullet"   : preAppend(); blocks ~= Block(BlockType.Text, attr, "\&bullet;"); break;
				case "~"        : preAppend(); blocks ~= Block(BlockType.Text, attr, "\&nbsp;"  ); break;
				case "tab":
					preAppend();
					BlockAttr tabAttr = attr;
					blocks ~= Block(BlockType.Tab, tabAttr);
					attr.columnIndex++;
					break;
				case "par":
					preAppend();
					BlockAttr parAttr = attr;
					// discard some attributes for endlines
					parAttr.bold = parAttr.italic = parAttr.underline = false;
					parAttr.subSuper = SubSuper.none;
					parAttr.fontColor = defaultColor;
					parAttr.columnIndex = -1;
					blocks ~= Block(BlockType.NewParagraph, parAttr);
					attr.paragraphIndex++;
					attr.columnIndex = 0;
					attr.list = false;
					break;
				case "page":
					preAppend();
					blocks ~= Block(BlockType.PageBreak);
					break;
				case "pard":
					attr.leftIndent = initAttr.leftIndent;
					attr.firstLineIndent = initAttr.firstLineIndent;
					attr.tabs = initAttr.tabs;
					attr.center = false;
					break;
				case "f":
					attr.font = &fonts[e.word.num];
					break;
				case "cf":
					attr.fontColor = colors[e.word.num];
					break;
				case "fs":
					attr.fontSize = e.word.num;
					break;
				case "fi":
					attr.firstLineIndent = e.word.num;
					break;
				case "li":
					attr.leftIndent = e.word.num;
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
				case "tx":
					attr.tabs ~= e.word.num;
					break;
				case "rtf":
					enforce(stack.length == 0 && i == 0, "rtf control word not at document start");
					break;
				case "ansi":
					break;
				case "ansicpg":
					enforce(e.word.num == 1252, "Unsupported codepage");
					break;
				case "deff":
					enforce(e.word.num == 0, "Unsupported default font");
					break;
				case "deflang":
				case "deflangfe":
				case "viewkind":
					break;
				case "uc":
					enforce(e.word.num == 1, "Unsupported Unicode substitution character count");
					break;
				case "nowidctlpar":
					// no-op without \widowctrl or \widctlpar
					break;
				case "qc":
					attr.center = true;
					break;
				case "qj":
					attr.center = false;
					break;
				case "sub":
					attr.subSuper = SubSuper.subscript;
					break;
				case "super":
					attr.subSuper = SubSuper.superscript;
					break;
				case "nosupersub":
					attr.subSuper = SubSuper.none;
					break;
				case "*":
				case "pn":
				case "pnlvlblt":
				case "pnf":
				case "pnindent":
					// Bullet list backwards compatibility
					break;
				case "lang":
					// Semantic-only?
					break;
				case "ri":
					// Right-align - unsupported
					break;
				default:
					throw new Exception("Unknown XML control word: " ~ e.word.word);
				}
				break;
			}
		}
	}

	Block[] parse()
	{
		BlockAttr attr; // default attributes
		parse(elements, attr, null);

		/// Unmark columns in paragraphs that do not have tabs.
		{
			size_t parStart = 0;
			bool sawTab = false;
			foreach (bi, ref block; blocks)
				if (block.type == BlockType.Tab)
					sawTab = true;
				else
				if (block.type == BlockType.NewParagraph)
				{
					if (!sawTab)
						foreach (ref b; blocks[parStart..bi])
							b.attr.columnIndex = -1;
					sawTab = false;
					parStart = bi + 1;
				}
		}

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
			default: enforce(false, "Unknown hex digit");
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

ushort[256] windows1252 = [
	0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009, 0x000A, 0x000B, 0x000C, 0x000D, 0x000E, 0x000F,
	0x0010, 0x0011, 0x0012, 0x0013, 0x0014, 0x0015, 0x0016, 0x0017, 0x0018, 0x0019, 0x001A, 0x001B, 0x001C, 0x001D, 0x001E, 0x001F,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027, 0x0028, 0x0029, 0x002A, 0x002B, 0x002C, 0x002D, 0x002E, 0x002F,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037, 0x0038, 0x0039, 0x003A, 0x003B, 0x003C, 0x003D, 0x003E, 0x003F,
	0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047, 0x0048, 0x0049, 0x004A, 0x004B, 0x004C, 0x004D, 0x004E, 0x004F,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057, 0x0058, 0x0059, 0x005A, 0x005B, 0x005C, 0x005D, 0x005E, 0x005F,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067, 0x0068, 0x0069, 0x006A, 0x006B, 0x006C, 0x006D, 0x006E, 0x006F,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077, 0x0078, 0x0079, 0x007A, 0x007B, 0x007C, 0x007D, 0x007E, 0x007F,
	0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
	0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178,
	0x00A0, 0x00A1, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7, 0x00A8, 0x00A9, 0x00AA, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF,
	0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7, 0x00B8, 0x00B9, 0x00BA, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x00BF,
	0x00C0, 0x00C1, 0x00C2, 0x00C3, 0x00C4, 0x00C5, 0x00C6, 0x00C7, 0x00C8, 0x00C9, 0x00CA, 0x00CB, 0x00CC, 0x00CD, 0x00CE, 0x00CF,
	0x00D0, 0x00D1, 0x00D2, 0x00D3, 0x00D4, 0x00D5, 0x00D6, 0x00D7, 0x00D8, 0x00D9, 0x00DA, 0x00DB, 0x00DC, 0x00DD, 0x00DE, 0x00DF,
	0x00E0, 0x00E1, 0x00E2, 0x00E3, 0x00E4, 0x00E5, 0x00E6, 0x00E7, 0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x00EC, 0x00ED, 0x00EE, 0x00EF,
	0x00F0, 0x00F1, 0x00F2, 0x00F3, 0x00F4, 0x00F5, 0x00F6, 0x00F7, 0x00F8, 0x00F9, 0x00FA, 0x00FB, 0x00FC, 0x00FD, 0x00FE, 0x00FF,
];
