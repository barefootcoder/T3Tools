//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "IniOptions.h"

//---------------------------------------------------------------------------
#pragma package(smart_init)

//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
//this constructor associates an ini file with the option values

IniOptions::IniOptions (const string& ini_filename)
{
	//TODO: Add your source code here
}
//---------------------------------------------------------------------------

string IniOptions::getValue (const string& name) const
{
	return ini_settings->Values[name.c_str()];
}
//---------------------------------------------------------------------------

void IniOptions::setValue (const string& name, const string& value)
{
	ini_settings->Values[name.c_str()] = value.c_str();
}
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//	METHODS TO MANAGE INI FILE
//---------------------------------------------------------------------------

void IniOptions::readIniFile ()
{
	//reads ini file and sets values accordingly

	//add HOME path to filename if it exists
	if (getenv(HOME.c_str()))
	{
		ini_filename = String(getenv(HOME.c_str())) + '\\' + INIFILENAME;
		hist_filename = String(getenv(HOME.c_str())) + '\\' + HISTFILENAME;
	}
	else
	{
		ini_filename = INIFILENAME;
		hist_filename = HISTFILENAME;
	}

	try
	{
		ini_settings->LoadFromFile(ini_filename);
	}
	catch(...)
	{
		;
	}

	//General Options, other forms positions, etc. are done in respective
	//forms (MessageActionForm, OptionsForm) -- they must exist first anyway

	//recover the contact list order
	String users = ini_settings->Values["contact_order"];
	int pos;
	Message temp_mess;
	do			//add to UserCollection because control can't be painted yet
	{
		pos = users.Pos(",");
		String next = pos ? users.SubString(1, pos - 1) : users;
		users.Delete(1, pos);
		temp_mess.from = next;
		UserCollection[temp_mess.from] = temp_mess;		//reorders it, oh well
	}
	while (pos);

	//set main window size and position from ini file
	if (ini_settings->Values["mainform_left"] != "")	//otherwise, it's 1st time
	{
		MainForm->Position = poDesigned;
		MainForm->Left = ini_settings->Values["mainform_left"].ToIntDef(MainForm->Left);
		MainForm->Top = ini_settings->Values["mainform_top"].ToIntDef(MainForm->Top);
		MainForm->Width = ini_settings->Values["mainform_width"].ToIntDef(MainForm->Width);
		MainForm->Height = ini_settings->Values["mainform_height"].ToIntDef(MainForm->Height);
		Contacts->Width = ini_settings->Values["talker_width"].ToIntDef(Contacts->Width);
		timernames_width = ini_settings->Values["timernames_width"].ToIntDef(50);
		hidden_timer_panes[0] = ini_settings->Values["hide_timer_names"].ToIntDef(0);
		hidden_timer_panes[1] = ini_settings->Values["hide_timer_digits"].ToIntDef(0);
		hidden_timer_panes[2] = ini_settings->Values["hide_timer_icons"].ToIntDef(0);
	}

}
//---------------------------------------------------------------------------

void IniOptions::writeIniFile ()
{
	//save current user list order
	String user_list;
	for (int i = 0; i < Contacts->Items->Count; i++)
    {
		user_list += Contacts->Items->Strings[i];	//concat current contacts
		if (Contacts->Items->Count > i + 1)
			user_list += ',';
	}
	ini_settings->Values["contact_order"] = user_list;

	//save current size and position of main window
	ini_settings->Values["mainform_left"] = MainForm->Left;
	ini_settings->Values["mainform_top"] = MainForm->Top;
	ini_settings->Values["mainform_width"] = MainForm->Width;
	ini_settings->Values["mainform_height"] = MainForm->Height;
	ini_settings->Values["talker_width"] = Contacts->Width;
	ini_settings->Values["timernames_width"] = timernames_width;
	ini_settings->Values["hide_timer_names"] = (int) hidden_timer_panes[0];
	ini_settings->Values["hide_timer_digits"] = (int) hidden_timer_panes[1];
	ini_settings->Values["hide_timer_icons"] = (int) hidden_timer_panes[2];

	//write to file, updating current user options as well
	ini_settings->SaveToFile(ini_filename);
}
//---------------------------------------------------------------------------


