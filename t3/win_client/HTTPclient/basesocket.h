//---------------------------------------------------------------------------

#ifndef basesocketH
#define basesocketH
//---------------------------------------------------------------------------

#include <string>

using namespace std;


const short SERVER_PORT = 80;		//default server port
//const char* const SERVER_ADDR = "127.0.0.1";	//default server address
const string SERVER_ADDR = "127.0.0.1";	//default server address
const int TIME_OUT_SECS = 2;		//default blocking timeout in seconds
const int RECV_BUF_SIZE = 128;		//size of client receive buffer

const int SUCCESS_LEVEL = 200;		//for next const's, values at or above this
									//are for Success and below are for Failure
const int ERR_NODLL = 100;
const int ERR_NOSOCKET = 110;
const int ERR_NOSERVERNAME = 120;
const int ERR_NOSERVERIP = 130;
const int ERR_NOCONNECT = 140;
const int ERR_NOSEND = 150;
const int ERR_NORESPOND = 160;
const int ERR_NORCVDATA = 170;
const int GOOD_DLL = 200;
const int GOOD_SOCKET = 210;
const int GOOD_IP = 220;
const int GOOD_CONNECT = 230;
const int GOOD_SEND = 240;
const int GOOD_RESPOND = 250;
const int GOOD_RCVDATA = 260;
const int GOOD_CLOSESCKT = 270;
const int SHOW_DATA_TO_SEND = 300;


//---------------------------------------------------------------------------

class BaseSocket
{
  public:
	//ctor
	BaseSocket();

	//key properties
	short server_port;
	int time_out_secs;

  protected:
	//main workhorse - derived classes should wrap doTransfer() with a public
	//function that knows high-level protocol (such as http)
	int doTransfer(string data_to_send, string& data_received, bool keep_log) const;
			//note: don't change data_to_send into a reference or const

	//key properties
	string server_addr;		//derived classes should extract this from a URL

  private:
	void writeLog(int status, string message = "") const;

};

//---------------------------------------------------------------------------
#endif
