//---------------------------------------------------------------------------

#ifndef impmBFTalkerH
#define impmBFTalkerH
//---------------------------------------------------------------------------


#include <string>
#include <map>

using namespace std;

const int TIMEOUT_DEFAULT = 2;	//waiting-for-server-response timeout in secs

//---------------------------------------------------------------------------

//caller interface

struct InstantMessage
{
	InstantMessage()
	{
	};

	string message_id;
	string from;
	string address;
	string location;
	string gmt_time;
	string to;
	string status;
	string subject;
	string message_text;
};


#if defined(__WIN32__)		//exposed functions in dll for Win32 Windows
//---------------------------------------------------------------------------
	//export/import adjustment for including this header in dll or calling app
	#ifdef impmBFTalker_dll
		#define PUBDLL __declspec(dllexport)
		PUBDLL const InstantMessage* IMessage;	//dll cannot modify send messg
		PUBDLL multimap<string, InstantMessage>* RecvdIMessages;
	#else
		#define PUBDLL __declspec(dllimport)
		PUBDLL InstantMessage* IMessage;
		PUBDLL const multimap<string, InstantMessage>* RecvdIMessages;
	#endif

	extern "C" PUBDLL int sendIMessage(string server_url,
					int timeout = TIMEOUT_DEFAULT, bool keep_log = false);

//---------------------------------------------------------------------------
#endif

//---------------------------------------------------------------------------
#endif

