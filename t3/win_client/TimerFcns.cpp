//---------------------------------------------------------------------------
#include <iostream>
#include <string>
using namespace std;

#include "TimerMgr.h"
using namespace barefoot;

#include "TimerFcns.h"
#include "comm.h"

#ifdef __WIN32__

	VOID CALLBACK TimerMgrProc (HWND hwnd, UINT uMsg, UINT event, DWORD time)
	{
		// DEBUG
		//::MessageBox(NULL, "In Timer Callback", "DEBUG", MB_OK); 

		theTimerMgr().pingServerInThread();

		// DEBUG
		//::MessageBox(NULL, "Out Timer Callback", "DEBUG", MB_OK); 

		return;
	}

	DWORD WINAPI TimerThreadFunc (LPVOID junk)
	{
		// DEBUG
		//::MessageBox(NULL, "In Timer Thread", "DEBUG", MB_OK); 

		theTimerMgr().pingServer();

		// DEBUG
		//::MessageBox(NULL, "Out Timer Thread", "DEBUG", MB_OK); 

		// get the flock out of this thread
		ExitThread(0);
		return 0;
	}

#endif

//------------------------------------------------------------------------------
