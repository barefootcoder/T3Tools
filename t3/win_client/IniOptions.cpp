//---------------------------------------------------------------------------
#include <vcl.h>

#include <sstream>


#include "IniOptions.h"

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//---------------------------------------------------------------------------

IniOptions::IniOptions (const string& ini_filename)
{
	//this constructor associates an ini file with the persistent option values

	ini_values = new TStringList;
	tmp_values = new TStringList;

	inifilename = ini_filename;         
	ini_values->LoadFromFile(inifilename.c_str());
										
}
//---------------------------------------------------------------------------

IniOptions::~IniOptions ()
{
	//on destroy, save the persistent values

	ini_values->SaveToFile(inifilename.c_str());

	delete ini_values;
	delete tmp_values;
}
//---------------------------------------------------------------------------

string IniOptions::getValue (const string& name, string default_val) const
{
	//if getValue() does not find the value in ini_values, it searches
	//tmp_values, thus freeing the caller from having to decide where to look

	string value("");

	value = ini_values->Values[name.c_str()].c_str();

	if (value == "")
		value = tmp_values->Values[name.c_str()].c_str();

	if (value == "")
		return default_val;
	else
		return value;
}
//---------------------------------------------------------------------------

int IniOptions::getValueInt (const string& name, int default_val) const
{
	//equivalent to getValue() but returns an int

	string value = getValue(name);
	int int_val;

	if (istringstream(value) >> int_val)
		return int_val;
	else
		return default_val;
}
//---------------------------------------------------------------------------

void IniOptions::setValue (const string& name, const string& value, bool ini)
{
	if (ini)
		ini_values->Values[name.c_str()] = value.c_str();
	else
		tmp_values->Values[name.c_str()] = value.c_str();
}
//---------------------------------------------------------------------------

void IniOptions::setValueInt (const string& name, const int int_val, bool ini)
{
	//equivalent to setValue() but accepts an int for the value
	//(could just overload of course, but that's too criptic)

	ostringstream outstrm;
	outstrm << int_val;

	setValue(name, outstrm.str(), ini);
}
//---------------------------------------------------------------------------
