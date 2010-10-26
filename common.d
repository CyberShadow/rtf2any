module rtf2any.common;

enum BlockType { Text, NewParagraph, PageBreak }

struct BlockAttr
{
	bool bold, italic, underline;
	int listLevel;
	int fontSize;
	int fontColor;
}

struct Block
{
	BlockType type;
	BlockAttr attr;
	string text;
}
