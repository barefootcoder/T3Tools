//---------------------------------------------------------------------------

#define httpclient_dll

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#include <stdio.h>
#include <iostream>
#include <stdlib.h>

#include "HTTPclient.h"
#include "httpcomm.h"

//for development testing only
//#include <fstream>
//ofstream testfile("socket.log", ios::app);
				

//---------------------------------------------------------------------------
#if defined(__WIN32__)			

#include <windows.h>			//DllMain is needed to build a Windows Dll
//---------------------------------------------------------------------------
BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fwdreason, LPVOID lpvReserved)
{
	if (fwdreason == DLL_PROCESS_ATTACH)
	{
		RecvBuf = new DataHTTP;

		//for development testing only
		//testfile << "Loading DLL...\n" << '\n';

	}

	else if (fwdreason == DLL_PROCESS_DETACH)
	{
		//for development testing only
		//testfile << "\nUnloading Dll Now\n\n" << endl;

		//delete RecvBuf;			//apparently dll deletes this automatically
		//exit(EXIT_SUCCESS);		//without above delete, it's no longer needed
	}

	return true;
}
//---------------------------------------------------------------------------

#elif defined(__linux__)

//will need to somehow create and delete RecvdBuf in here
#endif

//---------------------------------------------------------------------------
//declarations of any dll helper functions
//(private to dll - don't put in header because header is shared by caller)

void prepareHeaders(HTTPComm& http);

//---------------------------------------------------------------------------

int getData(bool simple)
{
	HTTPComm http;

	http.server_port = SendBuf->server_port;
	http.time_out_secs = SendBuf->timeout;
	RecvBuf->data_to_send.clear();		//not used -- http get has no body

	prepareHeaders(http);

	RecvBuf->data_received.clear();			//ready it for next set of data

	int result;
	result = http.doGet(RecvBuf->data_received, SendBuf->server_URL,
							simple, SendBuf->keep_log);

	//separate returned data into headers and body
	http.splitHeaders(RecvBuf->data_received, RecvBuf->server_headers_str,
							RecvBuf->server_headers);

	return result;
}
//---------------------------------------------------------------------------

int postData(bool cgi_form_data)
{
	HTTPComm http;

	http.server_port = SendBuf->server_port;
	http.time_out_secs = SendBuf->timeout;
	http.client_body = SendBuf->data_to_send;

	prepareHeaders(http);

	if (cgi_form_data)
	{
		http.urlEncode(http.client_body, false);
		RecvBuf->data_to_send = http.client_body;	//so caller can inspect it
		if (http.client_headers.empty())
		{
			http.client_headers = "Content-Type: application/x-www-form-urlencoded";
			http.client_headers += HTTP_NEWLINE;
		}
	}
	else
	{
		RecvBuf->data_to_send.clear();		//since can't copy http.client_body
		if (http.client_headers.empty())
		{
			http.client_headers = "Content-Type: application/octet-stream";
			http.client_headers += HTTP_NEWLINE;
		}
	}

	//next line works above for cgi_form_data but here causes an exception
	//not a big deal since we can do without, but may want to check later
	//RecvBuf->data_to_send = http.client_body;	//so caller can inspect it

	RecvBuf->data_received.clear();			//ready it for next set of data

	int result;
	result = http.doPost(RecvBuf->data_received, SendBuf->server_URL,
							SendBuf->keep_log);

	//separate returned data into headers and body
	http.splitHeaders(RecvBuf->data_received, RecvBuf->server_headers_str,
							RecvBuf->server_headers);

	return result;
}
//---------------------------------------------------------------------------

void prepareHeaders(HTTPComm& http)
{
	RecvBuf->client_headers_str = SendBuf->client_headers_str;
	RecvBuf->client_headers = SendBuf->client_headers;

	//scatter the headers from string, if any, to our local vector
	//(this also cleans string, and fills it up if empty to use vector headers)
	http.strToVector(RecvBuf->client_headers_str, RecvBuf->client_headers);

	http.client_headers = RecvBuf->client_headers_str;

}
//---------------------------------------------------------------------------
