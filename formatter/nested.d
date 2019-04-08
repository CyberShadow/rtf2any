module rtf2any.formatter.nested;

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
			subSuper,
			listItem,
			paragraph,
			column,
			indent,
			font,
			fontSize,
			fontColor,
			hyperlink,
			tabs,
		}
		Type type;

		union
		{
			/// Type.bold / italic / underline
			bool enabled;

			/// Type.subSuper
			SubSuper subSuper;

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

		/// Type.hyperlink
		string href;

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
				case Format.Type.subSuper:
					return .format("SubSuper %s", subSuper);
				case Format.Type.indent:
					return .format("Indent %d %d %s", leftIndent, firstLineIndent, list);
				case Format.Type.font:
					return .format("Font %s", font);
				case Format.Type.fontSize:
					return .format("Font size %d", fontSize);
				case Format.Type.fontColor:
					return .format("Font color #%06x", fontColor);
				case Format.Type.hyperlink:
					return .format("Hyperlink %(%s%)", href);
				case Format.Type.tabs:
					return .format("Tabs [%(%d,%)]", tabs);
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
					if (indent.leftIndent == f.leftIndent && indent.list && !f.list && f.firstLineIndent == 0)
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
		if (attr.tabs)
			list ~= args!(Format, type => Format.Type.tabs, tabs => attr.tabs);
		if (attr.alignment)
			list ~= args!(Format, type => Format.Type.alignment, alignment => attr.alignment);
		list ~= args!(Format, type => Format.Type.fontColor, fontColor => attr.fontColor);
		if (attr.href)
			list ~= args!(Format, type => Format.Type.hyperlink, href => attr.href);
		if (attr.paragraphIndex >= 0)
			list ~= args!(Format, type => Format.Type.paragraph, paragraphIndex => attr.paragraphIndex);
		if (attr.columnIndex >= 0)
			list ~= args!(Format, type => Format.Type.column, columnIndex => attr.columnIndex);
		list ~= args!(Format, type => Format.Type.bold, enabled => attr.bold);
		list ~= args!(Format, type => Format.Type.italic, enabled => attr.italic);
		list ~= args!(Format, type => Format.Type.underline, enabled => attr.underline);
		list ~= args!(Format, type => Format.Type.subSuper, subSuper => attr.subSuper);
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
	void newParagraph() {}
	void newPage() {}
	void newLine() {}

	void addBold(bool enabled) {}
	void addItalic(bool enabled) {}
	void addUnderline(bool enabled) {}
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
	void addHyperlink(string href) {}
	
	void removeBold(bool enabled) {}
	void removeItalic(bool enabled) {}
	void removeUnderline(bool enabled) {}
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
	void removeHyperlink(string href) {}

	void flush() {}

	final void addFormat(Format f, ref Block block)
	{
		final switch (f.type)
		{
			case Format.Type.bold:
				addBold(f.enabled);
				break;
			case Format.Type.italic:
				addItalic(f.enabled);
				break;
			case Format.Type.underline:
				addUnderline(f.enabled);
				break;
			case Format.Type.alignment:
				addAlignment(f.alignment);
				break;
			case Format.Type.subSuper:
				addSubSuper(f.subSuper);
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
			case Format.Type.hyperlink:
				addHyperlink(f.href);
				break;
		}
	}
	
	final void removeFormat(Format f, ref Block block)
	{
		final switch (f.type)
		{
			case Format.Type.bold:
				removeBold(f.enabled);
				break;
			case Format.Type.italic:
				removeItalic(f.enabled);
				break;
			case Format.Type.underline:
				removeUnderline(f.enabled);
				break;
			case Format.Type.alignment:
				removeAlignment(f.alignment);
				break;
			case Format.Type.subSuper:
				removeSubSuper(f.subSuper);
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
			case Format.Type.hyperlink:
				removeHyperlink(f.href);
				break;
		}
	}

	final bool canSplitFormat(Format f)
	{
		switch (f.type)
		{
			case Format.Type.paragraph:
			case Format.Type.column:
			case Format.Type.listItem:
				return false;
			case Format.Type.indent:
				return !f.list;
			default:
				return true;
		}
	}

	static void preprocess(ref Block[] blocks)
	{
		blocks = blocks.dup;

		// Duplicate the properties of paragraph and tab delimiters to
		// their beginning as fake text nodes, so that the list->tree
		// algorithm below promotes properties (e.g. font size) which
		// correspond to the corresponding delimiter.

		// Insert two nodes: the first with just the formatting
		// properties and no paragraph / column index, and a second
		// with the same formatting properties but with the paragraph
		// / column index. This will coerce the list->tree algorithm
		// to first process the formatting to the entire paragraph or
		// row (i.e. incl. that of the terminating delimiter), and
		// only then begin the paragraph/column node.

		// Afterwards, strip the index from the delimiter itself, to
		// ensure the formatting is extended across multiple
		// paragraphs / columns.

		{
			size_t paragraphIdx = size_t.max;
			size_t tabIdx = size_t.max;
			void insertDummy(size_t index, ref size_t idx, int* function(Block*) dg)
			{
				Block[2] start;
				start[0].type = BlockType.Text;
				start[0].text = null;
				start[0].attr = blocks[idx].attr;
				start[1] = start[0];
				*dg(&start[0]) = -1;
				*dg(&blocks[idx]) = -1;
				blocks.insertInPlace(index, start[]);
				if (paragraphIdx != size_t.max) paragraphIdx += 2;
				if (tabIdx != size_t.max) tabIdx += 2;
				idx = size_t.max;
			}
			foreach_reverse (bi, ref block; blocks)
			{
				if (block.type == BlockType.Tab || block.type == BlockType.NewParagraph)
				{
					if (tabIdx != size_t.max)
						insertDummy(bi+1, tabIdx, b => &b.attr.columnIndex);
					tabIdx = bi;
				}
				if (block.type == BlockType.NewParagraph)
				{
					if (paragraphIdx != size_t.max)
						insertDummy(bi+1, paragraphIdx, b => &b.attr.paragraphIndex);
					paragraphIdx = bi;
					tabIdx = size_t.max;
				}
			}

			insertDummy(0, paragraphIdx, b => &b.attr.paragraphIndex);
		}

		// Insert dummy nodes for final empty columns, as otherwise
		// they will not be registered.
		foreach_reverse (bi; 1..blocks.length)
		{
			if (blocks[bi-1].type == BlockType.Tab && blocks[bi].type == BlockType.NewParagraph)
			{
				Block dummy;
				dummy.type = BlockType.Text;
				dummy.text = null;
				dummy.attr = blocks[bi-1].attr;
				dummy.attr.columnIndex++;
				blocks.insertInPlace(bi, dummy);
			}
		}
	}

	string format()
	{
		static immutable Format[] defaultStack = [
			{ type : Format.Type.fontColor, fontColor : defaultColor },
			{ type : Format.Type.bold     , enabled : false },
			{ type : Format.Type.italic   , enabled : false },
			{ type : Format.Type.underline, enabled : false },
			{ type : Format.Type.subSuper , subSuper : SubSuper.none },
		];
		Format[] stack = (cast(Format[])defaultStack).dup;
		s = null;

		preprocess(blocks);

		Format[] prevList;

		import std.stdio : stderr;
		debug enum debugBlockIndex = 99999999;

		foreach (bi, ref block; blocks)
		{
			scope(failure) stderr.writefln("Error with block %d %s:", bi, block);
			scope(failure) stderr.writeln("Stack: ", stack);

			blockIndex = bi;

			Format[] newList = attrToChanges(block.attr, prevList);
			debug if (bi == debugBlockIndex)
			{
				stderr.writeln("block: ", block);
				stderr.writeln("stack: ", stack);
				stderr.writeln("prevList: ", prevList);
				stderr.writeln("newList: ", newList);
			}

			// Gracious unwind (popping things off the top of the stack)
			while (stack.length && !haveFormat(newList, stack[$-1]))
			{
				debug if (bi == debugBlockIndex)
					stderr.writeln("removing format: ", stack[$-1]);
				removeFormat(stack[$-1], blocks[bi-1]);
				stack = stack[0..$-1];
			}

			// Brutal unwind (popping things out from the middle of the stack)
			foreach (i, f; stack)
				if (i >= defaultStack.length && !haveFormat(newList, f))
				{
					bool canSplit = true;
					foreach (rf; stack[i+1..$])
						if (haveFormat(newList, rf) && !canSplitFormat(rf))
						{
							debug if (bi == debugBlockIndex)
								stderr.writeln("Can't split format ", rf, " for ", f);
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
						debug if (bi == debugBlockIndex)
							stderr.writeln("Unwound stack: ", stack);
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
					debug if (bi == debugBlockIndex)
						stderr.writeln("Adding format: ", f);
					stack ~= f;
					addFormat(f, block);
				}

			assert(stack.startsWith(cast(Format[])defaultStack));

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
				case BlockType.LineBreak:
					newLine();
					break;
			}

			prevList = newList;
			debug if (bi == debugBlockIndex)
				stderr.writeln();
		}

		// close remaining tags
		blockIndex = blocks.length;
		foreach_reverse (rf; stack[defaultStack.length..$])
			removeFormat(rf, blocks[$-1]);

		flush();

		return s;
	}

	static string dumpBlocks(Block[] blocks)
	{
		import std.format : format;
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
				text = format("%(%s%)", [block.text]);
				break;
			case BlockType.NewParagraph:
				text = "NewParagraph";
				break;
			case BlockType.PageBreak:
				text = "PageBreak";
				break;
			case BlockType.LineBreak:
				text = "LineBreak";
				break;
			default:
				//assert(0);
			}
			s ~= .format("%s:\n%s\n", attrs, text);
			prevChanges = changes;
		}
		return s;
	}
}
