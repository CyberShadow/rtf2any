module rtf2any.xml.helpers;

import std.algorithm.iteration;
import std.array;
import std.conv;

import ae.utils.aa;
import ae.utils.xmllite;

bool isTag(XmlNode n, string tag, XmlNodeType type = XmlNodeType.Node)
{
	return n.type == type && n.tag ==  tag;
}

bool isWhitespace(XmlNode n)
{
	import std.string : strip;
	return n.type == XmlNodeType.Text && !strip(n.tag).length;
}

XmlNode findOnlyChild(XmlNode n, string tag, XmlNodeType type = XmlNodeType.Node)
{
	return n.isTag(tag, type) ? n :
		n.children.length != 1 ? null :
		n.children[0].findOnlyChild(tag, type);
}

XmlNode findOnlyChild(XmlNode n, XmlNodeType type)
{
	return n.type == type ? n :
		n.children.length != 1 ? null :
		n.children[0].findOnlyChild(type);
}

XmlNode[] findNodes(XmlNode n, string tag)
{
	if (n.isTag(tag))
		return [n];
	return n.children.map!(n => findNodes(n, tag)).join;
}

alias Attributes = OrderedMap!(string, string);

XmlNode newNode(XmlNodeType type, string tag, Attributes attributes, XmlNode[] children = null)
{
	auto node = new XmlNode(type, tag);
	node.attributes = attributes;
	node.children = children;
	return node;
}

XmlNode newNode(string tag, Attributes attributes, XmlNode[] children = null)
{
	return newNode(XmlNodeType.Node, tag, attributes, children);
}

XmlNode newNode(XmlNodeType type, string tag, string[string] attributes = null, XmlNode[] children = null)
{
	return newNode(type, tag, Attributes(attributes), children);
}

XmlNode newNode(string tag, string[string] attributes = null, XmlNode[] children = null)
{
	return newNode(XmlNodeType.Node, tag, attributes, children);
}

XmlNode newTextNode(string text)
{
	return newNode(XmlNodeType.Text, text);
}

// For error messages
string describeNode(XmlNode node)
{
	switch (node.type)
	{
		case XmlNodeType.Node:
			return "<" ~ node.tag ~ ">";
		case XmlNodeType.Meta:
			return "<?" ~ node.tag ~ "?>";
		case XmlNodeType.Text:
			return "text node (\"" ~ node.tag ~ "\")";
		default:
			return node.type.to!string;
	}
}
