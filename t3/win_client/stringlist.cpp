//---------------------------------------------------------------------------
#include <algorithm>
#include <fstream>
using namespace std;

#include "stringlist.h"
using namespace arinbe;

//---------------------------------------------------------------------------
StringList::StringList ()
{
	return;
}
//---------------------------------------------------------------------------
StringList::StringList (const StringList& sl)
{
	sl.Merge(*this);
	return;
}
//------------------------------------------------------------------------------
StringList::~StringList ()
{
	return;
}
//------------------------------------------------------------------------------
int StringList::Add (const string& str)
{
	m_list.push_back(str);
	return m_list.size();
}
//------------------------------------------------------------------------------
void StringList::Delete (int index)
{
	int i;
	vector<string>::iterator ki = m_list.begin();
	for ( i = 0; ki != m_list.end() && i < index; ++i, ++ki )
	{
		// do nothing
	}

	if ( i == index && ki != m_list.end() )
		m_list.erase(ki);

	return;
}
//------------------------------------------------------------------------------
void StringList::Delete (const string& str)
{

	vector<string>::iterator ki = find(m_list.begin(), m_list.end(), str);
	if ( ki != m_list.end() )
	{
		// Found it
		m_list.erase(ki);
	}

	return;
}
//------------------------------------------------------------------------------
void StringList::Merge (StringList& str_list) const
{
	vector<string>::const_iterator i = m_list.begin();
	for ( ; i != m_list.end(); i++ )
		str_list.Add(*i);

	return;
}
//------------------------------------------------------------------------------
void StringList::Clear ()
{
	// clear the list
	m_list.clear();

	return;
}
//------------------------------------------------------------------------------
string StringList::Text () const
{
	return Join("\r\n");
}
//------------------------------------------------------------------------------
void StringList::Text (const string& _line, const string& _delim)
{
	Clear();
	SplitAndAdd(_delim, _line);

	return;
}
//------------------------------------------------------------------------------
string StringList::CommaText () const
{
	return Join(",");
}
//------------------------------------------------------------------------------
void StringList::CommaText (const string& _line)
{
	Clear();
	SplitAndAdd(",", _line);

	return;
}
//------------------------------------------------------------------------------
void StringList::SplitAndAdd (const string& split_str, const string& _line)
{
	// make sure we read something
	string  line = _line;
	if ( line.length() > 0 )
	{
		int pos = line.find(split_str);
		while ( pos > -1 )
		{
			// add this to the list
			Add(line.substr(0, pos));

			// new string becomes old string minus the stuff added
			line = line.substr(pos + split_str.length());
			pos = line.find(split_str);
		}

		// check the last chunk
		if ( line.length() > 0 )
			Add(line);
	}

	return;
}
//------------------------------------------------------------------------------
string StringList::Join (const string& join_str) const
{
	string str;

	vector<string>::const_iterator i = m_list.begin();
	for ( ; i != m_list.end(); i++ )
	{
		// add a return 
		if ( str.length() > 0 )
			str = str + join_str;

		// tack on the name
		str = str + *i;  
	}

	return str;
}
//---------------------------------------------------------------------------
StringList StringList::GetNames () const
{
	StringList strlist;

	vector<string>::const_iterator i = m_list.begin();
	for ( ; i != m_list.end(); i++ )
	{
		KeyType kt = MakeKeyType(*i);
		strlist.Add(kt.key_name);  
	}

	return strlist;
}
//---------------------------------------------------------------------------
StringList StringList::GetValues () const
{
	StringList strlist;

	vector<string>::const_iterator i = m_list.begin();
	for ( ; i != m_list.end(); i++ )
	{
		KeyType kt = MakeKeyType(*i);
		strlist.Add(kt.key_value);  
	}

	return strlist;
}
//---------------------------------------------------------------------------
string StringList::String (int index) const
{
	string  str = "";

	// Get and make the string
	if ( index < (int) m_list.size() )
	{
		str = m_list[index];
	}

	return str;
}
//---------------------------------------------------------------------------
string StringList::Value (int index) const
{
	string  result;

	// Get and make the string
	if ( index < (int) m_list.size() )
	{
		KeyType kt = MakeKeyType(m_list[index]);
		result = kt.key_value;
	}

	return result;
}
//---------------------------------------------------------------------------
string StringList::Value (const string& name) const
{
	string  str = "";

	// Get and make the string
	int index = IndexOfName(name);
	if ( index > -1 )
		str = Value(index);

	return str;
}
//---------------------------------------------------------------------------
string StringList::Name (int index) const
{
	string  result = "";

	// Get and make the string
	if ( index < (int) m_list.size() )
	{
		KeyType kt = MakeKeyType(m_list[index]);
		result = kt.key_name;
	}

	return result;
}
//---------------------------------------------------------------------------
void StringList::SetString (int index, const string& value)
{
	Delete(index);
	Add(value);

	return;
}
//---------------------------------------------------------------------------
void StringList::SetValue (int index, const string& value)
{
	string name = Name(index);
	Delete(index);
	Add(name + "=" + value);

	return;
}
//---------------------------------------------------------------------------
void StringList::SetValue (const string& name, const string& value)
{
	// find the name, delete it
	int index = IndexOfName(name);
	if ( index > -1 )
		Delete(index);

	Add(name + "=" + value);

	return;
}
//---------------------------------------------------------------------------
void StringList::SetName (int index, const string& name)
{
	string value = Value(index);
	Delete(index);
	Add(name + "=" + value);

	return;
}
//---------------------------------------------------------------------------
int StringList::IndexOf (const string& str) const
{
	int result = -1;

	vector<string>::const_iterator ki = m_list.begin();
	for (int i = 0; ki != m_list.end(); i++, ki++ )
	{
		if ( !str.compare(*ki) )
		{
			// Found it
			result = i;
			break;
		}
	}

	return result;
}
//---------------------------------------------------------------------------
int StringList::IndexOfName (const string& str) const
{
	int result = -1;

	vector<string>::const_iterator ki = m_list.begin();
	for (int i = 0; ki != m_list.end(); i++, ki++ )
	{
		KeyType key = MakeKeyType(*ki);
		if ( !str.compare(key.key_name) )
		{
			result = i;
			break;
		}
	}

	return result;
}
//---------------------------------------------------------------------------
KeyType StringList::MakeKeyType (const string& str) const
{

	KeyType kt;
	int pos = str.find('=');
	if ( pos > -1 )
	{
		kt.key_name = str.substr(0, pos);
		kt.key_value = str.substr(pos + 1);

		// Assume we want to trim
		TrimString(kt.key_name);
		TrimString(kt.key_value);
	}
	else
	{
		// No equals sign
		kt.key_name = str;
	}

	return kt;
}
//---------------------------------------------------------------------------
void StringList::TrimString (string& str) const
{
	// left trim
	while ( isspace(str[0]) && (str.length() > 0) )
		str.erase(0, 1);

	// right trim
	while ( isspace(str[str.length() - 1]) && (str.length() > 0) )
		str.erase(str.length() - 1, 1);

	return;
}
//---------------------------------------------------------------------------
int StringList::ReadFromFile (const string& conf_file)
{
	ifstream file(conf_file.c_str());
	if ( file.is_open() )
	{
		string line;
		std::getline(file, line);
		while ( !file.eof() )
		{
			// add this line
			Add(line);

			// keep reading
			std::getline(file, line);
		}
	}

	return Count();
}
//---------------------------------------------------------------------------
int StringList::WriteToFile (const string& filename) const
{
	int count = 0;

	ofstream file(filename.c_str(), ios::out | ios::trunc);
	if ( file.is_open() )
	{
		vector<string>::const_iterator it = m_list.begin();
		for ( ; it != m_list.end(); ++it )
		{
			file << *it << endl;
			++count;
		}
	}

	return count;
}
//---------------------------------------------------------------------------
int StringList::WriteToFile (ofstream& file) const
{
	int count = 0;

	if ( file.is_open() )
	{
		vector<string>::const_iterator it = m_list.begin();
		for ( ; it != m_list.end(); ++it )
		{
			file << *it << endl;
			++count;
		}
	}

	return count;
}
//---------------------------------------------------------------------------
