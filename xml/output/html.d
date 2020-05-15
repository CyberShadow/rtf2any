module rtf2any.xml.output.html;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;
import std.path;
import std.string;
import std.typecons;

import ae.utils.aa;
import ae.utils.array;
import ae.utils.meta;
import ae.utils.xmllite;
import ae.utils.xmlwriter;

import rtf2any.xml.reader;
import rtf2any.xml.helpers;

string toHTML(XmlDocument xml)
{
	struct State
	{
		bool inTable;
		int[] columns;
		bool inParagraph;
		int leftIndent, firstLineIndent;
		bool firstLineIndentPending;
		int initColNum;
	}

	uint colNum;
	XmlNode[] stack;

	void walk(XmlNode n, XmlNode parent, State state)
	{
		stack ~= n;
		scope(exit) stack = stack[0..$-1];

		XmlNode hn;
		switch (n.type)
		{
			case XmlNodeType.Node:
				switch (n.tag)
				{
					case "document":
					{
						auto htmlNode = new XmlNode(XmlNodeType.Node, "html");
						htmlNode.attributes["xmlns"] = "http://www.w3.org/1999/xhtml";
						parent.children ~= htmlNode;

						auto headNode = new XmlNode(XmlNodeType.Node, "head");
						htmlNode.children ~= headNode;

						auto metaNode = new XmlNode(XmlNodeType.Node, "meta");
						metaNode.attributes["charset"] = "utf-8";
						headNode.children ~= metaNode;

						auto titleNode = new XmlNode(XmlNodeType.Node, "title");
						titleNode.children ~= new XmlNode(XmlNodeType.Text, n.attributes.aaGet("title"));
						headNode.children ~= titleNode;

						auto styleNode = new XmlNode(XmlNodeType.Node, "style");
						styleNode.children ~= new XmlNode(XmlNodeType.Text, q"EOF
body {
	line-height: 1.1;
}
p {
	margin: 0;
	min-height: 1.1em;
}
td {
	height: 1.1em;
}
ul {
	margin: 0;
	padding-left: 1.2em;
	list-style: disc;
}
td {
	padding: 0;
	vertical-align: baseline;
}
table {
	border-collapse: collapse;
}
li table {
	display: inline-table;
}
EOF".strip.replace("\n", "\n\t\t\t"));
						headNode.children ~= styleNode;

						parent = htmlNode;

						hn = new XmlNode(XmlNodeType.Node, "body");
						break;
					}
					case "b":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "font-weight: bold";
						break;
					case "i":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "font-style: italic";
						break;
					case "u":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "text-decoration: underline";
						break;
					case "no-b":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "font-weight: normal";
						break;
					case "no-i":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "font-style: normal";
						break;
					case "no-u":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "text-decoration: none";
						break;
					case "align":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "text-align: " ~ n.attributes.aaGet("dir");
						break;
					case "sub":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "vertical-align: sub; font-size: smaller";
						break;
					case "super":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "vertical-align: super; font-size: smaller";
						break;
					case "indent":
					{
						bool list = n.attributes.aaGet("list").to!bool;
						auto left = n.attributes.aaGet("left").to!int;
						auto firstLine = n.attributes.aaGet("first-line").to!int;
						hn = new XmlNode(XmlNodeType.Node, list ? "ul" : "div");
						auto leftIndent = left - state.leftIndent;
						if (list)
							leftIndent += firstLine;
						if (leftIndent)
							hn.attributes["style"] = "margin-left: " ~ (leftIndent / 20.0).text ~ "pt";
						state.leftIndent = left;
						state.firstLineIndent = firstLine;
						state.firstLineIndentPending = firstLine && !list;

						if (state.inTable)
						{
							auto tr = new XmlNode(XmlNodeType.Node, "tr");
							parent.children ~= tr;

							colNum = 0;
							while (colNum < state.columns.length && state.columns[colNum] <= state.leftIndent + state.firstLineIndent)
							{
								tr.children ~= newNode("td");
								colNum++;
							}
							state.initColNum = colNum;

							auto td = new XmlNode(XmlNodeType.Node, "td");
							tr.children ~= td;
							auto colSpan = state.columns.length + 1 - colNum;
							if (colSpan > 1)
								td.attributes["colspan"] = colSpan.text;

							if (list)
							{
								parent = td;
								state.inTable = false;
							}
							else
							{
								auto table = new XmlNode(XmlNodeType.Node, "table");
								td.children ~= table;
								parent = table;
							}
						}
						break;
					}
					case "font":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "font-family: " ~ n.attributes.aaGet("name");
						break;
					case "size":
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						hn.attributes["style"] = "font-size: " ~ (n.attributes.aaGet("pt").to!float / 2).text ~ "pt";
						break;
					case "color":
					{
						hn = new XmlNode(XmlNodeType.Node, state.inParagraph ? "span" : "div");
						auto rgb = n.attributes.aaGet("rgb");
						hn.attributes["style"] = "color: " ~ (rgb == "default" ? "initial" :rgb);
						break;
					}
					case "hyperlink":
						hn = new XmlNode(XmlNodeType.Node, "a");
						hn.attributes["href"] = n.attributes.aaGet("url");
						break;
					case "local-link":
						hn = new XmlNode(XmlNodeType.Node, "a");
						hn.attributes["href"] = "#" ~ n.attributes.aaGet("target-id");
						break;
					case "tabs":
					{
						hn = new XmlNode(XmlNodeType.Node, "table");
						auto stops = n.attributes.aaGet("stops");
						state.columns = stops.length ? stops.split(",").map!(to!int).array : emptySlice!int;
						state.inTable = true;
						if (state.firstLineIndentPending)
						{
							hn.attributes["style"] = "margin-left: " ~ (state.firstLineIndent / 20.0).text ~ "pt";
							state.firstLineIndentPending = false;
						}
						//state.firstLineIndent = 0;
						break;
					}
					case "li":
						hn = new XmlNode(XmlNodeType.Node, "li");
						break;
					case "p":
						hn = new XmlNode(XmlNodeType.Node, state.inTable ? "tr" : "p");
						colNum = state.initColNum;
						state.inParagraph = true;
						if (!state.inTable && state.firstLineIndentPending)
						{
							hn.attributes["style"] = "text-indent: " ~ (state.firstLineIndent / 20.0).text ~ "pt";
							state.firstLineIndentPending = false;
						}
						break;
					case "col":
						hn = new XmlNode(XmlNodeType.Node, state.inTable ? "td" : "span");
						if (colNum < state.columns.length)
						{
							auto width = state.columns[colNum] - (colNum ? state.columns[colNum-1] : state.leftIndent + state.firstLineIndent);
							hn.attributes["style"] = "width: " ~ text(width / 20.0) ~ "pt";
						}
						colNum++;
						break;
					default:
						throw new Exception("Unknown XML tag " ~ n.tag);
				}

				foreach (name, value; n.attributes)
					if (name == "id")
						hn.attributes["id"] = value;
					else
					if (name.skipOver("html:"))
						hn.attributes[name] = value;

				break;
			case XmlNodeType.Text:
				hn = new XmlNode(XmlNodeType.Text, n.tag);
				break;
			default:
				throw new Exception("Unknown XML node type");
		}

		foreach (child; n.children)
			walk(child, hn, state);

		bool mergeStyle(XmlNode target, XmlNode[] sources...)
		{
			auto styles = sources
				.map!(source => source.attributes.get("style", null))
				.filter!identity
				.map!(style => style.split(";"))
				.join()
				.map!(style => style.findSplit(":"))
				.map!(style => tuple(style[0].strip, style[2].strip))
				.array;

			OrderedMap!(string, string) styleMap;
			foreach (style; styles)
				if (style[0] in styleMap)
				{
					switch (style[0])
					{
						case "margin-left":
						case "text-indent":
						{
							enforce(style[1].endsWith("pt"));
							enforce(styleMap[style[0]].endsWith("pt"));
							styleMap[style[0]] = (styleMap[style[0]][0..$-2].to!float + style[1][0..$-2].to!float).text ~ "pt";
							break;
						}
						case "font-family":
						case "font-size":
						case "font-weight":
						case "font-style":
						case "text-decoration":
						case "text-align":
						case "vertical-align":
						case "color":
							styleMap[style[0]] = style[1];
							break;
						case "width":
							return false;
						default:
							assert(false, "Don't know how to merge style: " ~ style[0]);
					}
				}
				else
					styleMap[style[0]] = style[1];

			assert(target.type == XmlNodeType.Node);
			if (target.tag == "table" && "padding-left" in styleMap)
				return false;

			auto ids = sources
				.map!(source => source.attributes.get("id", null))
				.filter!identity
				.array;
			if (ids.length > 1)
				return false;

			string[] values;
			foreach (name, value; styleMap)
				values ~= name ~ ": " ~ value;
			target.attributes["style"] = values.join("; ");
			if (ids.length)
				target.attributes["id"] = ids[0];

			return true;
		}

		// <div> is not allowed in <table> - push styles in such <div> blocks down to their children
		if (hn.type == XmlNodeType.Node && hn.tag == "table")
			foreach_reverse (i, child; hn.children)
				if (child.type == XmlNodeType.Node && child.tag == "div")
				{
					foreach (child2; child.children)
						mergeStyle(child2, child, child2).enforce("Can't collapse div inside table");
					hn.children = hn.children[0..i] ~ child.children ~ hn.children[i+1..$];
				}

		if (hn.children.length == 1 &&
			hn.children[0].type == XmlNodeType.Node &&
			hn.children[0].tag.isOneOf("div", "span") &&
			"style" in hn.children[0].attributes &&
			mergeStyle(hn, hn, hn.children[0]))
			hn.children = hn.children[0].children;

		if (hn.children.length == 1 &&
			hn.children[0].type == XmlNodeType.Node &&
			hn.tag.isOneOf("div", "span") &&
			"style" in hn.attributes &&
			mergeStyle(hn.children[0], hn, hn.children[0]))
			hn = hn.children[0];

		if (hn.type == XmlNodeType.Node && hn.tag == "tr")
		{
			if (hn.children.length == 0)
				hn.children ~= new XmlNode(XmlNodeType.Node, "td");
			else
				foreach (i, child; hn.children[0..$-1])
				{
					assert(child.type == XmlNodeType.Node && child.tag == "td");
					if (child.attributes.get("style", null).indexOf("width:") < 0)
						child.attributes["style"] = ("style" in child.attributes ? child.attributes["style"] ~ "; " : "") ~ "width: 36pt";
				}
		}

		if (hn.type == XmlNodeType.Node && hn.tag == "table")
			foreach (child; hn.children)
				assert(child.type == XmlNodeType.Node && child.tag == "tr");
		if (hn.type == XmlNodeType.Node && hn.tag == "tr")
			foreach (child; hn.children)
				assert(child.type == XmlNodeType.Node && child.tag == "td");

		parent.children ~= hn;
	}

	auto html = new XmlDocument();
	walk(xml["document"], html, State.init);

	PrettyXmlWriter writer;

	void writeNode(XmlNode node)
	{
		void writeChildren()
		{
			foreach (child; node.children)
				writeNode(child);
		}

		void writeAttributes()
		{
			foreach (key, value; node.attributes)
				writer.addAttribute(key, value);
		}

		switch (node.type)
		{
			case XmlNodeType.Root:
				writeChildren();
				return;
			case XmlNodeType.Node:
				writer.startTagWithAttributes(node.tag);
				writeAttributes();
				if (node.children.length)
				{
					bool oldEnabled = writer.formatter.enabled;
					bool newEnabled;
					switch (node.tag)
					{
						case "p":
							newEnabled = false;
							break;
						case "td":
							newEnabled = node.findNodes("p") || node.findNodes("table");
							break;
						case "li":
						{
							int countLines(XmlNode n)
							{
								int count = 0;
								if (n.type == XmlNodeType.Node && n.tag.isOneOf("p", "ul", "tr"))
									count++;
								foreach (child; n.children)
								{
									count += countLines(child);
									if (count > 1)
										return count;
								}
								return count;
							}
							newEnabled = countLines(node) > 1;
							break;
						}
						default:
							newEnabled = oldEnabled;
							break;
					}
					writer.formatter.enabled = newEnabled;
					writer.endAttributes();
					writeChildren();
					writer.endTag(node.tag);
					writer.formatter.enabled = oldEnabled;
					if (oldEnabled && !newEnabled)
						writer.newLine();
				}
				else
					writer.endAttributesAndTag();
				return;
			case XmlNodeType.Text:
				writer.startLine();
				writer.text(node.tag);
				writer.newLine();
				return;
			default:
				assert(false);
		}
	}

	writeNode(html);

	return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE HTML>\n" ~ writer.output.get();
}
