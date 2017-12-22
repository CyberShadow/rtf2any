module rtf2any.common;

import std.string;

enum BlockType
{
	/// Unicode text. See "text" field.
	Text,

	/// List bullet.
	Bullet,

	/// \par
	NewParagraph,

	/// \tab
	Tab,

	/// \page
	PageBreak
}

struct Font
{
	/// nil/swiss/modern/roman/...
	/// See https://msdn.microsoft.com/en-us/library/windows/desktop/dd144832(v=vs.85).aspx
	string family;

	string name;
	int pitch; /// fprq
	int charset;
}

enum SubSuper { none, subscript, superscript }

struct BlockAttr
{
	bool bold, italic, underline, center;
	SubSuper subSuper;
	int leftIndent; /// in twips
	int firstLineIndent; /// relative to leftIndent
	int fontSize;
	int fontColor;
	int[] tabs; /// in twips
	int paragraphIndex, columnIndex;
	Font* font;

	string toString()
	{
		string[] attrs;
		if (bold) attrs ~= "bold";
		if (italic) attrs ~= "italic";
		if (underline) attrs ~= "underline";
		if (center) attrs ~= "center";
		if (subSuper) attrs ~= format("%s", subSuper);
		if (leftIndent) attrs ~= format("leftIndent=%d", leftIndent);
		if (firstLineIndent) attrs ~= format("firstLineIndent=%d", leftIndent);
		if (fontSize) attrs ~= format("fontSize=%d", fontSize);
		if (fontColor) attrs ~= format("fontColor=%d", fontColor);
		foreach (tab; tabs) attrs ~= format("tab=%d", tab);
		if (paragraphIndex >= 0) attrs ~= format("paragraphIndex=%d", paragraphIndex);
		if (columnIndex >= 0) attrs ~= format("columnIndex=%d", columnIndex);
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
		case BlockType.Bullet:
			return s ~ ` Bullet`;
		case BlockType.NewParagraph:
			return s ~ ` NewParagraph`;
		case BlockType.Tab:
			return s ~ ` Tab`;
		case BlockType.PageBreak:
			return s ~ ` PageBreak`;
		}
	}
}
