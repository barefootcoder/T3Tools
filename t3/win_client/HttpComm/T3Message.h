//-----------------------------------------------------------------------------
#ifndef MessagesImpH
#define MessagesImpH
//-----------------------------------------------------------------------------

#include <string>
#include <map>
using namespace std;

//-----------------------------------------------------------------------------
class T3Message
{
public:

	T3Message ();
	T3Message (const T3Message& t3msg);
	T3Message (const string& element_name, const string& xml_message);
	T3Message (const string& element_name, 
			   const map<string,string>& attributes, const string& content);

	void setElementName (const string& element_name);
	string getElementName () const;

	void setAttribute (const string& key, const string& value);
	string getAttribute (const string& key) const;

	void setContent (const string& content);
	string getContent () const;

	string toXML () const; //turns Message into XML message

	//auxiliary methods
	static string xmlEscape (string what_text);
	static string xmlUnEscape (string what_text);

private:

	string m_element_name;
	string m_content;
	map<string, string> m_attributes;

	bool parseXmlMessage (const string& xml_msg);
};
//------------------------------------------------------------------------------
#endif
