//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include <iostream>
#include <string>
using namespace std;

// include the winsock dll
#include <winsock.h>

USERES("t3client.res");
USEFORM("MainFrm.cpp", MainForm);
USEUNIT("TimersImp.cpp");
USEFORM("NewTimr.cpp", NewTimer);
USEFORM("TimerActionFrm.cpp", TimerActionForm);
USEUNIT("HttpComm\T3Message.cpp");
USEFORM("MessageActionFrm.cpp", MessageActionForm);
USEFORM("OptionsFrm.cpp", OptionsForm);
USEFORM("TestFrm.cpp", TestForm);
USEUNIT("TransThread.cpp");
USEUNIT("IniOptions.cpp");
USEUNIT("MessageMgr.cpp");
USEUNIT("HttpComm\stringlist.cpp");
USEUNIT("HttpComm\HttpComponent.cpp");
USEUNIT("HttpComm\comm.cpp");
USEUNIT("HttpComm\Socket.cpp");
USEFORM("UtilityDialg.cpp", UtilityDialog);
USEFORM("InTransitFrm.cpp", InTransitForm);
//---------------------------------------------------------------------------
WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int)
{
	DeleteFile("socket.log");

    string basename = Application->ExeName.c_str();
    for (int i = 0; i < (int) basename.length(); ++i )
		basename[i] = tolower(basename[i]);
	basename.erase(basename.find(".exe"));

	// check for existance of the inifile
    string inifile = basename + ".ini";
	if ( !FileExists(inifile.c_str()) )
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
			Application->CreateForm(__classid(TTimerActionForm), &TimerActionForm);
			Application->CreateForm(__classid(TUtilityDialog), &UtilityDialog);
			Application->CreateForm(__classid(TInTransitForm), &InTransitForm);
			Application->CreateForm(__classid(TTestForm), &TestForm);
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
