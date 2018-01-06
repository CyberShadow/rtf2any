module rtf2any.rtf.lexer;

import std.conv;
import std.format;

import rtf2any.common;

struct ControlWord
{
	string word;
	int _num;
	bool haveNum;

	@property int num() { assert(haveNum); return _num; }
	@property void num(int value) { haveNum = true; _num = value; }

	@property bool flag()
	{
		if (haveNum)
		{
			assert (_num == 0);
			return false;
		}
		else
			return true;
	}
}

enum ElementType { Text, ControlWord, Group }

struct Element
{
	ElementType type;
	union
	{
		ControlWord word;
		Element[] group;
		string text;
	}

	string toString()
	{
		final switch (type)
		{
			case ElementType.Text:
				return format("%(%s%)", [text]);
			case ElementType.ControlWord:
				return word.text;
			case ElementType.Group:
				return group.text;
		}
	}
}

struct Lexer
{
	string rtf;
	int p;

	char peek()
	{
		return rtf[p];
	}

	char readChar()
	{
		//writef("%s", rtf[p]); stdout.flush();
		return rtf[p++];
	}

	void skipChar()
	{
		//writef("%s", rtf[p]); stdout.flush();
		p++;
	}

	void expect(char c)
	{
		char r = readChar();
		if (r != c)
			throw new Exception("Expected " ~ c ~ ", got " ~ r);
	}

	ControlWord readControlWord()
	{
		expect('\\');
		ControlWord word;
		bool inNum;
		string num;
		while (true)
		{
			char c = peek();
			if (!inNum && (c>='a' && c<='z') || (c>='A' && c<='Z'))
				word.word ~= c;
			else
			if (!inNum && c=='-')
			{
				inNum = true;
				num ~= c;
			}
			else
			if (c>='0' && c<='9')
			{
				inNum = true;
				num ~= c;
			}
			else
			if (c==' ')
			{
				skipChar();
				break;
			}
			else
			{
				if (word.word.length==0)
				{
					word.word = [c];
					skipChar();
				}
				break;
			}
			skipChar();
		}
		if (inNum)
			word.num = to!int(num);
		return word;
	}

	Element[] readGroup()
	{
		expect('{');
		Element[] elements;
		while (true)
		{
			char c = peek();
			switch (c)
			{
			case '\\':
			{
				auto e = Element(ElementType.ControlWord);
				e.word = readControlWord();
				elements ~= e;
				break;
			}
			case '{':
			{
				auto e = Element(ElementType.Group);
				e.group = readGroup();
				elements ~= e;
				break;
			}
			case '}':
				skipChar();
				return elements;
			case '\r':
			case '\n':
				skipChar();
				break;
			default:
				if (elements.length && elements[$-1].type == ElementType.Text)
					elements[$-1].text ~= c;
				else
				{
					auto e = Element(ElementType.Text);
					e.text = [c];
					elements ~= e;
				}
				skipChar();
				break;
			}
		}
	}

	Element[] lex()
	{
		return readGroup();
	}
}
