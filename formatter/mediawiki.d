module rtf2any.formatter.mediawiki;

import rtf2any.common;
import rtf2any.formatter.nested;
import std.string;
import std.array;

class MediaWikiFormatter : NestedFormatter
{
	this(Block[] blocks) { super(blocks); }

	int listLevel, bulletPending;
	bool inTable;

	void pre()
	{
		if (bulletPending && listLevel)
		{
			if (!inTable)
			{
				foreach (i; 0..listLevel)
					s ~= "*";
				s ~= " ";
			}
			bulletPending = false;
		}
	}

	@property bool paraStart() { return blockIndex==0 || blocks[blockIndex-1].type == BlockType.NewParagraph; }
	@property bool paraEnd() { return blockIndex==blocks.length || blocks[blockIndex].type == BlockType.NewParagraph; }

	override void addText(string text) { pre(); if (inTable) text = text.replace("\t", " || "); s ~= text.replace("<", "&lt;").replace(">", "&gt;").replace("{{", "<nowiki>{{</nowiki>").replace("}}", "<nowiki>}}</nowiki>"); }
	override void newParagraph() { if (!inTable) s ~= "\n"; else s ~= "\n|-\n| "; if (listLevel) bulletPending = true; }

	override void addBold() { pre(); s ~= "'''"; }
	override void addItalic() { pre(); s ~= "''"; }
	override void addUnderline() { pre(); s ~= "<u>"; }
	override void addListLevel(int level) { listLevel = level; bulletPending = true; }
	override void addFontSize(int size) { pre(); if (size > 25 && paraStart) s ~= "== "; else if (size > 20 && paraStart) s ~= "=== "; else if (size < 20) s ~= "<small>"; }
	override void addFontColor(int color) { pre(); s ~= .format(`<span style="color: #%06x">`, color); }
	override void addTabCount(int tabCount) { if (listLevel==0) { inTable = true; s ~= "{|\n| "; } }
	
	override void removeBold() { s ~= "'''"; }
	override void removeItalic() { s ~= "''"; }
	override void removeUnderline() { s ~= "</u>"; }
	override void removeListLevel(int level) { listLevel = level-1; }
	override void removeFontSize(int size) { if (size > 25 && paraEnd) s ~= " =="; else if (size > 20 && paraEnd) s ~= " ==="; else if (size < 20) s ~= "</small>"; }
	override void removeFontColor(int color) { s ~= "</span>"; }
	override void removeTabCount(int tabCount) { if (inTable) { inTable = false; s = s[0..$-5] ~ "|}\n"; } }
}

