
#include <iostream>
#include <string>
#include <map>
#include <fstream>
using namespace std;

#include "comm.h"
#include "T3Message.h"

#include "HttpComponent.h"
using namespace arinbe;

//---------------------------------------------------------------------------
bool sendT3Message(const T3Message& IMessage, T3MultiMap& rcvimsgs,
				   const string& attr_name,
                   const string& server_url, int timeout, bool keep_log)
{
	// set to something reasonable
	if ( timeout == 0 )
		timeout = 10;

	string post = "DATA=" + HttpComponent::urlEscape(IMessage.toXML());

	// this is for post
	HttpComponent http(server_url, timeout);
	StringList hdrs;
	HTTPRequest request = http.sendHttpRequest(hdrs, post);

	// this is for get
	//HttpComponent http(server_url + post, timeout);
	//HTTPRequest request = http.sendHttpRequest();

	buildRecvdIMmap(request.message.Text(), rcvimsgs, attr_name);

	if (keep_log)
	{
    	// write a log
        writeLog(post, request, rcvimsgs);
	}

	return !request.error;
}
//---------------------------------------------------------------------------
void buildRecvdIMmap(const string& rcvdstr, T3MultiMap& recvd_messages,
					 const string& attr_name)
{
	//builds the map that dll exports as message set received from server
	recvd_messages.clear();

	vector<string> message_list;
	string msg_beg = "<MESSAGE";
	int len_beg = msg_beg.length();
	string msg_end = "</MESSAGE>";
	int len_end = msg_end.length();

	int pos_beg = rcvdstr.find(msg_beg, 0);
	while ( pos_beg > -1 )
	{
		int pos_end = rcvdstr.find(msg_end, pos_beg + len_beg);
		if ( pos_end > -1 )
		{
			// extract the msg from the string
			string msg = rcvdstr.substr(pos_beg, pos_end - pos_beg + len_end);

			T3Message t3msg("MESSAGE", msg);
			string key = t3msg.getAttribute(attr_name);

			// add this message to the received
			recvd_messages.insert(make_pair(key, t3msg));

			// search for next
			pos_beg = rcvdstr.find(msg_beg, pos_end + len_end);
		}
		else
		{
			// can't find end of message, quit
			pos_beg = -1;
		}
	}

	return;
}
//---------------------------------------------------------------------------
void writeLog (const string& post, const HTTPRequest& request,
			   const T3MultiMap& rec)
{
	ofstream testfile("socket.log", ios::app);
    testfile << "---------- DATA BEING SENT TO SERVER: ----------\n";
    testfile << post.c_str() << endl << endl;
    testfile << "---------- DATA BEING SENT TO SERVER: ----------\n";
    testfile << endl;
    testfile << "---------- RAW DATA RECEIVED FROM SERVER: ----------\n";
    testfile << request.message.Text().c_str() << "\n\n";
    testfile << "------- END OF RAW DATA RECEIVED FROM SERVER -------\n";
    testfile << endl;

    testfile << "Total Message Received = " << rec.size() << endl;

	/*
    testfile << "Begin Received Messages Listing" << endl;
    T3MultiMap::const_iterator i = rec.begin();
    for ( int count = 1; i != rec.end(); ++i, ++count )
    {
    	testfile << "MSG " << count << endl;
        testfile << i->second.toXML() << endl;
    }
	*/

	return;
}
