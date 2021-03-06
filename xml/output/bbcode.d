module rtf2any.xml.output.bbcode;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.path;
import std.range.primitives;
import std.string;
import std.typecons;

import ae.utils.aa;
import ae.utils.array;
import ae.utils.meta;
import ae.utils.xmllite;
import ae.utils.xmlwriter;

import rtf2any.xml.reader;
import rtf2any.xml.helpers;

enum postLimit = 20000 - 200;

string toBBCode(XmlDocument xml)
{
	struct State
	{
		bool splittingAllowed = true;
	}

	// uint colNum;
	string[3][] stack;

	Appender!string result;
	Appender!(char[]) buf;

	size_t lastCheckpoint;
	string[3][] lastCheckpointStack;

	void visit(XmlNode n, State state, size_t childIndex)
	{
		void descend(string tag, string arguments = null, string closeTag = null)
		{
			void visitChildren()
			{
				foreach (i, child; n.children)
					visit(child, state, i);
			}

			if (tag || closeTag)
			{
				if (!closeTag) closeTag = tag;
				stack ~= [tag, arguments, closeTag];
				scope(exit) stack = stack[0..$-1];

				buf.formattedWrite!"[%s%s]"(tag, arguments);
				visitChildren();
				if (closeTag.length)
					buf.formattedWrite!"[/%s]"(closeTag);
			}
			else
				visitChildren();
		}

		void checkpoint()
		{
			if (!state.splittingAllowed)
				return;

			if (buf.data.length > postLimit)
			{
				result.put(buf.data[0 .. lastCheckpoint]);
				foreach_reverse (n; lastCheckpointStack)
					if (n[2].length)
						result.formattedWrite!"[/%s]"(n[2]);
				result.put("\n\n---------------------------------------------------------------------------------------------------------------------------\n\n");
				foreach (n; lastCheckpointStack)
					result.formattedWrite!"[%s%s]"(n[0], n[1]);

				auto remainder = buf.data[lastCheckpoint .. $].idup;
				buf.clear();
				buf.put(remainder);
			}

			enforce(buf.data.length <= postLimit, "Splitting failed");

			lastCheckpoint = buf.data.length;
			lastCheckpointStack = stack;
		}

		switch (n.type)
		{
			case XmlNodeType.Node:
				switch (n.tag)
				{
					case "document":
						descend(null);
						break;
					case "b":
					case "i":
					case "u":
					case "sub":
						descend(n.tag);
						break;
					case "super":
						descend("sup");
						break;
					// case "no-b":
					// case "no-i":
					// case "no-u":
					// 	o.formattedWrite!"[/%s]"(n.tag);
					// 	visitChildren();
					// 	o.formattedWrite!"[%s]"(n.tag);
					// 	break;
					case "align":
						descend(n.attributes.aaGet("dir"));
						break;
					case "indent":
					{
						bool list = n.attributes.aaGet("list").to!bool;
						descend(list ? "list" : null);
						break;
					}
					case "font":
						// TODO?
						descend(null);
						break;
					case "size":
					{
						auto size = n.attributes.aaGet("pt").to!int;
						descend(size != 20 ? "size" : null, format!"=%spt"(size / 2f));
						break;
					}
					case "color":
						descend("color", format!"=%s"(n.attributes.aaGet("rgb")));
						break;
					case "hyperlink":
						descend("url", format!"=%s"(n.attributes.aaGet("url")));
						break;
					case "local-link":
						// No equivalent
						descend(null);
						break;
					case "tabs":
						// TODO
						descend(null);
						break;
					case "li":
						if (childIndex == 0)
							state.splittingAllowed = false;
						descend("*", null, "");
						break;
					case "p":
						descend(null);
						buf.put("\n");
						break;
					case "col":
						// TODO
						descend(null);
						break;
					default:
						throw new Exception("Unknown XML tag " ~ n.tag);
				}

				break;
			case XmlNodeType.Text:
				if (stack.filter!(s => s[0] == "*").walkLength <= 2)
					checkpoint();
				buf.put(n.tag);
				break;
			default:
				throw new Exception("Unknown XML node type");
		}
	}

	visit(xml["document"], State.init, 0);
	result.put(buf.data);
	return result.data;
}
