module rtf2any.xml.reader;

import ae.utils.xmllite;

XmlDocument parseRTFXML(string s)
{
	static struct ParseConfig
	{
	static:
		NodeCloseMode nodeCloseMode(string tag) { return XmlParseConfig.nodeCloseMode(tag); }
		bool preserveWhitespace(string tag) { return tag == "p"; }
		enum optionalParameterValues = XmlParseConfig.optionalParameterValues;
	}
	return parseDocument!ParseConfig(s);
}
