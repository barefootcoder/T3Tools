//---------------------------------------------------------------------------
#ifndef MessagesImpH
#define MessagesImpH
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
class Message
{
public:
	Message () {}
	Message (String xml_message);		//constructs Message from XML message
	Message (String who_from, String who_to,		//constructs from data
			String what_status, String what_thread, String what_message_text);

	//key methods
	String toXML ();					//turns Message into XML message

	//key properties
	String message_id;					//RFU
	String from;
	String location;					//workstation of 'from' user
	String time;						//timestamp a message is sent
	String to;
	String status;
	String thread;
	String message_text;

	//auxiliary methods
	void parseXmlElement(String& element, TStringList* attributes, String& data);

private:
	//auxiliary methods
	void xmlEscape (String& what_text);
	void xmlUnEscape (String& what_text);


};

//---------------------------------------------------------------------------
#endif
