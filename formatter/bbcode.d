module rtf2any.formatter.bbcode;

import rtf2any.common;
import rtf2any.formatter.nested;

class BBCodeFormatter : NestedFormatter
{
	this(Block[] blocks) { super(blocks); }

	bool bulletPending;
	int listLevel;

	void pre()
	{
		if (bulletPending)
		{
			if (listLevel != 0)
				s ~= "[*]";
			bulletPending = false;
		}
	}

	override void addText(string text) { pre(); s ~= text; }
	override void newParagraph() { s ~= "\n"; if (listLevel != 0) bulletPending = true; }

	override void addBold(bool enabled) { pre(); s ~= enabled ? "[B]" : "[/B]"; }
	override void addItalic(bool enabled) { pre(); s ~= enabled ? "[I]" : "[/I]"; }
	override void addUnderline(bool enabled) { pre(); s ~= enabled ? "[U]" : "[/U]"; }
	override void addIndent(int left, int firstLine, bool list) { s ~= "[LIST]"; bulletPending = true; listLevel++; }
	override void addFontSize(int size) { assert(0, "TODO"); }
	override void addFontColor(int color) { assert(0, "TODO"); }
	
	override void removeBold(bool enabled) { pre(); s ~= enabled ? "[/B]" : "[B]"; }
	override void removeItalic(bool enabled) { pre(); s ~= enabled ? "[/I]" : "[I]"; }
	override void removeUnderline(bool enabled) { pre(); s ~= enabled ? "[/U]" : "[U]"; }
	override void removeIndent(int left, int firstLine, bool list) { s ~= "[/LIST]"; if (--listLevel == 0) bulletPending = false; }
	override void removeFontSize(int size) { assert(0, "TODO"); }
	override void removeFontColor(int color) { assert(0, "TODO"); }
}

