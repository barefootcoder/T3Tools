//---------------------------------------------------------------------------

#ifndef httpclientH
#define httpclientH
//---------------------------------------------------------------------------


#include <string>
#include <vector>

using namespace std;

const char* const DEFAULT_URL = "127.0.0.1";
const short DEFAULT_PORT = 80;
const int DEFAULT_TIMEOUT = 2;		//waiting-for-response timeout in seconds

//---------------------------------------------------------------------------

//caller interface

struct DataHTTP
{
	DataHTTP()
	{
		server_URL = DEFAULT_URL;
		server_port = DEFAULT_PORT;
		timeout = DEFAULT_TIMEOUT;
		keep_log = false;
	};

	string server_URL;
	short server_port;
	string client_headers_str;
	string server_headers_str;
	vector<string> client_headers;
	vector<string> server_headers;
	string data_to_send;
	string data_received;
	int timeout;
	bool keep_log;
};


#if defined(__WIN32__)		//exposed functions in dll for Win32 Windows
//---------------------------------------------------------------------------
	//export/import adjustment for including this header in dll or calling app
	#ifdef httpclient_dll
		#define LINKDLL __declspec(dllexport)
		LINKDLL const DataHTTP* SendBuf;	//dll cannot modify Send buffer
		LINKDLL DataHTTP* RecvBuf;
	#else
		#define LINKDLL __declspec(dllimport)
		LINKDLL DataHTTP* SendBuf;
		LINKDLL const DataHTTP* RecvBuf;	//caller cannot modify Recv buffer
	#endif

	extern "C" LINKDLL int getData(bool simple = false);
	extern "C" LINKDLL int postData(bool cgi_form_data = false);
//---------------------------------------------------------------------------
#endif

//---------------------------------------------------------------------------
#endif

