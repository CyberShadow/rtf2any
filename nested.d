module rtf2any.nested;

import std.algorithm.iteration;
import std.array;
import std.conv;
import std.string;
import std.traits;

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
			alignment,
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

		this(Type type) { this.type = type; }

		union
		{
			/// Type.alignment
			Alignment alignment;

			/// Type.paragraph
			int paragraphIndex;

			/// Type.column
			int columnIndex;

			/// Type.indent
			struct { int leftIndent, firstLineIndent; bool list; }

			/// Type.fontSize
			int fontSize;

			/// Type.fontColor
			int fontColor;
		}

		/// Type.font
		Font *font;

		/// Type.tabs
		int[] tabs;
	}

	Block[] blocks;
	size_t blockIndex;

	this(Block[] blocks)
	{
		this.blocks = blocks;
	}

	static Format[] attrToChanges(BlockAttr attr, Format[] prevFormat)
	{
		Format[] list;
		if (attr.font)
			list ~= args!(Format, type => Format.Type.font, font => attr.font);
		if (attr.fontSize)
			list ~= args!(Format, type => Format.Type.fontSize, fontSize => attr.fontSize);
		if (attr.leftIndent || attr.firstLineIndent || attr.list)
		{
			auto indents = prevFormat.filter!(f => f.type == Format.Type.indent).array;
			int score(ref Format f) { return f.leftIndent + f.firstLineIndent/2; }
			auto f = args!(Format, type => Format.Type.indent, leftIndent => attr.leftIndent, firstLineIndent => attr.firstLineIndent, list => attr.list);
			while (indents.length && score(indents[$-1]) >= score(f))
				indents = indents[0..$-1];
			indents ~= f;
			list ~= indents;
		}
		if (attr.tabs.length)
			list ~= args!(Format, type => Format.Type.tabs, tabs => attr.tabs);
		if (attr.alignment)
			list ~= args!(Format, type => Format.Type.alignment, alignment => attr.alignment);
		if (attr.fontColor != defaultColor)
			list ~= args!(Format, type => Format.Type.fontColor, fontColor => attr.fontColor);
		if (attr.paragraphIndex >= 0)
			list ~= args!(Format, type => Format.Type.paragraph, paragraphIndex => attr.paragraphIndex);
		if (attr.columnIndex >= 0)
			list ~= args!(Format, type => Format.Type.column, columnIndex => attr.columnIndex);
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
	void addAlignment(Alignment alignment) {}
	void addSubSuper(SubSuper subSuper) {}
	void addIndent(int left, int firstLine, bool list) {}
	void addFont(Font* font) {}
	void addFontSize(int size) {}
	void addFontColor(int color) {}
	void addTabs(int[] tabs) {}
	void addInParagraph(int index, bool list) {}
	void addInColumn(int index) {}
	
	void removeBold() {}
	void removeItalic() {}
	void removeUnderline() {}
	void removeAlignment(Alignment alignment) {}
	void removeSubSuper(SubSuper subSuper) {}
	void removeIndent(int left, int firstLine, bool list) {}
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
			case Format.Type.alignment:
				addAlignment(f.alignment);
				break;
			case Format.Type.subscript:
				addSubSuper(SubSuper.subscript);
				break;
			case Format.Type.superscript:
				addSubSuper(SubSuper.superscript);
				break;
			case Format.Type.indent:
				addIndent(f.leftIndent, f.firstLineIndent, f.list);
				break;
			case Format.Type.font:
				addFont(f.font);
				break;
			case Format.Type.fontSize:
				addFontSize(f.fontSize);
				break;
			case Format.Type.fontColor:
				addFontColor(f.fontColor);
				break;
			case Format.Type.tabs:
				addTabs(f.tabs);
				break;
			case Format.Type.paragraph:
				addInParagraph(f.paragraphIndex, block.attr.list);
				break;
			case Format.Type.column:
				addInColumn(f.columnIndex);
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
			case Format.Type.alignment:
				removeAlignment(f.alignment);
				break;
			case Format.Type.subscript:
				removeSubSuper(SubSuper.subscript);
				break;
			case Format.Type.superscript:
				removeSubSuper(SubSuper.superscript);
				break;
			case Format.Type.indent:
				removeIndent(f.leftIndent, f.firstLineIndent, f.list);
				break;
			case Format.Type.font:
				removeFont(f.font);
				break;
			case Format.Type.fontSize:
				removeFontSize(f.fontSize);
				break;
			case Format.Type.fontColor:
				removeFontColor(f.fontColor);
				break;
			case Format.Type.tabs:
				removeTabs(f.tabs);
				break;
			case Format.Type.paragraph:
				removeInParagraph(f.paragraphIndex, block.attr.list);
				break;
			case Format.Type.column:
				removeInColumn(f.columnIndex);
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

		Format[] prevList;

		foreach (bi, ref block; blocks)
		{
			blockIndex = bi;

			Format[] newList = attrToChanges(block.attr, prevList);

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

			prevList = newList;
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
		Format[] prevChanges;
		foreach (block; blocks)
		{
			string[] attrs;
			auto changes = attrToChanges(block.attr, prevChanges);
			foreach (f; changes)
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
					case Format.Type.alignment:
						attrs ~= "Align " ~ text(f.alignment);
						break;
					case Format.Type.subscript:
						attrs ~= "SubScript";
						break;
					case Format.Type.superscript:
						attrs ~= "SuperScript";
						break;
					case Format.Type.indent:
						attrs ~= .format("Indent %d %d", f.leftIndent, f.firstLineIndent);
						break;
					case Format.Type.font:
						attrs ~= .format("Font %s", f.font);
						break;
					case Format.Type.fontSize:
						attrs ~= .format("Font size %d", f.fontSize);
						break;
					case Format.Type.fontColor:
						attrs ~= .format("Font color #%06x", f.fontColor);
						break;
					case Format.Type.tabs:
						attrs ~= .format("Tab count %d", f.tabs.length);
						break;
					case Format.Type.paragraph:
						attrs ~= .format("Paragraph %d", f.paragraphIndex);
						break;
					case Format.Type.column:
						attrs ~= .format("Column %d", f.columnIndex);
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
			prevChanges = changes;
		}
		return s;
	}
}
