module rtf2any.rtf.parser;

import ae.utils.array;
import ae.utils.iconv;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;
import std.utf;

import rtf2any.common;
import rtf2any.rtf.lexer;

enum Charset : uint
{
    ANSI        = 0,
    DEFAULT     = 1,
    SYMBOL      = 2,
    MAC         = 77,
    SHIFTJIS    = 128,
    HANGEUL     = 129,
    HANGUL      = 129,
    JOHAB       = 130,
    GB2312      = 134,
    CHINESEBIG5 = 136,
    GREEK       = 161,
    TURKISH     = 162,
    VIETNAMESE  = 163,
    HEBREW      = 177,
    ARABIC      = 178,
    BALTIC      = 186,
    RUSSIAN     = 204,
    THAI        = 222,
    EASTEUROPE  = 238,
    OEM         = 255
}

enum CodePage : uint
{
    ACP,
    OEMCP,
    MACCP,
    THREAD_ACP, // =     3
    SYMBOL         =    42,
    UTF7           = 65000,
    UTF8           = 65001
}

uint charsetToCodepage(uint charset)
{
	switch (charset)
	{
		case Charset.ANSI:
			return 1252;
		case Charset.DEFAULT:
			throw new Exception("System-specific charset");
		case Charset.SYMBOL:
			return CodePage.SYMBOL;
		case Charset.EASTEUROPE:
			return 1250;
		case Charset.GREEK:
			return 1253;
		default:
			throw new Exception("Unknown charset: " ~ charset.text);
	}
}

/// Returns name for ae.utils.iconv.
string getCodePageName(uint codepage)
{
	switch (codepage)
	{
		case 1250:
			return "windows1250";
		case 1252:
			return "windows1252";
		case 1253:
			return "windows1253";
		case CodePage.SYMBOL:
			return "ascii8";
		default:
			throw new Exception("Unknown codepage: " ~ codepage.text);
	}
}

struct Parser
{
	Element[] elements;
	Block[] blocks;

	int[] colors;
	Font[int] fonts;
	int defaultCodepage;

	void parse(Element[] elements, ref BlockAttr parentAttr, Element[] stack)
	{
		BlockAttr attr = parentAttr;
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
				if (attr.list)
					attr.listItemIndex = attr.paragraphIndex;
			}

			final switch (e.type)
			{
			case ElementType.Text:
				preAppend();
				blocks ~= Block(BlockType.Text, attr, e.text);
				break;
			case ElementType.Group:
				if (e.type == ElementType.Group && e.group[0].word.word == "*")
					attr.list = true;
				parse(e.group, attr, stack ~ e);
				break;
			case ElementType.ControlWord:
				switch (e.word.word)
				{
				case "'":
				{
					// Replace the hex characters from next text block
					enforce(i+1 < elements.length && elements[i+1].type == ElementType.Text && elements[i+1].text.length >= 2, "Text block for hex escape expected");
					auto codepage = attr.font ? charsetToCodepage(attr.font.charset) : defaultCodepage;
					elements[i+1].text = toUtf8([cast(char)fromHex(elements[i+1].text[0..2])], getCodePageName(codepage)) ~ elements[i+1].text[2..$];
					break;
				}
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
					parAttr.bold = parAttr.italic = parAttr.underline = false; // TODO: these shouldn't be discarded!
					parAttr.subSuper = SubSuper.none;
					parAttr.fontColor = defaultColor;
					parAttr.columnIndex = -1;
					blocks ~= Block(BlockType.NewParagraph, parAttr);
					attr.paragraphIndex++;
					attr.columnIndex = 0;
					break;
				case "page":
					preAppend();
					blocks ~= Block(BlockType.PageBreak);
					break;
				case "pard":
					attr.leftIndent = parentAttr.leftIndent;
					attr.firstLineIndent = parentAttr.firstLineIndent;
					attr.tabs = parentAttr.tabs;
					attr.alignment = Alignment.left;
					attr.list = false;
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
					defaultCodepage = e.word.num;
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
				case "ql": attr.alignment = Alignment.left; break;
				case "qc": attr.alignment = Alignment.center; break;
				case "qr": attr.alignment = Alignment.right; break;
				case "qj": attr.alignment = Alignment.justify; break;
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
				case "pnlvlcont":
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

		{
			Block[][] paragraphs = [];
			size_t parStart = 0;
			foreach (bi, ref block; blocks)
				if (block.type == BlockType.NewParagraph)
				{
					paragraphs ~= blocks[parStart..bi+1];
					parStart = bi + 1;
				}
			paragraphs ~= blocks[parStart..$];

			auto haveTabs = paragraphs.map!(paragraph => paragraph.any!((ref Block block) => block.type == BlockType.Tab)).array;
			auto haveTabStops = paragraphs.map!(paragraph => paragraph.any!((ref Block block) => block.attr.tabs.length != 0)).array;

			/// Unmark tab stops in paragraphs that do not have tabs
			void unmarkTabs(size_t i)
			{
				foreach (ref block; paragraphs[i])
					block.attr.tabs = null;
				haveTabStops[i] = false;
			}
			{
				/// Maximum number of contiguous paragraphs that may
				/// have useless tab stops.
				enum maxParagraphs = 10;

				size_t start = size_t.max;
				foreach (i; 0..paragraphs.length)
					if (haveTabStops[i] && !haveTabs[i])
					{
						if (start == size_t.max)
							start = i;
					}
					else
						if (start != size_t.max)
						{
							if (i - start > maxParagraphs)
							foreach (n; start..i)
								unmarkTabs(n);
							start = size_t.max;
						}
			}
			foreach (i; 1..paragraphs.length)
				if (haveTabStops[i] && !haveTabStops[i-1] && !haveTabs[i])
					unmarkTabs(i);
			foreach_reverse (i; 0..paragraphs.length-1)
				if (haveTabStops[i] && !haveTabStops[i+1] && !haveTabs[i])
					unmarkTabs(i);

			// Paint paragraphs that have tabs but not tab stops
			foreach (i, paragraph; paragraphs)
				if (!haveTabStops[i] && haveTabs[i])
					foreach (ref block; paragraph)
						block.attr.tabs = emptySlice!int;

			/// Unmark columns in paragraphs that do not have tabs or tab stops
			foreach (i, paragraph; paragraphs)
				if (!haveTabs[i] && !haveTabStops[i])
					foreach (ref block; paragraph)
						block.attr.columnIndex = -1;

			blocks = paragraphs.join;
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
