//---------------------------------------------------------------------------

#ifndef TransThreadH
#define TransThreadH
//---------------------------------------------------------------------------
//#include <Classes.hpp>

#include <vector>
#include <map>

#include "MessagesImp.h"

using namespace std;

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
class TransferThread : public TThread
{
public:
	__fastcall TransferThread(bool CreateSuspended);

	//pointers to collections of data that the thread reads or writes
	vector<Message>* pTempSendBuffer;				//coll of messages to send
	multimap<string, Message>* pTempMessageBuffer;	//coll of unread messages
	multimap<string, Message>* pTempStatusBuffer;	//coll of unread status msgs
	map<string, Message>* pTempUserCollection;		//coll of ON/OFF mssgs (Users)

	String cgi_exe;			//address of server executable to process transfer
	int timeout;
	bool keeplog; 			//passed to comms libraries if comm log must be kept

protected:
	void __fastcall Execute();

private:
	//void __fastcall OnDone(TObject *Sender);	//event is now member of caller
	int result;				//outcome of server communication

};
//---------------------------------------------------------------------------
#endif
