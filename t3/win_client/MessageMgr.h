//---------------------------------------------------------------------------
#ifndef MessageMgrH
#define MessageMgrH
//---------------------------------------------------------------------------

#include <map>
#include <vector>
using namespace std;

#include "T3Message.h"

//---------------------------------------------------------------------------

class MessageMgr
{
 public:
	//ctor
	MessageMgr (const string& history_filename);

	//key methods
	void initTransfer (const T3Message& what_messg);	//key i/f to message senders
	void confirmDelivery (const T3Message& what_messg);	//confirm rcvd-message
	void confirmMessages ();	//process confirmations received from others
	void resendMessages ();		//resends any messages that remain unconfirmed

	//auxiliary methods
	void addToUnconfirmed ();	//copies all NORMAL from SendBuffer to UnconfCollection
	void saveUnconfirmed ();

	//key data collections (see also private temp versions)
	multimap<string, T3Message> MessageBuffer;	//unread messages (rcvd)
	multimap<string, T3Message> StatusBuffer;		//unread status messages (rcvd)
	map<string, T3Message> UserCollection;		//ON/OFF mssgs = Users (rcvd)
	map<string, T3Message> UnconfCollection;		//unconfirmed messages
	vector<T3Message> SendBuffer;					//accumulates to-send messages

	vector<string> user_list;	//user names list - clients maintain its order
	vector<string> hist_buffer;                 //memory copy of history file

	//status vars
	bool transfer_active;				//public status of thread_active
	bool thread_finished;				//set when thread terminates
	//bool server_ack;					//set when server returns status="ACK"

 private:
	//key methods
	void doTransfer ();
	void addToHistory (const T3Message& what_messg);

	//auxiliary methods
	void loadLocalHistory ();
	void loadUnconfirmed ();		//repopulates UnconfCollection from file

	//events
	void __fastcall onThreadDone (TObject *Sender);

	//Temp versions of key data collections are for use by child thread
	//without interfering with the main (public) collections
	multimap<string, T3Message> TempMessageBuffer;
	multimap<string, T3Message> TempStatusBuffer;
	map<string, T3Message> TempUserCollection;
	vector<T3Message> TempSendBuffer;

	//private data
	bool thread_active;
	bool m_should_resend_now;
	string hist_filename;			//full-path name of history file
	string unconf_filename;			//obtained from hist_filename

};

//---------------------------------------------------------------------------
namespace message_pump
{
								//pointer to object that multiple modules in an
	extern MessageMgr* MessagePump;	//app can share.  It governs message sending
								//and receiving and message collections. Also
								//user lists and history files, which are really
								//a special case of message collections.
								//The main GUI window or main() must create and
								//destroy this object.
}
//---------------------------------------------------------------------------
#endif
 