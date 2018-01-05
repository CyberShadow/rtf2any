module rtf2any.nested;

import std.algorithm.iteration;
import std.array;
import std.conv;
import std.string;
import std.traits;

import ae.utils.array;
import ae.utils.meta : enumLength;
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
			listItem,
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

			/// Type.listItem
			int listItemIndex;

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

		string toString() const
		{
			final switch (type)
			{
				case Format.Type.bold:
					return "Bold";
				case Format.Type.italic:
					return "Italic";
				case Format.Type.underline:
					return "Underline";
				case Format.Type.alignment:
					return .format("Align %s", alignment);
				case Format.Type.subscript:
					return "SubScript";
				case Format.Type.superscript:
					return "SuperScript";
				case Format.Type.indent:
					return .format("Indent %d %d %s", leftIndent, firstLineIndent, list);
				case Format.Type.font:
					return .format("Font %s", font);
				case Format.Type.fontSize:
					return .format("Font size %d", fontSize);
				case Format.Type.fontColor:
					return .format("Font color #%06x", fontColor);
				case Format.Type.tabs:
					return .format("Tab count %d", tabs.length);
				case Format.Type.listItem:
					return .format("List item %d", listItemIndex);
				case Format.Type.paragraph:
					return .format("Paragraph %d", paragraphIndex);
				case Format.Type.column:
					return .format("Column %d", columnIndex);
			}
		}
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
			auto indents = prevFormat.filter!(f => f.type.isOneOf(Format.Type.indent, Format.Type.listItem)).array;
			auto f = args!(Format, type => Format.Type.indent, leftIndent => attr.leftIndent, firstLineIndent => attr.firstLineIndent, list => attr.list);
			foreach (i, ref indent; indents)
				if (indent.type == Format.Type.indent && indent.leftIndent >= f.leftIndent)
				{
					if (indent.leftIndent == f.leftIndent)
						indents = indents[0..i+1];
					else
						indents = indents[0..i] ~ f;
					goto cutoff;
				}
			indents ~= f;
		cutoff:
			assert(indents[$-1].type == Format.Type.indent);
			if (indents[$-1].list)
				indents ~= args!(Format, type => Format.Type.listItem, listItemIndex => attr.listItemIndex);
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

	static bool haveActiveFormat(Format[] stack, Format format)
	{
		bool[enumLength!(Format.Type)] sawFormat;
		foreach_reverse (f; stack)
		{
			if (!sawFormat[f.type])
			{
				if (f == format)
					return true;
				sawFormat[f.type] = true;
			}
		}
		return false;
	}

	version(none)
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
	void addInListItem(int index) {}
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
	void removeInListItem(int index) {}
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
			case Format.Type.listItem:
				addInListItem(f.listItemIndex);
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
			case Format.Type.listItem:
				removeInListItem(f.listItemIndex);
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
			case Format.Type.indent:
			case Format.Type.listItem:
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
				if (haveActiveFormat(newList, f) && !haveActiveFormat(stack, f))
				{
					stack ~= f;
					addFormat(f, block);
				}

			foreach (f; newList)
				if (haveActiveFormat(newList, f))
					assert(haveActiveFormat(stack, f), "Format not in stack: " ~ f.toString());

			foreach (f; stack)
				if (haveActiveFormat(stack, f))
					assert(haveActiveFormat(newList, f), "Rogue format in stack: " ~ f.toString());

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
			foreach (ref f; changes)
				attrs ~= f.toString();
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
