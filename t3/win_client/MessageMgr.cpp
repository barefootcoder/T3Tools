//---------------------------------------------------------------------------
#include <vcl.h>	//Builder IDE development only -- used for ShowMessage()
#include <fstream>
#include <sstream>

#include "MessageMgr.h"
#include "TransThread.h"
#include "IniOptions.h"


using namespace user_options;

//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

MessageMgr::MessageMgr (const string& history_filename)
{
	hist_filename = history_filename;

	loadLocalHistory();			//load local history file into history buffer
	loadUnconfirmed();			//recharge UnconfCollection from persistent store

	//initialize user collections and order using names stored in ini
	String users = IniOpt->getValue("contact_order").c_str();
	int pos;
	Message temp_mess;
	do
	{
		pos = users.Pos(",");
		String next = pos ? users.SubString(1, pos - 1) : users;
		users.Delete(1, pos);
		temp_mess.from = next;
		user_list.push_back(temp_mess.from.c_str());			//keeps order
		UserCollection[temp_mess.from.c_str()] = temp_mess;		//reorders
	}
	while (pos);


	thread_active = false;
	thread_finished = false;

}
//---------------------------------------------------------------------------

void MessageMgr::initTransfer (const Message& what_messg)
{
	//MessageMgr clients call this function when they want to send any message.
	//it calls doTransfer() to start a communication thread -- if the thread is
	//busy, the message remains in send buffer and is processed on next call.
	//(presently only one communication thread at a time is supported because
	// the communication dll used by the thread always uses the same data space)

	SendBuffer.push_back(what_messg);
                          
	addToHistory(what_messg);

	if (thread_active)
		return;

	doTransfer();
}
//---------------------------------------------------------------------------

void MessageMgr::doTransfer ()
{
	//activate a communication thread

	TransferThread *Transfer = new TransferThread(true);

	thread_active = true;				//onThreadDone() will set to false
	transfer_active = thread_active;
	Transfer->OnTerminate = onThreadDone;
	Transfer->cgi_exe = IniOpt->getValue("server_url").c_str();
	Transfer->keeplog = (IniOpt->getValue("test_mode") == "1");
	Transfer->timeout = IniOpt->getValueInt("communication_timeout", 10);

	//empty what's accumulated in SendBuffer up to this point into Temp version
	TempSendBuffer.insert(TempSendBuffer.end(), SendBuffer.begin(),
												SendBuffer.end());

	//b4 clearing send buffer, copy each NORMAL message to Unconfirmed collection
	addToUnconfirmed();
	/*
	vector<Message>::const_iterator it;
	for (it = SendBuffer.begin(); it != SendBuffer.end(); it++)
	{
		if (it->status == "NORMAL")
			UnconfCollection.insert(make_pair(it->message_id.c_str(), *it));
			//note: it's not added if it is already there
	}
	*/
	SendBuffer.clear();
	saveUnconfirmed();	//to keep latest updates of UnconfCollection persistent

	TempUserCollection.clear(); 	//prepare to receive updated user set
	TempMessageBuffer.clear();		//and any new messages
	TempStatusBuffer.clear();

	//tell the thread where the data containers are
	Transfer->pTempSendBuffer = &TempSendBuffer;
	Transfer->pTempMessageBuffer = &TempMessageBuffer;
	Transfer->pTempStatusBuffer = &TempStatusBuffer;
	Transfer->pTempUserCollection = &TempUserCollection;


	Transfer->Resume();			//start thread execution now

	//no need to delete Transfer since TransferThread frees itself
}
//---------------------------------------------------------------------------

void __fastcall MessageMgr::onThreadDone (TObject *Sender)
{
	//note:  called by trans thread but runs in the main execution thread, not
	//in TransferThread's, so we can safely update callers collections

	//collect newly arrived normal messages
	MessageBuffer.insert(TempMessageBuffer.begin(), TempMessageBuffer.end());

	//collect newly arrived status message
	StatusBuffer.insert(TempStatusBuffer.begin(), TempStatusBuffer.end());
	confirmMessages();			//process any confirmations received

	if (!TempUserCollection.empty())
	{
		//if there's a new user set, empty old user set, fill w/ new one
		UserCollection.clear();
		UserCollection.insert(TempUserCollection.begin(), TempUserCollection.end());
	}

	map<string, Message>::const_iterator it;
	//add each message received to history and issue confirmation of delivery
	for (it = TempMessageBuffer.begin(); it != TempMessageBuffer.end(); it++)
	{
		addToHistory(it->second);
		confirmDelivery(it->second);
	}


	thread_active = false;					//thread is finished
	transfer_active = thread_active;
	thread_finished = true;

}
//---------------------------------------------------------------------------

void MessageMgr::addToHistory (const Message& what_messg)
{
	//currently only messages with "NORMAL" status are added to history
	if (what_messg.status != "NORMAL")
		return;

	//copy to history
	string mess_rec = what_messg.toXML().c_str();

	ofstream history(hist_filename.c_str(), ios_base::app);

	history << mess_rec << endl;
	history.close();
	
	hist_buffer.push_back(mess_rec);			//keep sync'd with file
}
//---------------------------------------------------------------------------

void MessageMgr::loadLocalHistory ()
{
	ifstream history(hist_filename.c_str());

	hist_buffer.clear();

	string tempstr;
	while (getline(history, tempstr))
		hist_buffer.push_back(tempstr);

	history.close();

}
//---------------------------------------------------------------------------

void MessageMgr::loadUnconfirmed ()
{
	unconf_filename = hist_filename;
	size_t pos = unconf_filename.find_last_of('.');
	unconf_filename.erase(pos);
	unconf_filename += ".uncf";

	ifstream unconf(unconf_filename.c_str());

	string tempstr;
	while (getline(unconf, tempstr))
	{
		Message nxt(tempstr.c_str());
		//now add each to collection
		if (nxt.from == IniOpt->getValue("user_name").c_str())
		{				//this is always true except for blank or garbage lines

			UnconfCollection[nxt.message_id.c_str()] = nxt;
		}
	}

	unconf.close();
}
//---------------------------------------------------------------------------

void MessageMgr::addToUnconfirmed ()
{
	//copies all NORMAL from SendBuffer to UnconfCollection

	vector<Message>::const_iterator it;

	for (it = SendBuffer.begin(); it != SendBuffer.end(); it++)
	{
		if (it->status == "NORMAL")
			UnconfCollection.insert(make_pair(it->message_id.c_str(), *it));
			//note: it's not added if it is already there
	}

}
//---------------------------------------------------------------------------

void MessageMgr::confirmDelivery (const Message& what_messg)
{
	//sents out confirmation of a message that was received

	//build status message to send out (the 'from' of received will now be 'to')
	Message trans_out(what_messg.message_id, IniOpt->getValue("user_name").c_str(),
					what_messg.from, "NORMAL_DLVD", "", "");
	trans_out.location = IniOpt->getValue("user_location").c_str();

	//put it out for the mailman to pick up on next go round
	SendBuffer.push_back(trans_out);
}
//---------------------------------------------------------------------------

void MessageMgr::confirmMessages ()
{
	//process message confirmations received from others

	map<string, Message>::iterator loc;
	map<string, Message>::iterator it;

	for (it = StatusBuffer.begin(); it != StatusBuffer.end(); it++)
	{
		string status = it->second.status.c_str();
		if (status == "NORMAL_RCVD")
		{
			//replace in UnconfCollection
			loc = UnconfCollection.find(it->second.message_id.c_str());
			if (loc != UnconfCollection.end() && loc->second.status == "NORMAL")
				loc->second.status = status.c_str();
			//delete in StatusBuffer
			StatusBuffer.erase(it);
				//ShowMessage("Confirmed:  RCVD");
		}
		else if (status == "NORMAL_DLVD")
		{
			//replace in UnconfCollection
			loc = UnconfCollection.find(it->second.message_id.c_str());
			if (loc != UnconfCollection.end())
				loc->second.status = status.c_str();
			//delete in StatusBuffer
			StatusBuffer.erase(it);
				//ShowMessage("Confirmed:  DLVD");
		}
		else if (status == "NORMAL_READ")
		{
			//delete in UnconfCollection
			loc = UnconfCollection.find(it->second.message_id.c_str());
			if (loc != UnconfCollection.end())
				UnconfCollection.erase(loc);
			//delete in StatusBuffer
			StatusBuffer.erase(it);
				//ShowMessage("Confirmed:  READ");
		}
	}

	saveUnconfirmed();	//to keep latest updates of UnconfCollection persistent

}
//---------------------------------------------------------------------------

void MessageMgr::resendMessages ()
{
	//go through each of all unconfirmed messages and resend based on elapsed time
	//this method should be called by a UI ticker (currently the ping)

	time_t t1;		//the current time
	time_t t0;		//the message's time (most recent time update)

	time(&t1);		//read the current time

	map<string, Message>::iterator it;

	for (it = UnconfCollection.begin(); it != UnconfCollection.end(); it++)
	{
		istringstream(it->second.time.c_str()) >> t0;	//read message's time

		string status = it->second.status.c_str();
		if (status == "NORMAL")				//means NORMAL_RCVD was not received
		{
			int defvalue = IniOpt->getValueInt("resend_if_no_rcvd_interval");
			if ( defvalue > 0 && (t1 - t0) > defvalue )
			{
				//update time and resend
				it->second.time = t1;
				SendBuffer.push_back(it->second);
			}
		}
		else if (status == "NORMAL_RCVD")	//means NORMAL_DLVD was not received
		{
			int defvalue = 60 * IniOpt->getValueInt("resend_if_no_dlvd_interval");
			if ( defvalue > 0 && (t1 - t0) > defvalue )
			{
				//update time and resend
				it->second.time = t1;
				Message temp_msg = it->second;	//need a copy to recreate NORMAL
				temp_msg.status = "NORMAL";
				SendBuffer.push_back(temp_msg);
			}
		}
		else if (status == "NORMAL_DLVD")	//means NORMAL_READ was not received
		{
			int defvalue = 3600 * IniOpt->getValueInt("resend_if_no_read_interval");
			if ( defvalue > 0 && (t1 - t0) > defvalue )
			{
				//update time and resend
				it->second.time = t1;
				Message temp_msg = it->second;	//need a copy to recreate NORMAL
				temp_msg.status = "NORMAL";
				SendBuffer.push_back(temp_msg);
			}
		}
	}

	saveUnconfirmed();	//to keep latest updates of UnconfCollection persistent

}
//---------------------------------------------------------------------------

void MessageMgr::saveUnconfirmed ()
{
	//add each message in unconfirmed collection to file

	ofstream unconfs(unconf_filename.c_str());
	if (!unconfs) return;

	map<string, Message>::const_iterator it;
	for (it = UnconfCollection.begin(); it != UnconfCollection.end(); it++)
	{
		unconfs << it->second.toXML().c_str() << '\n';
	}

	unconfs.close();
}
//---------------------------------------------------------------------------

