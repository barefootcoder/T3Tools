//---------------------------------------------------------------------------
#ifndef MessageMgrH
#define MessageMgrH
//---------------------------------------------------------------------------
#include <Classes.hpp>	//MessagesImp.h still uses String, so this is still
						//needed -- once messages has no VCL, this can be deleted

#include <map>
#include <vector>

#include "MessagesImp.h"


using namespace std;

//---------------------------------------------------------------------------

class MessageMgr
{
 public:
	//ctor
	MessageMgr (const string& history_filename);

	//key methods
	void initTransfer (const Message& what_messg);	//key i/f to message senders
	void confirmDelivery (const Message& what_messg);	//confirm rcvd-message
	void confirmMessages ();	//process confirmations received from others
	void resendMessages ();		//resends any messages that remain unconfirmed

	//auxiliary methods
	void addToUnconfirmed ();	//copies all NORMAL from SendBuffer to UnconfCollection
	void saveUnconfirmed ();

	//key data collections (see also private temp versions)
	multimap<string, Message> MessageBuffer;	//unread messages (rcvd)
	multimap<string, Message> StatusBuffer;		//unread status messages (rcvd)
	map<string, Message> UserCollection;		//ON/OFF mssgs = Users (rcvd)
	map<string, Message> UnconfCollection;		//unconfirmed messages
	vector<Message> SendBuffer;					//accumulates to-send messages

	vector<string> user_list;	//user names list - clients maintain its order
	vector<string> hist_buffer;                 //memory copy of history file

	//status vars
	bool transfer_active;				//public status of thread_active
	bool thread_finished;				//set when thread terminates
	//bool server_ack;					//set when server returns status="ACK"

 private:
	//key methods
	void doTransfer ();
	void addToHistory (const Message& what_messg);

	//auxiliary methods
	void loadLocalHistory ();
	void loadUnconfirmed ();		//repopulates UnconfCollection from file

	//events
	void __fastcall onThreadDone (TObject *Sender);

	//Temp versions of key data collections are for use by child thread
	//without interfering with the main (public) collections
	multimap<string, Message> TempMessageBuffer;
	multimap<string, Message> TempStatusBuffer;
	map<string, Message> TempUserCollection;
	vector<Message> TempSendBuffer;

	//private data
	bool thread_active;
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
 