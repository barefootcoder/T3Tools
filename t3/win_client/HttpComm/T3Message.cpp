//---------------------------------------------------------------------------
#include <iostream>
#include <string>
#include <map>
using namespace std;

#include "T3Message.h"

//---------------------------------------------------------------------------
T3Message::T3Message ()
{
	return;
}
//---------------------------------------------------------------------------
T3Message::T3Message (const string& ele_name, const string& xml_msg)
{
	m_element_name = ele_name;
	parseXmlMessage(xml_msg);

	return;
}
//---------------------------------------------------------------------------
T3Message::T3Message (const string& ele_name, 
					  const map<string, string>& attr, const string& content)
{
	m_element_name = ele_name;
	m_attributes = attr;
	m_content = content;

	return;
}
//---------------------------------------------------------------------------
T3Message::T3Message (const T3Message& t3msg)
{
	m_element_name = t3msg.m_element_name;
	m_attributes = t3msg.m_attributes;
	m_content = t3msg.m_content;

	return;
}
//---------------------------------------------------------------------------
void T3Message::setElementName (const string& element_name)
{
	m_element_name = element_name;
	return;
}
//---------------------------------------------------------------------------
string T3Message::getElementName () const
{
	return m_element_name;
}
//---------------------------------------------------------------------------
void T3Message::setAttribute (const string& key, const string& value)
{
	m_attributes[key] = value;
	return;
}
//---------------------------------------------------------------------------
string T3Message::getAttribute (const string& key) const
{
	string rc = "";
	map<string,string>::const_iterator i = m_attributes.find(key);
	if ( i != m_attributes.end() )
		rc = i->second;

	return rc;
}
//---------------------------------------------------------------------------
void T3Message::setContent (const string& content)
{
	m_content = content;
	return;
}
//---------------------------------------------------------------------------
string T3Message::getContent () const
{
	return m_content;
}
//---------------------------------------------------------------------------
string T3Message::toXML () const
{
	// start the message
	string xml = "<" + m_element_name;

	// loop through the map
	for ( map<string,string>::const_iterator i = m_attributes.begin();
		  i != m_attributes.end(); ++i )
	{
		xml = xml + " " + i->first + "=\"" + xmlEscape(i->second) + "\"";
	}
	
	//add escape xml-reserved characters in message content
	xml = xml + ">" + xmlEscape(m_content);

	// add the end tag
	xml = xml + "</" + m_element_name + ">";

	return xml;
}
//---------------------------------------------------------------------------
string T3Message::xmlEscape (string what_text)
{
	for (size_t i = 0; i < what_text.length(); i++)
	{
		switch (what_text[i])
		{
		  case '\r' :
			what_text.erase(i, 1);
			what_text.insert(i, "&#13;");
			i += 4;
			break;
		  case '\n' :
			what_text.erase(i, 1);
			what_text.insert(i, "&#10;");
			i += 4;
			break;
		  case '/' :
			what_text.erase(i, 1);
			what_text.insert(i, "&#47;");
			i += 4;
			break;
		  case '<' :
			what_text.erase(i, 1);
			what_text.insert(i, "&lt;");
			i += 3;
			break;
		  case '>' :
			what_text.erase(i, 1);
			what_text.insert(i, "&gt;");
			i += 3;
			break;
		  case '\"' :
			what_text.erase(i, 1);
			what_text.insert(i, "&quot;");
			i += 5;
			break;
		  case '&' :
			what_text.erase(i, 1);
			what_text.insert(i, "&amp;");
			i += 4;
			break;
		}
	}

	return what_text;
}
//---------------------------------------------------------------------------
string T3Message::xmlUnEscape (string what_text)
{
	for (size_t i = 0; i < what_text.length(); i++)
	{
		if (what_text[i] == '&')
		{
			if (what_text.substr(i, 5) == "&#13;")
			{
				what_text.erase(i, 5);
				what_text.insert(i, "\r");
			}
			else if (what_text.substr(i, 5) == "&#10;")
			{
				what_text.erase(i, 5);
				what_text.insert(i, "\n");
			}
			else if (what_text.substr(i, 5) == "&#47;")
			{
				what_text.erase(i, 5);
				what_text.insert(i, "/");
			}
			else if (what_text.substr(i, 4) == "&lt;")
			{
				what_text.erase(i, 4);
				what_text.insert(i, "<");
			}
			else if (what_text.substr(i, 4) == "&gt;")
			{
				what_text.erase(i, 4);
				what_text.insert(i, ">");
			}
			else if (what_text.substr(i, 6) == "&quot;")
			{
				what_text.erase(i, 6);
				what_text.insert(i, "\"");
			}
			else if (what_text.substr(i, 5) == "&amp;")
			{
				what_text.erase(i, 5);
				what_text.insert(i, "&");
			}

		}
	}

	return what_text;
}
//---------------------------------------------------------------------------
//pass to this method an XML element (must begin and end w/ tags) and it splits
//it into a list of attributes (name=value, no quotes) and the element data
bool T3Message::parseXmlMessage (const string& xml_msg)
{
	bool rc = false;
	bool in_a_value = false;

	string attr = "";
	string tag = "";
	int start_of_attrs = 0;
	int start_of_data = 0;

	// start at 1 because 0 = "<" for start of tag
	for (size_t i = 1; i < xml_msg.length(); i++)
	{
		if (xml_msg[i] == ' ' || xml_msg[i] == '>')
		{
			start_of_attrs = i;
			break;
		}
		else
		{
			tag += xml_msg[i];
		}
	}

	// check tag
	if ( tag == m_element_name )
	{
		//read attributes
		for (size_t i = start_of_attrs; i < xml_msg.length(); i++)
		{                     
			if (xml_msg[i] == '\"')
			{
				in_a_value = !in_a_value;
				if (!in_a_value)
				{
					int eq = attr.find("=");

					// Debug
					//cout << "Adding attribute:  |" << attr << "|\n";
					//cout << "Key  :  |" << attr.substr(0, eq) << "|\n";
					//cout << "Value:  |" << attr.substr(eq + 1) << "|\n";

					m_attributes[attr.substr(0, eq)] = 
										xmlUnEscape(attr.substr(eq + 1));
					attr = "";
				}
			}
			else if (!in_a_value && xml_msg[i] == '>')
			{                       
				start_of_data = i + 1;
				break;
			}
			else if (xml_msg[i] != ' ' || in_a_value)
			{
				attr += xml_msg[i];
			}
		}

		//convert start-tag to end-tag
		tag = "/" + tag;   
		int end_of_data = xml_msg.find(tag, start_of_data) - 1;

		//read data
		m_content = xmlUnEscape(xml_msg.substr(start_of_data, 
											   end_of_data - start_of_data));
		// debug 
		//cout << "End Tag: |" << tag << "|\n";
		//cout << "Data starts at:  " << start_of_data << "\n";
		//cout << "Found tag at:  " << end_of_data << "\n";
		//cout << "Data:  |" << m_content << "|\n";
		//cout << "Length of msg:  " << xml_msg.length() << "\n";

	}
	else
	{
		// debug
		//cout << "DEBUG:  Tag name do not match\n";
		//cout << "Should be:  |" << m_element_name << "|\n";
		//cout << "Found    :  |" << tag << "|\n";

		// bad message
		rc = false;
	}

	return rc;
}
//---------------------------------------------------------------------------

