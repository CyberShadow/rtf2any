module rtf2any.bbcode;

import rtf2any.common;
import rtf2any.nested;

class BBCodeFormatter : NestedFormatter
{
	this(Block[] blocks) { super(blocks); }

	bool inList, bulletPending;

	void pre() { if (bulletPending) s ~= "[*]", bulletPending = false; }

	override void addText(string text) { pre(); s ~= text; }
	override void newParagraph() { s ~= \n; if (inList) bulletPending = true; }

	override void addBold() { pre(); s ~= "[B]"; }
	override void addItalic() { pre(); s ~= "[I]"; }
	override void addUnderline() { pre(); s ~= "[U]"; }
	override void addListLevel(int level) { s ~= "[LIST]"; inList = bulletPending = true; }
	override void addFontSize(int size) { assert(0, "TODO"); }
	override void addFontColor(int color) { assert(0, "TODO"); }
	
	override void removeBold() { s ~= "[/B]"; }
	override void removeItalic() { s ~= "[/I]"; }
	override void removeUnderline() { s ~= "[/U]"; }
	override void removeListLevel(int level) { s ~= "[/LIST]"; if (level==1) inList = bulletPending = false; }
	override void removeFontSize(int size) { assert(0, "TODO"); }
	override void removeFontColor(int color) { assert(0, "TODO"); }
}

