//---------------------------------------------------------------------------
#ifndef __timer_fcns_h__ 
#define __timer_fcns_h__ 


#ifdef __WIN32__

	extern "C"
	{
		// ping timer callback
		VOID CALLBACK TimerMgrProc (HWND hwnd, UINT uMsg,
									UINT idEvent, DWORD dwTime);

		DWORD WINAPI TimerThreadFunc ( LPVOID lpParam );
	}

#endif

#endif
