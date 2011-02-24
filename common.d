module rtf2any.common;

import std.string;

enum BlockType { Text, NewParagraph, PageBreak }

struct BlockAttr
{
	bool bold, italic, underline;
	int listLevel;
	int fontSize;
	int fontColor;

	string toString()
	{
		string[] attrs;
		if (bold) attrs ~= "bold";
		if (italic) attrs ~= "italic";
		if (underline) attrs ~= "underline";
		if (listLevel) attrs ~= format("listLevel=%d", listLevel);
		if (fontSize) attrs ~= format("fontSize=%d", fontSize);
		if (fontColor) attrs ~= format("fontColor=%d", fontColor);
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
		string s = attr.toString;
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
