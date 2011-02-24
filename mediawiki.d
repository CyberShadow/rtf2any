module rtf2any.mediawiki;

import rtf2any.common;
import rtf2any.nested;
import std.string;

class MediaWikiFormatter : NestedFormatter
{
	this(Block[] blocks) { super(blocks); }

	int listLevel, bulletPending;

	void pre()
	{
		if (bulletPending && listLevel)
		{
			foreach (i; 0..listLevel)
				s ~= "*";
			s ~= " ";
			bulletPending = false;
		}
	}

	override void addText(string text) { pre(); s ~= text; }
	override void newParagraph() { s ~= "\n"; if (listLevel) bulletPending = true; }

	override void addBold() { pre(); s ~= "'''"; }
	override void addItalic() { pre(); s ~= "''"; }
	override void addUnderline() { pre(); s ~= "<u>"; }
	override void addListLevel(int level) { listLevel = level; bulletPending = true; }
	override void addFontSize(int size) { pre(); if (size > 20) s ~= "== "; else if (size < 20) s ~= "<small>"; }
	override void addFontColor(int color) { pre(); s ~= .format(`<span style="color: #%06x">`, color); }
	
	override void removeBold() { s ~= "'''"; }
	override void removeItalic() { s ~= "''"; }
	override void removeUnderline() { s ~= "</u>"; }
	override void removeListLevel(int level) { listLevel = level-1; }
	override void removeFontSize(int size) { if (size > 20) s ~= " =="; else if (size < 20) s ~= "</small>"; }
	override void removeFontColor(int color) { s ~= "</span>"; }
}

