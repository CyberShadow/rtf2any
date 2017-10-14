module rtf2any.nested;

import std.string;
import rtf2any.common;

class NestedFormatter
{
	string s;

	enum FormatChange : uint
	{
		Bold,
		Italic,
		Underline,
		ListLevel0,
		// ...
		ListLevelMax = ListLevel0 + 10,
		FontSize0,
		// ...
		FontSizeMax = FontSize0 + 1000,
		FontColor0,
		// ...
		FontColorMax = FontColor0 + 0x1000000,
		TabCount0,
		// ...
		TabCountMax = TabCount0 + 100,
	}

	Block[] blocks;
	size_t blockIndex;

	this(Block[] blocks)
	{
		this.blocks = blocks;
	}

	static FormatChange[] attrToChanges(BlockAttr attr)
	{
		FormatChange[] list;
		for (int i=1; i<=attr.listLevel; i++)
			list ~= cast(FormatChange)(FormatChange.ListLevel0 + i);
		if (attr.tabCount)
			list ~= cast(FormatChange)(FormatChange.TabCount0 + attr.tabCount);
		if (attr.fontSize)
			list ~= cast(FormatChange)(FormatChange.FontSize0 + attr.fontSize);
		if (attr.fontColor)
			list ~= cast(FormatChange)(FormatChange.FontColor0 + attr.fontColor);
		if (attr.bold)
			list ~= FormatChange.Bold;
		if (attr.italic)
			list ~= FormatChange.Italic;
		if (attr.underline)
			list ~= FormatChange.Underline;
		return list;
	}

	static bool haveFormat(FormatChange[] stack, FormatChange format)
	{
		foreach (f; stack)
			if (f == format)
				return true;
		return false;
	}

	static bool haveFormat(FormatChange[] stack, FormatChange min, FormatChange max)
	{
		foreach (f; stack)
			if (f >= min && f<=max)
				return true;
		return false;
	}
	
	abstract void addText(string s);
	void newParagraph() {}
	void newPage() {}

	void addBold() {}
	void addItalic() {}
	void addUnderline() {}
	void addListLevel(int level) {}
	void addFontSize(int size) {}
	void addFontColor(int color) {}
	void addTabCount(int tabCount) {}
	
	void removeBold() {}
	void removeItalic() {}
	void removeUnderline() {}
	void removeListLevel(int level) {}
	void removeFontSize(int size) {}
	void removeFontColor(int color) {}
	void removeTabCount(int tabCount) {}

	final void addFormat(FormatChange f)
	{
		if (f == FormatChange.Bold)
			addBold();
		else
		if (f == FormatChange.Italic)
			addItalic();
		else
		if (f == FormatChange.Underline)
			addUnderline();
		else
		if (f >= FormatChange.ListLevel0 && f <= FormatChange.ListLevelMax)
			addListLevel(f - FormatChange.ListLevel0);
		else
		if (f >= FormatChange.FontSize0 && f <= FormatChange.FontSizeMax)
			addFontSize(f - FormatChange.FontSize0);
		else
		if (f >= FormatChange.FontColor0 && f <= FormatChange.FontColorMax)
			addFontColor(f - FormatChange.FontColor0);
		else
		if (f >= FormatChange.TabCount0 && f <= FormatChange.TabCountMax)
			addTabCount(f - FormatChange.TabCount0);
		else
			assert(0);
	}
	
	final void removeFormat(FormatChange f)
	{
		if (f == FormatChange.Bold)
			removeBold();
		else
		if (f == FormatChange.Italic)
			removeItalic();
		else
		if (f == FormatChange.Underline)
			removeUnderline();
		else
		if (f >= FormatChange.ListLevel0 && f <= FormatChange.ListLevelMax)
			removeListLevel(f - FormatChange.ListLevel0);
		else
		if (f >= FormatChange.FontSize0 && f <= FormatChange.FontSizeMax)
			removeFontSize(f - FormatChange.FontSize0);
		else
		if (f >= FormatChange.FontColor0 && f <= FormatChange.FontColorMax)
			removeFontColor(f - FormatChange.FontColor0);
		else
		if (f >= FormatChange.TabCount0 && f <= FormatChange.TabCountMax)
			removeTabCount(f - FormatChange.TabCount0);
		else
			assert(0);
	}

	string format()
	{
		FormatChange[] stack;

		foreach (bi, ref block; blocks)
		{
			blockIndex = bi;

			FormatChange[] newList = attrToChanges(block.attr);

			foreach (i, f; stack)
				if (!haveFormat(newList, f))
				{
					// unwind stack
					foreach_reverse(rf; stack[i..$])
						removeFormat(rf);
					stack = stack[0..i];
					break;
				}

			// add new and unwound formatters
			foreach (f; newList)
				if (!haveFormat(stack, f))
				{
					stack ~= f;
					addFormat(f);
				}

			switch (block.type)
			{
				case BlockType.Text:
					addText(block.text);
					break;
				case BlockType.NewParagraph:
					newParagraph();
					break;
				case BlockType.PageBreak:
					newPage();
					break;
				default:
					assert(0);
			}
		}

		// close remaining tags
		blockIndex = blocks.length;
		foreach_reverse(rf; stack)
			removeFormat(rf);

		return s;
	}

	static string dumpBlocks(Block[] blocks)
	{
		string s;
		foreach (block; blocks)
		{
			string[] attrs;
			foreach (f; attrToChanges(block.attr))
				if (f == FormatChange.Bold)
					attrs ~= "Bold";
				else
				if (f == FormatChange.Italic)
					attrs ~= "Italic";
				else
				if (f == FormatChange.Underline)
					attrs ~= "Underline";
				else
				if (f >= FormatChange.ListLevel0 && f <= FormatChange.ListLevelMax)
					attrs ~= .format("List level %d", cast(int)(f - FormatChange.ListLevel0));
				else
				if (f >= FormatChange.FontSize0 && f <= FormatChange.FontSizeMax)
					attrs ~= .format("Font size %d", cast(int)(f - FormatChange.FontSize0));
				else
				if (f >= FormatChange.FontColor0 && f <= FormatChange.FontColorMax)
					attrs ~= .format("Font color #%06x", cast(int)(f - FormatChange.FontColor0));
				else
				if (f >= FormatChange.TabCount0 && f <= FormatChange.TabCountMax)
					attrs ~= .format("Tab count %d", cast(int)(f - FormatChange.TabCount0));
				else
					assert(0);
			string text;
			switch (block.type)
			{
			case BlockType.Text:
				text = block.text;
				break;
			case BlockType.NewParagraph:
				text = "NewParagraph";
				break;
			case BlockType.PageBreak:
				text = "PageBreak";
				break;
			default:
				assert(0);
			}
			s ~= .format("%s:\n%s\n", attrs, text);
		}
		return s;
	}
}

