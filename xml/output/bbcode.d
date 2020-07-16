module rtf2any.xml.output.bbcode;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;
import std.format;
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

string toBBCode(XmlDocument xml)
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

	// uint colNum;
	// XmlNode[] stack;

	Appender!string o;

	void visit(XmlNode n, State state)
	{
		// stack ~= n;
		// scope(exit) stack = stack[0..$-1];

		switch (n.type)
		{
			case XmlNodeType.Node:
				switch (n.tag)
				{
					case "document":
						foreach (child; n.children)
							visit(child, state);
						break;
					case "b":
					case "i":
					case "u":
					case "sub":
						o.formattedWrite!"[%s]"(n.tag);
						foreach (child; n.children)
							visit(child, state);
						o.formattedWrite!"[/%s]"(n.tag);
						break;
					case "super":
						o ~= "[sup]";
						foreach (child; n.children)
							visit(child, state);
						o ~= "[/sup]";
						break;
					case "no-b":
					case "no-i":
					case "no-u":
						o.formattedWrite!"[/%s]"(n.tag);
						foreach (child; n.children)
							visit(child, state);
						o.formattedWrite!"[%s]"(n.tag);
						break;
					case "align":
						o.formattedWrite!"[%s]"(n.attributes.aaGet("dir"));
						foreach (child; n.children)
							visit(child, state);
						o.formattedWrite!"[/%s]"(n.attributes.aaGet("dir"));
						break;
					case "indent":
					{
						bool list = n.attributes.aaGet("list").to!bool;
						if (list) o ~= "[list]";
						foreach (child; n.children)
							visit(child, state);
						if (list) o ~= "[/list]";
						break;
					}
					case "font":
						// TODO?
						foreach (child; n.children)
							visit(child, state);
						break;
					case "size":
					{
						auto size = n.attributes.aaGet("pt").to!int;
						if (size != 20) o.formattedWrite!"[size=%spt]"(size / 2f);
						foreach (child; n.children)
							visit(child, state);
						if (size != 20) o ~= "[/size]";
						break;
					}
					case "color":
						o.formattedWrite!"[color=%s]"(n.attributes.aaGet("rgb"));
						foreach (child; n.children)
							visit(child, state);
						o ~= "[/color]";
						break;
					case "hyperlink":
						o.formattedWrite!"[url=%s]"(n.attributes.aaGet("url"));
						foreach (child; n.children)
							visit(child, state);
						o ~= "[/url]";
						break;
					case "local-link":
						// No equivalent
						foreach (child; n.children)
							visit(child, state);
						break;
					case "tabs":
						// TODO
						foreach (child; n.children)
							visit(child, state);
						break;
					case "li":
						o ~= "[li]";
						foreach (child; n.children)
							visit(child, state);
						o ~= "[/li]";
						break;
					case "p":
						foreach (child; n.children)
							visit(child, state);
						o ~= "\n";
						break;
					case "col":
						// TODO
						foreach (child; n.children)
							visit(child, state);
						break;
					default:
						throw new Exception("Unknown XML tag " ~ n.tag);
				}

				break;
			case XmlNodeType.Text:
				o ~= n.tag;
				break;
			default:
				throw new Exception("Unknown XML node type");
		}
	}

	visit(xml["document"], State.init);
	return o.data;
}
