module rtf2any.xml.writer;

import ae.utils.xmllite;
import ae.utils.xmlwriter;

string writeRTFXML(XmlNode node)
{
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
			default:
				assert(false);
			case XmlNodeType.Meta:
				node.writeTo(writer);
				break;
			case XmlNodeType.Text:
				writer.startLine();
				writer.text(node.tag);
				writer.newLine();
				return;
		}
	}

	writeNode(node);
	return writer.output.get();
}
