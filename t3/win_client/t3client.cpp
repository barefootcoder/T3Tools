//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop
USERES("t3client.res");
USEFORM("MainFrm.cpp", MainForm);
USEUNIT("TimersImp.cpp");
USEFORM("NewTimr.cpp", NewTimer);
USEFORM("TimerActionFrm.cpp", TimerActionForm);
USEUNIT("MessagesImp.cpp");
USEFORM("MessageActionFrm.cpp", MessageActionForm);
USEFORM("OptionsFrm.cpp", OptionsForm);
USEFORM("TestFrm.cpp", TestForm);
USE("t3client.todo", ToDo);
USEUNIT("TransThread.cpp");
USEUNIT("IniOptions.cpp");
USEUNIT("MessageMgr.cpp");
USEFORM("UtilityDialg.cpp", UtilityDialog);
USEFORM("InTransitFrm.cpp", InTransitForm);
//---------------------------------------------------------------------------
WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int)
{
	try
	{
		Application->Initialize();
		Application->CreateForm(__classid(TMainForm), &MainForm);
		Application->CreateForm(__classid(TNewTimer), &NewTimer);
		Application->CreateForm(__classid(TTimerActionForm), &TimerActionForm);
		Application->CreateForm(__classid(TOptionsForm), &OptionsForm);
		Application->CreateForm(__classid(TTestForm), &TestForm);
		Application->CreateForm(__classid(TUtilityDialog), &UtilityDialog);
		Application->CreateForm(__classid(TInTransitForm), &InTransitForm);
		Application->Run();
	}
	catch (Exception &exception)
	{
		Application->ShowException(&exception);
	}
	return 0;
}
//---------------------------------------------------------------------------
