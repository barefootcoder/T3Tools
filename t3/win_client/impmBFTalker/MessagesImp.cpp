//---------------------------------------------------------------------------
//#include <vcl.h>
#pragma hdrstop

#include "MessagesImp.h"


//---------------------------------------------------------------------------
#pragma package(smart_init)

//---------------------------------------------------------------------------

Message::Message (String xml_message)
{
	//constructs Message object from URL-encoded XML message
	//change this code if needed according to the final structure of XML message
	//(arg must be passed by value because it may come from a temp object)

	TStringList* attr_set = new TStringList;

	parseXmlElement(xml_message, attr_set, message_text);

	//convert attribute values to Message properties:
	message_id = attr_set->Values["id"];
	from = attr_set->Values["from"];
	location = attr_set->Values["location"];
	time = attr_set->Values["time"];
	to = attr_set->Values["to"];
	status = attr_set->Values["status"];
	thread = attr_set->Values["subject"];

	//restore xml escaped characters in thread and message data
	xmlUnEscape(thread);
	xmlUnEscape(message_text);

	delete attr_set;
}
//---------------------------------------------------------------------------

Message::Message (String what_id, String who_from, String who_to,
				  String what_status, String what_thread, String what_message_text)
{
	//constructs Message object from discrete data
	//(args must be passed by value because some may come from temp objects)

	message_id = what_id;
	from = who_from;
	to = who_to;
	status = what_status;
	thread = what_thread;
	message_text = what_message_text;

	//add initialization for more member vars as needed
}
//---------------------------------------------------------------------------

String Message::toXML () const
{
	//creates XML message from a Message object
	//this code may change based on changes to the structure of XML message

	//escape xml-reserved characters in thread
	String encoded_thread = thread;
	xmlEscape(encoded_thread);

	//escape xml-reserved characters in message content
	String encoded_message_text = message_text;
	xmlEscape(encoded_message_text);

	String xml = "<MESSAGE";
	xml += ( " id=\"" + message_id + '\"');
	xml += ( " from=\"" + from + '\"');
	xml += ( " location=\"" + location + '\"');
	xml += ( " time=\"" + time + '\"');
	xml += ( " to=\"" + to + '\"');
	xml += ( " status=\"" + status + '\"');
	xml += ( " subject=\"" + encoded_thread + '\"');
	xml += ( String(">") + encoded_message_text + "</MESSAGE>" );

	return xml;
}
//---------------------------------------------------------------------------

void Message::xmlEscape (String& what_text) const
{
	for (int i = 1; i <= what_text.Length(); i++)
	{
		switch (what_text[i])
		{
		  case '\r' :
			what_text.Delete(i, 1);
			what_text.Insert("&#13;", i);
			i += 4;
			break;
		  case '\n' :
			what_text.Delete(i, 1);
			what_text.Insert("&#10;", i);
			i += 4;
			break;
		  case '/' :
			what_text.Delete(i, 1);
			what_text.Insert("&#47;", i);
			i += 4;
			break;
		  case '<' :
			what_text.Delete(i, 1);
			what_text.Insert("&lt;", i);
			i += 3;
			break;
		  case '>' :
			what_text.Delete(i, 1);
			what_text.Insert("&gt;", i);
			i += 3;
			break;
		  case '\"' :
			what_text.Delete(i, 1);
			what_text.Insert("&quot;", i);
			i += 5;
			break;
		  case '&' :
			what_text.Delete(i, 1);
			what_text.Insert("&amp;", i);
			i += 4;
			break;
		}
	}
}
//---------------------------------------------------------------------------

void Message::xmlUnEscape (String& what_text) const
{
	for (int i = 1; i <= what_text.Length(); i++)
	{
		if (what_text[i] == '&')
		{
			if (what_text.SubString(i, 5) == "&#13;")
			{
				what_text.Delete(i, 5);
				what_text.Insert("\r", i);
			}
			else if (what_text.SubString(i, 5) == "&#10;")
			{
				what_text.Delete(i, 5);
				what_text.Insert("\n", i);
			}
			else if (what_text.SubString(i, 5) == "&#47;")
			{
				what_text.Delete(i, 5);
				what_text.Insert("/", i);
			}
			else if (what_text.SubString(i, 4) == "&lt;")
			{
				what_text.Delete(i, 4);
				what_text.Insert("<", i);
			}
			else if (what_text.SubString(i, 4) == "&gt;")
			{
				what_text.Delete(i, 4);
				what_text.Insert(">", i);
			}
			else if (what_text.SubString(i, 6) == "&quot;")
			{
				what_text.Delete(i, 6);
				what_text.Insert("\"", i);
			}
			else if (what_text.SubString(i, 5) == "&amp;")
			{
				what_text.Delete(i, 5);
				what_text.Insert("&", i);
			}

		}
	}

}
//---------------------------------------------------------------------------

void Message::parseXmlElement (String& element,
										TStringList* attributes, String& data)
//pass to this method an XML element (must begin and end w/ tags) and it splits
//it into a list of attributes (name=value, no quotes) and the element data
{
	bool in_a_value = false;

	String attr;
	String tag;
	int start_of_attrs;
	int start_of_data;

	for (int i = 1; i <= element.Length(); i++)	//detect start of attrs if any
	{
		if (element[i] == ' ' || element[i] == '>')
		{
			start_of_attrs = i;
			break;
		}
		else
			tag += element[i];
	}

	//read attributes
	for (int i = start_of_attrs; i <= element.Length(); i++)
	{                     
		if (element[i] == '\"')
		{
			in_a_value = !in_a_value;
			if (!in_a_value)
			{
				attributes->Add(attr);		//finished previous attr
				attr = "";
			}
		}
		else if (!in_a_value && element[i] == '>')
		{                       
			start_of_data = i + 1;
			break;
		}
		else if (element[i] != ' ' || in_a_value)
		{
			attr += element[i];
		}
	}

	//read data
	tag.Insert("/", 2);					//convert start-tag to end-tag
	int end_of_data = element.Pos(tag);
	data = element.SubString(start_of_data, end_of_data - start_of_data);

}
//---------------------------------------------------------------------------

