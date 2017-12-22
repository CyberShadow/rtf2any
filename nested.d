module rtf2any.nested;

import std.conv;
import std.string;

import ae.utils.meta.args;

import rtf2any.common;

class NestedFormatter
{
	string s;

	struct Format
	{
		enum Type
		{
			bold,
			italic,
			underline,
			center,
			subscript,
			superscript,
			paragraph,
			column,
			indent,
			font,
			fontSize,
			fontColor,
			tabs,
		}
		Type type;

		/// For paragraph, column, listLevel, fontSize, fontColor, indent
		int value;

		/// For indent
		int value2;

		/// For font
		Font *font;

		/// For tabs
		int[] tabs;
	}

	Block[] blocks;
	size_t blockIndex;

	this(Block[] blocks)
	{
		this.blocks = blocks;
	}

	static Format[] attrToChanges(BlockAttr attr)
	{
		Format[] list;
		if (attr.font)
			list ~= args!(Format, type => Format.Type.font, font => attr.font);
		if (attr.fontSize)
			list ~= Format(Format.Type.fontSize, attr.fontSize);
		if (attr.leftIndent || attr.firstLineIndent)
			list ~= Format(Format.Type.indent, attr.leftIndent, attr.firstLineIndent);
		if (attr.tabs.length)
			list ~= args!(Format, type => Format.Type.tabs, tabs => attr.tabs);
		if (attr.center)
			list ~= Format(Format.Type.center);
		if (attr.fontColor)
			list ~= Format(Format.Type.fontColor, attr.fontColor);
		if (attr.paragraphIndex >= 0)
			list ~= Format(Format.Type.paragraph, attr.paragraphIndex);
		if (attr.columnIndex >= 0)
			list ~= Format(Format.Type.column, attr.columnIndex);
		if (attr.bold)
			list ~= Format(Format.Type.bold);
		if (attr.italic)
			list ~= Format(Format.Type.italic);
		if (attr.underline)
			list ~= Format(Format.Type.underline);
		if (attr.subSuper == SubSuper.subscript)
			list ~= Format(Format.Type.subscript);
		if (attr.subSuper == SubSuper.superscript)
			list ~= Format(Format.Type.superscript);
		return list;
	}

	static bool haveFormat(Format[] stack, Format format)
	{
		foreach (f; stack)
			if (f == format)
				return true;
		return false;
	}

	static bool haveFormat(Format[] stack, Format.Type formatType)
	{
		foreach (f; stack)
			if (f.type == formatType)
				return true;
		return false;
	}

	abstract void addText(string s);
	void addBullet() {}
	void newParagraph() {}
	void newPage() {}

	void addBold() {}
	void addItalic() {}
	void addUnderline() {}
	void addCenter() {}
	void addSubSuper(SubSuper subSuper) {}
	void addIndent(int left, int firstLine) {}
	void addFont(Font* font) {}
	void addFontSize(int size) {}
	void addFontColor(int color) {}
	void addTabs(int[] tabs) {}
	void addInParagraph(int index, bool list) {}
	void addInColumn(int index) {}
	
	void removeBold() {}
	void removeItalic() {}
	void removeUnderline() {}
	void removeCenter() {}
	void removeSubSuper(SubSuper subSuper) {}
	void removeIndent(int left, int firstLine) {}
	void removeFont(Font* font) {}
	void removeFontSize(int size) {}
	void removeFontColor(int color) {}
	void removeTabs(int[] tabs) {}
	void removeInParagraph(int index, bool list) {}
	void removeInColumn(int index) {}

	void flush() {}

	final void addFormat(Format f, ref Block block)
	{
		final switch (f.type)
		{
			case Format.Type.bold:
				addBold();
				break;
			case Format.Type.italic:
				addItalic();
				break;
			case Format.Type.underline:
				addUnderline();
				break;
			case Format.Type.center:
				addCenter();
				break;
			case Format.Type.subscript:
				addSubSuper(SubSuper.subscript);
				break;
			case Format.Type.superscript:
				addSubSuper(SubSuper.superscript);
				break;
			case Format.Type.indent:
				addIndent(f.value, f.value2);
				break;
			case Format.Type.font:
				addFont(f.font);
				break;
			case Format.Type.fontSize:
				addFontSize(f.value);
				break;
			case Format.Type.fontColor:
				addFontColor(f.value);
				break;
			case Format.Type.tabs:
				addTabs(f.tabs);
				break;
			case Format.Type.paragraph:
				addInParagraph(f.value, block.attr.list);
				break;
			case Format.Type.column:
				addInColumn(f.value);
				break;
		}
	}
	
	final void removeFormat(Format f, ref Block block)
	{
		final switch (f.type)
		{
			case Format.Type.bold:
				removeBold();
				break;
			case Format.Type.italic:
				removeItalic();
				break;
			case Format.Type.underline:
				removeUnderline();
				break;
			case Format.Type.center:
				removeCenter();
				break;
			case Format.Type.subscript:
				removeSubSuper(SubSuper.subscript);
				break;
			case Format.Type.superscript:
				removeSubSuper(SubSuper.superscript);
				break;
			case Format.Type.indent:
				removeIndent(f.value, f.value2);
				break;
			case Format.Type.font:
				removeFont(f.font);
				break;
			case Format.Type.fontSize:
				removeFontSize(f.value);
				break;
			case Format.Type.fontColor:
				removeFontColor(f.value);
				break;
			case Format.Type.tabs:
				removeTabs(f.tabs);
				break;
			case Format.Type.paragraph:
				removeInParagraph(f.value, block.attr.list);
				break;
			case Format.Type.column:
				removeInColumn(f.value);
				break;
		}
	}

	final bool canSplitFormat(Format f)
	{
		switch (f.type)
		{
			case Format.Type.paragraph:
			case Format.Type.column:
				return false;
			default:
				return true;
		}
	}

	string format()
	{
		Format[] stack;
		s = null;

		// Duplicate the properties of a paragraph's delimiter to its
		// beginning as a fake text node, so that the list->tree
		// algorithm below promotes properties (e.g. font size) which
		// correspond to the paragraph delimiter.
		{
			BlockAttr* paragraphAttr;
			foreach_reverse (bi, ref block; blocks)
				if (block.type == BlockType.NewParagraph)
				{
					if (paragraphAttr)
					{
						Block start;
						start.type = BlockType.Text;
						start.text = null;
						start.attr = *paragraphAttr;
						blocks = blocks[0..bi+1] ~ start ~ blocks[bi+1..$];
					}
					paragraphAttr = &block.attr;
				}
		}

		foreach (bi, ref block; blocks)
		{
			blockIndex = bi;

			Format[] newList = attrToChanges(block.attr);

			// Gracious unwind (popping things off the top of the stack)
			while (stack.length && !haveFormat(newList, stack[$-1]))
			{
				removeFormat(stack[$-1], blocks[bi-1]);
				stack = stack[0..$-1];
			}

			// Brutal unwind (popping things out from the middle of the stack)
			foreach (i, f; stack)
				if (!haveFormat(newList, f))
				{
					bool canSplit = true;
					foreach (rf; stack[i+1..$])
						if (!canSplitFormat(rf))
						{
							canSplit = false;
							break;
						}

					if (canSplit)
					{
						// Unwind stack to remove all formats no
						// longer present, and everything that came on
						// top of them in the stack.
						foreach_reverse (rf; stack[i..$])
							removeFormat(rf, blocks[bi-1]);
						stack = stack[0..i];
						break;
					}
					else
					{
						// Just let the new format to be added to the
						// top of the stack, overriding the old one.
					}
				}

			// Add new and re-add unwound formatters.
			foreach (f; newList)
				if (!haveFormat(stack, f))
				{
					stack ~= f;
					addFormat(f, block);
				}

			final switch (block.type)
			{
				case BlockType.Text:
					addText(block.text);
					break;
				case BlockType.NewParagraph:
					newParagraph();
					break;
				case BlockType.Tab:
					break;
				case BlockType.PageBreak:
					newPage();
					break;
			}
		}

		// close remaining tags
		blockIndex = blocks.length;
		foreach_reverse(rf; stack)
			removeFormat(rf, blocks[$-1]);

		flush();

		return s;
	}

	static string dumpBlocks(Block[] blocks)
	{
		string s;
		foreach (block; blocks)
		{
			string[] attrs;
			foreach (f; attrToChanges(block.attr))
				final switch (f.type)
				{
					case Format.Type.bold:
						attrs ~= "Bold";
						break;
					case Format.Type.italic:
						attrs ~= "Italic";
						break;
					case Format.Type.underline:
						attrs ~= "Underline";
						break;
					case Format.Type.center:
						attrs ~= "Center";
						break;
					case Format.Type.subscript:
						attrs ~= "SubScript";
						break;
					case Format.Type.superscript:
						attrs ~= "SuperScript";
						break;
					case Format.Type.indent:
						attrs ~= .format("Indent %d %d", f.value, f.value2);
						break;
					case Format.Type.font:
						attrs ~= .format("Font %s", f.font);
						break;
					case Format.Type.fontSize:
						attrs ~= .format("Font size %d", f.value);
						break;
					case Format.Type.fontColor:
						attrs ~= .format("Font color #%06x", f.value);
						break;
					case Format.Type.tabs:
						attrs ~= .format("Tab count %d", f.tabs.length);
						break;
					case Format.Type.paragraph:
						attrs ~= .format("Paragraph %d", f.value);
						break;
					case Format.Type.column:
						attrs ~= .format("Column %d", f.value);
						break;
				}
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
