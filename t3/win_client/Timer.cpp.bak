//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop
USERES("Timer.res");
USEFORM("MainFrm.cpp", MainForm);
USEUNIT("TimersImp.cpp");
USEFORM("NewTimr.cpp", NewTimer);
USEFORM("TimerActionFrm.cpp", TimerActionForm);
USEUNIT("MessagesImp.cpp");
USEFORM("MessageActionFrm.cpp", MessageActionForm);
USEFORM("OptionsFrm.cpp", OptionsForm);
USEFORM("TestFrm.cpp", TestForm);
USE("Timer.todo", ToDo);
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
		Application->Run();
	}
	catch (Exception &exception)
	{
		Application->ShowException(&exception);
	}
	return 0;
}
//---------------------------------------------------------------------------
