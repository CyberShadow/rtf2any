module rtf2any.common;

import std.string;

enum BlockType { Text, NewParagraph, PageBreak }

struct Font
{
	int index;

	/// nil/swiss/modern/roman/...
	/// See https://msdn.microsoft.com/en-us/library/windows/desktop/dd144832(v=vs.85).aspx
	string family;

	string name;
	int pitch; /// fprq
	int charset;
}

struct BlockAttr
{
	bool bold, italic, underline;
	int listLevel;
	int fontSize;
	int fontColor;
	int tabCount;
	Font* font;

	string toString()
	{
		string[] attrs;
		if (bold) attrs ~= "bold";
		if (italic) attrs ~= "italic";
		if (underline) attrs ~= "underline";
		if (listLevel) attrs ~= format("listLevel=%d", listLevel);
		if (fontSize) attrs ~= format("fontSize=%d", fontSize);
		if (fontColor) attrs ~= format("fontColor=%d", fontColor);
		if (tabCount) attrs ~= format("tabCount=%d", tabCount);
		return "[" ~ join(attrs, " ") ~ "]";
	}
}

struct Block
{
	BlockType type;
	BlockAttr attr;
	string text;

	string toString()
	{
		string s = attr.toString();
		final switch (type)
		{
		case BlockType.Text:
			return s ~ ` Text: ` ~ text;
		case BlockType.NewParagraph:
			return s ~ ` NewParagraph`;
		case BlockType.PageBreak:
			return s ~ ` PageBreak`;
		}
	}
}
