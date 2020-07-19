module rtf2any.xml.output.mediawiki;

import std.algorithm.iteration;
import std.algorithm.searching;
import std.array;
import std.conv;
import std.exception;
import std.format;
import std.path;
import std.range.primitives;
import std.regex;
import std.string;
import std.typecons;

import ae.utils.aa;
import ae.utils.array;
import ae.utils.meta;
import ae.utils.text.html;
import ae.utils.xmllite;
import ae.utils.xmlwriter;

import rtf2any.xml.reader;
import rtf2any.xml.helpers;

string[string] toMediaWiki(XmlDocument xml, string mainPage, HashSet!string nonWikiSections = HashSet!string(), HashSet!string subpageSections = HashSet!string())
{
	struct State
	{
		int listLevel = 0;
		bool inHeading = false;
		bool inSubpageHeading = false;
		bool inTable = false;
		bool inCell = false;
	}

	bool outputting = true;
	bool headingWritten = false;
	bool tableStarted = false;
	bool listStillActive = true;
	int headingLevel = 0;
	int newlinesWritten = 0;
	string currentPageName = mainPage;
	string nextPageName;

	string[string] results;
	Appender!(char[])[string] bufs;
	bufs[mainPage] = Appender!(char[])();

	void visit(XmlNode n, State state, size_t childIndex)
	{
		void visitChildren()
		{
			foreach (i, child; n.children)
				visit(child, state, i);
		}

		void descendHtml(string tag, string arguments = null, string closeTag = null)
		{
			if (tag || closeTag)
			{
				if (!closeTag) closeTag = tag;

				if (outputting)
				{
					bufs[currentPageName].formattedWrite!"<%s%s>"(tag, arguments);
					newlinesWritten = 0;
				}
				visitChildren();
				if (closeTag.length && outputting)
				{
					bufs[currentPageName].formattedWrite!"</%s>"(closeTag);
					newlinesWritten = 0;
				}
			}
			else
				visitChildren();
		}

		void descendOther(string open, string close = null)
		{
			if (!close) close = open;

			if (outputting)
			{
				bufs[currentPageName].formattedWrite!"%s"(open);
				newlinesWritten = 0;
			}
			visitChildren();
			if (close.length && outputting)
			{
				bufs[currentPageName].formattedWrite!"%s"(close);
				newlinesWritten = 0;
			}
		}

		switch (n.type)
		{
			case XmlNodeType.Node:
			{
				if ("id" in n.attributes)
				{
					if (n.attributes.aaGet("id") in nonWikiSections)
					{
						outputting = false;
					}
					else
					{
						outputting = true;
						currentPageName = mainPage;
					}

					if (n.attributes.aaGet("id") in subpageSections)
					{
						// we want to output just the heading in the current document; and start a new one for the contents.
						state.inSubpageHeading = true;
						nextPageName = "";
					}
				}
				switch (n.tag)
				{
					case "document":
						descendHtml(null);
						break;
					case "b":
					case "no-b":
						if (state.inHeading || (state.inTable && !state.inCell))
							descendHtml(null);
						else
							descendOther("'''");
						break;
					case "i":
					case "no-i":
						if (state.inHeading || (state.inTable && !state.inCell))
							descendHtml(null);
						else
							descendOther("''");
						break;
					case "u":
					case "sub":
						descendHtml((state.inHeading || (state.inTable && !state.inCell)) ? null : n.tag);
						break;
					case "super":
						descendHtml("sup");
						break;
					case "no-u":
						if (outputting)
						{
						 	bufs[currentPageName].put("</u>");
							newlinesWritten = 0;
						}
					 	visitChildren();
						if (outputting)
						{
						 	bufs[currentPageName].put("<u>");
							newlinesWritten = 0;
						}
					 	break;
					case "align":
						descendHtml("div", format!` style="text-align:%s"`(n.attributes.aaGet("dir")));
						break;
					case "indent":
					{
						bool list = n.attributes.aaGet("list").to!bool;
						if (list)
						{
							if (outputting && newlinesWritten == 0)
							{
								bufs[currentPageName].put("\n");
								++newlinesWritten;
							}
							++state.listLevel;
						}
						visitChildren();
						break;
					}
					case "font":
						descendHtml(null);
						break;
					case "size":
					{
						auto size = n.attributes.aaGet("pt").to!int;
						if (size > 20)
						{
							// in a heading we want to disable most formatting
							state.inHeading = true;
							headingLevel = size == 28 ? 2 : 3;
							headingWritten = false;
							descendHtml(null);
							if (headingWritten)
							{
								if (outputting)
								{
									if (state.inSubpageHeading)
										bufs[currentPageName].put("]]");
									bufs[currentPageName].put("=".replicate(headingLevel));
									bufs[currentPageName].put("\n");
									newlinesWritten = 1;
									if (state.inSubpageHeading)
									{
										currentPageName = nextPageName;
										bufs[currentPageName] = Appender!(char[])();
									}
								}
							}
						}
						else
						{
							descendHtml(size != 20 ? "span" : null, format!" style=\"font-size:%spt\""(size / 2f));
						}
						break;
					}
					case "color":
					{
						auto rgb = n.attributes.aaGet("rgb");
						descendHtml((state.inHeading || (state.inTable && !state.inCell)) ? null : "span", format!" style=\"color:%s\""(rgb == "default" ? "initial" : rgb));
						break;
					}
					case "hyperlink":
						descendOther(format!"[%s "(encodeHtmlEntities(n.attributes.aaGet("url"))), "]");
						break;
					case "local-link":
						descendOther(format!"[[#%s|"(encodeHtmlEntities(n.attributes.aaGet("target-id"))), "]]");
						break;
					case "tabs":
						if (state.listLevel == 0)
						{
							state.inTable = true;
							tableStarted = false;
							descendHtml(null);
							if (outputting && tableStarted)
							{
								if (newlinesWritten == 0)
									bufs[currentPageName].put("\n");
								bufs[currentPageName].put("|}\n");
								newlinesWritten = 1;
							}
						}
						else
							descendHtml(null);
						break;
					case "li":
						listStillActive = true;
						descendOther(format!"%s "("*".replicate(state.listLevel)), "");
						if (outputting && newlinesWritten == 0)
						{
							bufs[currentPageName].put("\n");
							++newlinesWritten;
						}
						break;
					case "p":
						if (state.listLevel != 0 && !listStillActive && newlinesWritten != 0)
						{
							bufs[currentPageName].formattedWrite!"%s:"("*".replicate(state.listLevel));
						}
						descendHtml(null);
						if (state.listLevel == 0 && !state.inHeading && !state.inTable)
						{
							if (outputting && newlinesWritten < 2)
							{
								bufs[currentPageName].put("\n".replicate(2 - newlinesWritten));
								newlinesWritten = 2;
							}
						}
						else if (!state.inHeading && !state.inTable)
						{
							listStillActive = false;
							if (outputting)
								bufs[currentPageName].put("<br />");
						}
						else if (state.inTable && tableStarted)
						{
							if (outputting)
							{
								if (newlinesWritten == 0)
									bufs[currentPageName].put("\n");
								bufs[currentPageName].put("|-\n");
								newlinesWritten = 1;
							}
						}
						break;
					case "col":
						if (!state.inTable)
							descendOther("", " ");
						else
						{
							if (outputting && newlinesWritten == 0)
							{
								bufs[currentPageName].put("\n");
							}
							if (outputting && !tableStarted)
							{
								bufs[currentPageName].put("{|\n");
								tableStarted = true;
							}
							state.inCell = true;
							descendOther("|", "");
							if (outputting && newlinesWritten == 0)
							{
								bufs[currentPageName].put("\n");
								newlinesWritten = 1;
							}
						}
							
						break;
					default:
						throw new Exception("Unknown XML tag " ~ n.tag);
				}

				break;
			}
			case XmlNodeType.Text:
				if (outputting)
				{
					if (state.inHeading && n.tag != "" && !headingWritten)
					{
						if (newlinesWritten < 2)
						{
							bufs[currentPageName].put("\n".replicate(2 - newlinesWritten));
						}
						bufs[currentPageName].put("=".replicate(headingLevel));
						headingWritten = true;

						if (state.inSubpageHeading && nextPageName == "")
						{
							nextPageName = n.tag.findSplit(` (`)[0].encodeHtmlEntities!false();
							bufs[currentPageName].formattedWrite!"[[{{FULLPAGENAME}}/%s|"(nextPageName);
						}
					}
					bufs[currentPageName].put(encodeHtmlEntities!false(n.tag));
					newlinesWritten = 0;
				}
				break;
			default:
				throw new Exception("Unknown XML node type");
		}
	}

	visit(xml["document"], State.init, 0);
	foreach(page; bufs.keys)
	{
		Appender!string result;
		result.put(bufs[page].data);
		results[page] = result.data;
	}
	return results;
}
