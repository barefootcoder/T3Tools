//---------------------------------------------------------------------------
#ifndef IniOptionsH
#define IniOptionsH
//---------------------------------------------------------------------------

#include <map>
#include <string>


using namespace std;

//---------------------------------------------------------------------------

//IniOptions manages user preferences for the client app.  It can read/write
//the options in an ini file (currently only supports name=value format)

class IniOptions
{
public:
	//ctor, dtor
	IniOptions (const string& ini_filename);
	~IniOptions ();

	//action methods
	void setValue (const string& name, const string& value, bool ini = true);
	void setValueInt (const string& name, const int int_val, bool ini = true);
						//bool ini decides if this value will be persistent
	string getValue (const string& name, string default_val = "") const;
	int getValueInt (const string& name, int default_val = 0) const;

private:
	//data
	TStringList* ini_values;		//name=value pairs
	TStringList* tmp_values;		//name=value pairs never saved to ini file
	//note: later use these maps for values, but for now use above StringLists
	map<string, string> t_ini_values;	//name=value pairs (remove "t_" later)
	map<string, string> t_tmp_values;	//name=value pairs never saved to ini file

	string inifilename;

};
//---------------------------------------------------------------------------
namespace user_options
{
								//pointer to object that multiple modules in an
	extern IniOptions* IniOpt;	//app can share.  It governs ini files and
								//other user settings, persistent or not.  The 
								//main GUI window or main() must create and
								//destroy this object.
}
//---------------------------------------------------------------------------
#endif
 