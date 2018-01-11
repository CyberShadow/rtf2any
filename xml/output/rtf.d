module rtf2any.xml.output.rtf;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;

import ae.utils.array;
import ae.utils.xmllite;

import rtf2any.common;
import rtf2any.rtf.writer;

string toRTF(XmlDocument xml)
{
	Font[] fonts;
	size_t registerFont(in Font* font)
	{
		assert(font);
		auto i = fonts.indexOf(*font);
		if (i < 0)
		{
			i = fonts.length;
			fonts ~= *font;
		}
		return i;
	}

	int[] colors = [defaultColor];
	size_t registerColor(uint color)
	{
		auto i = colors.indexOf(color);
		if (i < 0)
		{
			i = colors.length;
			colors ~= color;
		}
		return i;
	}

	BlockAttr oldAttr;
	bool attrInitialized = false; // need to emit a \pard at the top
	int paragraphIndex, columnIndex, listParagraphIndex = int.min;

	RTFWriter rtf;

	struct State
	{
		bool inListItem;
		size_t columnCount;
	}

	void walk(XmlNode n, BlockAttr attr, State state)
	{
		void flushAttr()
		{
			if (!attrInitialized
			 || (oldAttr.tabs.length && attr.tabs != oldAttr.tabs)
			 || (oldAttr.list && !attr.list)
			 || (oldAttr.font && !attr.font)
			)
			{
				rtf.putDir("pard");
				oldAttr.leftIndent = oldAttr.firstLineIndent = 0;
				oldAttr.tabs = null;
				oldAttr.alignment = Alignment.left;
				oldAttr.list = false;
				attrInitialized = true;
			}
			if (attr.href && !oldAttr.href)
			{
				// {\field{\*\fldinst HYPERLINK "http://www.google.com/"}{\fldrslt http://www.google.com}}
				rtf.beginGroup();
				rtf.putDir("field");
				rtf.beginGroup();
				rtf.putDir("*");
				rtf.putDir("fldinst");
				rtf.putText("HYPERLINK \"" ~ attr.href ~ "\"");
				rtf.endGroup();
				rtf.beginGroup();
				rtf.putDir("fldrslt");
			}
			if (attr.bold != oldAttr.bold)
				rtf.putDir(attr.bold ? "b" : "b0");
			if (attr.italic != oldAttr.italic)
				rtf.putDir(attr.italic ? "i" : "i0");
			if (attr.underline != oldAttr.underline)
				rtf.putDir(attr.underline ? "ul" : "ulnone");
			if (attr.alignment != oldAttr.alignment)
				rtf.putDir("q" ~ "lcrj"[attr.alignment]);
			if (attr.subSuper != oldAttr.subSuper)
				rtf.putDir(["nosupersub", "sub", "super"][attr.subSuper]);
			if (attr.list != oldAttr.list)
			{
				assert(attr.list);
				rtf.beginGroup();
				rtf.putDir("*");
				rtf.putDir("pn");
				rtf.putDir("pnlvlblt");
				static immutable Font listFont = {
					Font font;
					font.family = "nil";
					font.charset = 2;
					font.name = "Symbol";
					return font;
				}();
				rtf.putDir("pnf", registerFont(&listFont));
				rtf.beginGroup();
				rtf.putDir("pntxtb");
				rtf.putText("\u00b7");
				rtf.endGroup();
				rtf.endGroup();
			}
			if (attr.leftIndent != oldAttr.leftIndent)
				rtf.putDir("li", attr.leftIndent);
			if (attr.firstLineIndent != oldAttr.firstLineIndent)
				rtf.putDir("fi", attr.firstLineIndent);
			if (attr.fontSize != oldAttr.fontSize)
				rtf.putDir("fs", attr.fontSize);
			if (attr.fontColor != oldAttr.fontColor)
				rtf.putDir("cf", registerColor(attr.fontColor));
			if (attr.tabs != oldAttr.tabs)
				foreach (tab; attr.tabs)
					rtf.putDir("tx", tab);
			if ((attr.font?*attr.font:Font.init) != (oldAttr.font?*oldAttr.font:Font.init))
				rtf.putDir("f", registerFont(attr.font));
			if (!attr.href && oldAttr.href)
			{
				rtf.endGroup();
				rtf.endGroup();
			}
			oldAttr = attr;
		}

		switch (n.type)
		{
			case XmlNodeType.Node:
				switch (n.tag)
				{
					case "document":
						break;
					case "b":
						attr.bold = true;
						break;
					case "i":
						attr.italic = true;
						break;
					case "u":
						attr.underline = true;
						break;
					case "align":
						attr.alignment = n.attributes.aaGet("dir").to!Alignment;
						break;
					case "sub":
						attr.subSuper = SubSuper.subscript;
						break;
					case "super":
						attr.subSuper = SubSuper.superscript;
						break;
					case "indent":
						attr.leftIndent = n.attributes.aaGet("left").to!int;
						attr.firstLineIndent = n.attributes.aaGet("first-line").to!int;
						state.inListItem = false;
						break;
					case "font":
					{
						attr.font = new Font;
						attr.font.pitch = n.attributes.aaGet("pitch").to!int;
						attr.font.family = n.attributes.aaGet("family");
						attr.font.name = n.attributes.aaGet("name");
						attr.font.charset = n.attributes.aaGet("charset").to!int;
						break;
					}
					case "size":
						attr.fontSize = n.attributes.aaGet("pt").to!int;
						break;
					case "color":
					{
						auto s = n.attributes.aaGet("rgb");
						enforce(s.skipOver("#"));
						attr.fontColor = s.to!int(16);
						break;
					}
					case "a":
						attr.href = n.attributes.aaGet("href");
						break;
					case "tabs":
						attr.tabs = n.attributes.aaGet("stops").split(",").map!(to!int).array;
						break;
					case "li":
						state.inListItem = true;
						listParagraphIndex = 0;
						// rtf.beginGroup();
						// rtf.putDir("pntext");
						// rtf.putText("•");
						// rtf.putDir("tab");
						// rtf.endGroup();
						break;
					case "p":
						attr.paragraphIndex = paragraphIndex++;
						attr.columnIndex = columnIndex = 0;
						attr.list = state.inListItem && listParagraphIndex == 0;
						if (state.inListItem && listParagraphIndex)
							attr.firstLineIndent = 0;
						state.columnCount = n.countNodes("col");
						break;
					case "col":
						attr.columnIndex = columnIndex++;
						break;
					default:
						throw new Exception("Unknown XML tag " ~ n.tag);
				}
				break;
			case XmlNodeType.Text:
				flushAttr();
				rtf.putText(n.tag);
				break;
			default:
				throw new Exception("Unknown XML node type");
		}

		foreach (child; n.children)
			walk(child, attr, state);

		switch (n.type)
		{
			case XmlNodeType.Node:
				switch (n.tag)
				{
					case "p":
						flushAttr();
						rtf.putDir("par");
						rtf.newLine();
						listParagraphIndex++;
						break;
					case "col":
						if (columnIndex < state.columnCount)
						{
							flushAttr();
							rtf.putDir("tab");
						}
						break;
					case "document":
						rtf.endGroup();
						break;
					default:
						break;
				}
				break;
			default:
				break;
		}
	}

	walk(xml["document"], BlockAttr.init, State.init);

	auto docBody = rtf.buf.data.idup;
	rtf.buf.clear();
	rtf.beginGroup();
	rtf.putDir("rtf", 1);

	rtf.beginGroup();
	rtf.putDir("fonttbl");
	foreach (fi, font; fonts)
	{
		rtf.beginGroup();
		rtf.putDir("f", fi);
		rtf.putDir("f", font.family);
		rtf.putDir("fprq", font.pitch);
		rtf.putDir("fcharset", font.charset);
		rtf.putText(font.name);
		rtf.putText(";");
		rtf.endGroup();
	}
	rtf.endGroup();
	rtf.newLine();

	rtf.beginGroup();
	rtf.putDir("colortbl");
	foreach (fi, color; colors)
	{
		if (color != defaultColor)
		{
			rtf.putDir("red", (color >> 16) & 0xFF);
			rtf.putDir("green", (color >> 8) & 0xFF);
			rtf.putDir("blue", color & 0xFF);
		}
		rtf.putText(";");
	}
	rtf.endGroup();
	rtf.newLine();

	rtf.beginGroup();
	rtf.putDir("*");
	rtf.putDir("generator");
	rtf.putText("Team15 RTF generator;");
	rtf.endGroup();
	rtf.newLine();

	rtf.buf.put(docBody);
	rtf.endGroup();

	return rtf.buf.data.assumeUnique;
}

size_t countNodes(XmlNode n, string tag)
{
	if (n.type == XmlNodeType.Node && n.tag == tag)
		return 1;
	return n.children.map!(n => countNodes(n, tag)).sum;
}
