//---------------------------------------------------------------------------

#ifndef httpcommH
#define httpcommH
//---------------------------------------------------------------------------

#include <string>
#include <vector>

#include "basesocket.h"

using namespace std;

const string HTTP_VERSION = "HTTP/1.0";
//const char* const HTTP_NEWLINE = "\r\n";
const string HTTP_NEWLINE = "\r\n";

//---------------------------------------------------------------------------

class HTTPComm : public BaseSocket
{
  public:
	//action methods
	int doGet(string& receive_buffer, string URL, bool simple, bool keep_log);
	int doPost(string& receive_buffer, string URL, bool keep_log);

	//data to be passed by caller in required format as indicated below
	string client_headers;	//ea header line terminated by CRLF
	string client_body;		//any valid basic_string

	//helper functions used by caller to manage and format HTTP headers and body
	void strToVector(string& headers, vector<string>& vheaders);
	void vectorToStr(vector<string>& vheaders, string& headers);
	void splitHeaders(string& all_data, string& headers_str,
											vector<string>& headers);
	void urlEncode(string& whatstr, bool url_string = false);

  private:
	void parseURL(string URL);
	string server_URI;
	void encodeStr(string& whatstr);	//helper function for urlEncode


};


//---------------------------------------------------------------------------
#endif
 