//---------------------------------------------------------------------------

#define impmBFTalker_dll

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

#include <stdio.h>
#include <iostream>
#include <stdlib.h>
#include <fstream>

#include "HTTPclient.h"
#include "impmBFTalker.h"
#include "MessagesImp.h"

//for development testing only
//ofstream testfile("socket.log", ios::app);

//---------------------------------------------------------------------------
#if defined(__WIN32__)			

#include <windows.h>			//DllMain is needed to build a Windows Dll
//---------------------------------------------------------------------------
BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fwdreason, LPVOID lpvReserved)
{
	if (fwdreason == DLL_PROCESS_ATTACH)
	{
		//SendBuf = new DataHTTP;		//object from HTTPclient.dll

		//for development testing only
		//testfile << "Loading impmBFTalker.DLL ...\n" << '\n';

	}

	else if (fwdreason == DLL_PROCESS_DETACH)
	{
		//for development testing only
		//testfile << "\nUnloading impmBFTalker.DLL Now" << endl;

		//delete SendBuf;
		//exit(EXIT_SUCCESS);		//apparently needs exit() to clean up junk
	}

	return true;
}
//---------------------------------------------------------------------------

#elif defined(__linux__)

//here for template reasons, but this dll's code cannot be used for
//linux in its current version because it uses Borland VCL
#endif

//---------------------------------------------------------------------------
//declarations of any dll helper functions and dll vars
//(private to dll - don't put in header because header is shared by caller)

void buildRecvdIMmap(string& rcvdstr);
multimap<string, InstantMessage> recvd_messages;

//---------------------------------------------------------------------------

int sendIMessage(string server_url, int timeout, bool keep_log)
{
	//caller should fill in IMessage, so build Message object from that data:

	//for this to work, create SendBuf object for each call, but deleting
	//at end causes protection error -- yet it does not seem to leak memory,
	//so somehow dll deallocates this memory -- ok, but watch for any trouble
	SendBuf = new DataHTTP;

	Message messg_out(IMessage->message_id.c_str(), IMessage->from.c_str(),
					  IMessage->to.c_str(), IMessage->status.c_str(),
					  IMessage->subject.c_str(), IMessage->message_text.c_str());
	messg_out.location = IMessage->location.c_str();
	messg_out.time = IMessage->gmt_time.c_str();

	//convert message to xml (modify this part if other format is used)
	String xml_out = messg_out.toXML();
	xml_out.Insert("DATA=", 1);	//add "DATA=" to beginning of message string

	//use HTTPclient library to communicate with server
	SendBuf->server_URL = server_url;
	SendBuf->timeout = timeout;
	SendBuf->keep_log = keep_log;

	SendBuf->data_to_send = xml_out.c_str();

	int result = postData(true);

	if (keep_log)
	{
		ofstream testfile("socket.log", ios::app);

		testfile << endl;
		testfile << "---------- RAW DATA RECEIVED FROM SERVER: ----------\n";
		testfile << RecvBuf->data_received << "\n\n";
		testfile << "\n------- END OF RAW DATA RECEIVED FROM SERVER -------\n" << endl;
	}

	buildRecvdIMmap(RecvBuf->data_received);

	RecvdIMessages = &recvd_messages;

	//delete SendBuf;		//don't deallocate mem -- see note above
	return result;
}
//---------------------------------------------------------------------------

void buildRecvdIMmap(string& rcvdstr)
{
	//builds the map that dll exports as message set received from server

	recvd_messages.clear();

	//later fix to do a more direct way to stuff the items into the map
	//but for now, the following code already existed so I may as well use it

	TStringList* message_set = new TStringList();
	message_set->Text = rcvdstr.c_str();

	//scan list of messages (lines), and remove junk ones
	for (int i = 0; i < message_set->Count; i++)
	{
		if (!message_set->Strings[i].Pos("MESSAGE"))
		{
			message_set->Delete(i--);	//lower i because next one moves up
		}
	}

	if (message_set->Count == 0)		//if all lines were junk
	{           						//there's nothing to do -- abort
		delete message_set;
		return;
	}

	//now copy to map
	for (int i = 0; i < message_set->Count; i++)
	{
		Message new_message(message_set->Strings[i]);
		InstantMessage imessage;

		imessage.message_id = new_message.message_id.c_str();
		imessage.from = new_message.from.c_str();
		imessage.location = new_message.location.c_str();
		imessage.gmt_time = new_message.time.c_str();
		imessage.to = new_message.to.c_str();
		imessage.status = new_message.status.c_str();
		imessage.subject = new_message.thread.c_str();
		imessage.message_text = new_message.message_text.c_str();

		recvd_messages.insert(make_pair(imessage.from, imessage));
	}

	delete message_set;
}
//---------------------------------------------------------------------------
