//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include <iostream>
#include <string>
using namespace std;

// include the winsock dll
#include <winsock.h>

#include "t3client.h"

USERES("t3client.res");
USEFORM("MainFrm.cpp", MainForm);
USEUNIT("TimersImp.cpp");
USEFORM("NewTimr.cpp", NewTimer);
USEUNIT("HttpComm\T3Message.cpp");
USEFORM("MessageActionFrm.cpp", MessageActionForm);
USEFORM("OptionsFrm.cpp", OptionsForm);
USEUNIT("TransThread.cpp");
USEUNIT("IniOptions.cpp");
USEUNIT("MessageMgr.cpp");
USEUNIT("HttpComm\stringlist.cpp");
USEUNIT("HttpComm\HttpComponent.cpp");
USEUNIT("HttpComm\comm.cpp");
USEUNIT("HttpComm\Socket.cpp");
USEFORM("UtilityDialg.cpp", UtilityDialog);
USEFORM("InTransitFrm.cpp", InTransitForm);
USEUNIT("TimerMgr.cpp");
USEUNIT("TimerFcns.cpp");
//---------------------------------------------------------------------------
WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int)
{
	DeleteFile("socket.log");

	if ( !FileExists(T3IniFilename().c_str()) )
    {
    	ShowMessage("Unable to read Ini File.");
        return 0;
    }

	// check for valid socket DLL
	WSADATA wsaData;
	if ( !WSAStartup(0x0101, &wsaData) )
	{
		try
		{
			Application->Initialize();
			Application->CreateForm(__classid(TMainForm), &MainForm);
		Application->CreateForm(__classid(TUtilityDialog), &UtilityDialog);
		Application->CreateForm(__classid(TInTransitForm), &InTransitForm);
		Application->Run();
		}
		catch (Exception &exception)
		{
			Application->ShowException(&exception);
		}

		// clean up the socket
		WSACleanup();
	}
	else
	{
    	WSACleanup();
		::MessageBox(NULL, "T3 - Error",
					 "This application requires Winsock v1.1 or above.",
					 MB_OK | MB_ICONERROR);
	}

	return 0;
}
//---------------------------------------------------------------------------
string T3Filename ()
{
	return "t3client";
}
//---------------------------------------------------------------------------
string T3Pathname ()
{
	//add HOME path to filename if it exists
	string path;
	if (getenv("HOME") )
	{
		path = string(getenv("HOME")) + "\\";
	}
	else
	{
		path = ".\\";
	}

	return path;
}
//---------------------------------------------------------------------------
string T3IniFilename ()
{
	return T3Pathname() + T3Filename() + ".ini";
}
//---------------------------------------------------------------------------
string T3HisFilename ()
{
	return T3Pathname() + T3Filename() + ".his";
}
//---------------------------------------------------------------------------
