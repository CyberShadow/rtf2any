module rtf2any.formatter.xml;

import std.conv;
import std.string;
import std.array;

import ae.utils.array;
import ae.utils.meta;
import ae.utils.xmllite;
import ae.utils.xmlwriter;

import rtf2any.common;
import rtf2any.formatter.nested;
import rtf2any.xml.common;
import rtf2any.xml.writer;

class XmlFormatter : NestedFormatter
{
	this(Block[] blocks, string title)
	{
		super(blocks);

		auto document = new XmlDocument();
		xmlStack ~= document;

		auto declNode = new XmlNode(XmlNodeType.Meta, "xml");
		declNode.attributes["version"] = "1.0";
		declNode.attributes["encoding"] = "UTF-8";
		document.children ~= declNode;

		auto rootNode = new XmlNode(XmlNodeType.Node, "document");
		rootNode.attributes["xmlns"] = presentationNamespace;
		rootNode.attributes["title"] = title;
		document.children ~= rootNode;
		xmlStack ~= rootNode;
	}

	XmlNode[] xmlStack;

	override void addText(string text)
	{
		if (!text.length)
			return;

		auto node = new XmlNode(XmlNodeType.Text, text);
		xmlStack[$-1].children ~= node;
	}

	private void addTag(string tag, string[string] attrs = null)
	{
		assert(tag.length);
		auto node = new XmlNode(XmlNodeType.Node, tag);
		node.attributes = XmlAttributes(attrs);
		xmlStack[$-1].children ~= node;
		xmlStack ~= node;
	}

	private void removeTag(string tag, string[string] attrs = null)
	{
		assert(xmlStack[$-1].type == XmlNodeType.Node && xmlStack[$-1].tag == tag, "Closed tag mismatch");
		assert(xmlStack[$-1].attributes == XmlAttributes(attrs), "Closed tag attribute mismatch");
		if (!xmlStack[$-1].children.length && !tag.isOneOf("col", "p", "li"))
			xmlStack[$-2].children = xmlStack[$-2].children[0..$-1];
		xmlStack = xmlStack[0..$-1];
	}

	static immutable string[enumLength!SubSuper] subSuperTag = [null, "sub", "super"];

	int lastParagraphIndex = -1;
	bool inParagraph;

	override void addBold(bool enabled) { addTag(enabled ? "b" : "no-b"); }
	override void addItalic(bool enabled) { addTag(enabled ? "i" : "no-i"); }
	override void addUnderline(bool enabled) { addTag(enabled ? "u" : "no-u"); }
	override void addAlignment(Alignment a) { assert(!inParagraph); addTag("align", ["dir":a.text]); }
	override void addSubSuper(SubSuper subSuper) { addTag(subSuperTag[subSuper]); }
	override void addIndent(int left, int firstLine, bool list) { assert(!inParagraph); addTag("indent", ["left":left.text, "first-line":firstLine.text, "list":list.text]); }
	override void addFont(Font* font) { addTag("font", font.fontAttr); }
	override void addFontSize(int size) { addTag("size", ["pt":size.text]); }
	override void addFontColor(int color) { addTag("color", ["rgb":color==defaultColor?"default":"#%06x".format(color)]); }
	override void addTabs(int[] tabs) { assert(!inParagraph); addTag("tabs", ["stops":"%(%d,%)".format(tabs)]); }
	override void addInParagraph(int index, bool list) { assert(index == ++lastParagraphIndex); assert(!inParagraph); inParagraph = true; addTag("p"); }
	override void addInListItem(int index) { assert(!inParagraph); addTag("li"); }
	override void addInColumn(int index) { addTag("col"); }
	override void addHyperlink(string href) { addTag("hyperlink", ["url":href]); }

	override void removeBold(bool enabled) { removeTag(enabled ? "b" : "no-b"); }
	override void removeItalic(bool enabled) { removeTag(enabled ? "i" : "no-i"); }
	override void removeUnderline(bool enabled) { removeTag(enabled ? "u" : "no-u"); }
	override void removeAlignment(Alignment a) { removeTag("align", ["dir":a.text]); }
	override void removeSubSuper(SubSuper subSuper) { removeTag(subSuperTag[subSuper]); }
	override void removeIndent(int left, int firstLine, bool list) { removeTag("indent", ["left":left.text, "first-line":firstLine.text, "list":list.text]); }
	override void removeFont(Font* font) { removeTag("font", font.fontAttr); }
	override void removeFontSize(int size) { removeTag("size", ["pt":size.text]); }
	override void removeFontColor(int color) { removeTag("color", ["rgb":color==defaultColor?"default":"#%06x".format(color)]); }
	override void removeTabs(int[] tabs) { removeTag("tabs", ["stops":"%(%d,%)".format(tabs)]); }
	override void removeInParagraph(int index, bool list) { assert(index == lastParagraphIndex); assert(inParagraph); inParagraph = false; removeTag("p"); }
	override void removeInListItem(int index) { removeTag("li"); }
	override void removeInColumn(int index) { removeTag("col"); }
	override void removeHyperlink(string href) { removeTag("hyperlink", ["url":href]); }

	override void flush()
	{
		assert(xmlStack.length == 2 /* XmlDocument, <document> */,
			"There are unclosed nodes at flush time");

		s = writeRTFXML(xmlStack[0]);
	}
}

private string[string] fontAttr(Font* font)
{
	return [
		"family" : font.family,
		"name" : font.name,
		"pitch" : font.pitch.text,
		"charset" : font.charset.text,
	];
}
