//---------------------------------------------------------------------------

#ifndef TransThreadH
#define TransThreadH
//---------------------------------------------------------------------------
//#include <Classes.hpp>

#include <vector>
#include <map>
#include <string>
using namespace std;

#include "T3Message.h"

//---------------------------------------------------------------------------
class TransferThread : public TThread
{
public:
	__fastcall TransferThread(bool CreateSuspended);

	//pointers to collections of data that the thread reads or writes
	vector<T3Message>* pTempSendBuffer;				//coll of messages to send
	multimap<string, T3Message>* pTempMessageBuffer;	//coll of unread messages
	multimap<string, T3Message>* pTempStatusBuffer;	//coll of unread status msgs
	map<string, T3Message>* pTempUserCollection;		//coll of ON/OFF mssgs (Users)

	string cgi_exe;			//address of server executable to process transfer
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
