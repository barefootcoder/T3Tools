//---------------------------------------------------------------------------
#include <vcl.h>	//Builder IDE development only -- used for ShowMessage()
#pragma hdrstop

#include <iostream>
#include <string>
#include <fstream>
#include <sstream>
using namespace std;

#include "stringlist.h"
using namespace arinbe;

#include "MessageMgr.h"
#include "TransThread.h"
#include "IniOptions.h"

using namespace user_options;

//---------------------------------------------------------------------------
MessageMgr::MessageMgr (const string& history_filename)
{
	hist_filename = history_filename;

	loadLocalHistory();			//load local history file into history buffer
	loadUnconfirmed();			//recharge UnconfCollection from persistent store

	//initialize user collections and order using names stored in ini
	StringList usrlist;
	usrlist.CommaText(IniOpt->getValue("contact_order").c_str());
	for ( int i = 0; i < usrlist.Count(); ++i )
	{
		string user = usrlist.String(i);

		map<string, string> attr;
		attr["from"] = user;
		T3Message temp_mess("MESSAGE", attr, "");

		user_list.push_back(user);			//keeps order
		UserCollection[user] = temp_mess;		//reorders
	}

	thread_active = false;
	thread_finished = false;
	m_should_resend_now = false;
}
//---------------------------------------------------------------------------

void MessageMgr::initTransfer (const T3Message& what_messg)
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

	// transfer new messages
	doTransfer();

	return;
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

	//start thread execution now
	Transfer->Resume();			

	return;
}
//---------------------------------------------------------------------------

void __fastcall MessageMgr::onThreadDone (TObject *Sender)
{
	//note:  called by trans thread but runs in the main execution thread, not
	//in TransferThread's, so we can safely update callers collections

	//collect newly arrived normal messages
	//MessageBuffer.insert(TempMessageBuffer.begin(), TempMessageBuffer.end());

	//collect newly arrived status message
	StatusBuffer.insert(TempStatusBuffer.begin(), TempStatusBuffer.end());

	//process any confirmations received
	confirmMessages();

	if (!TempUserCollection.empty())
	{
		//if there's a new user set, empty old user set, fill w/ new one
		UserCollection.clear();
		UserCollection.insert(TempUserCollection.begin(),
							  TempUserCollection.end());
	}

	//for each received message:  if this message was not already received,
	//collect in message buffer, add to history, and issue delivery confirmation
	multimap<string, T3Message>::const_iterator it = TempMessageBuffer.begin();
	for ( ; it != TempMessageBuffer.end(); it++)
	{
		//check if we already have this message
		string who_from = it->second.getAttribute("from");
		bool already_have = false;

		multimap<string, T3Message>::iterator pit =
        								MessageBuffer.lower_bound(who_from);
		for ( ; pit != MessageBuffer.upper_bound(who_from); ++pit)
		{
			if (it->second.getAttribute("id") == pit->second.getAttribute("id"))
			{
				already_have = true;		//already have this message
				break;
			}
		}

		if (already_have)
			continue;			//so, do nothing with it

		MessageBuffer.insert(*it);
		addToHistory(it->second);
		confirmDelivery(it->second);
	}

	// allow a resend if necessary
	thread_active = false;					

	// check for resends
	if ( m_should_resend_now )
	{
		// resend messages as necessary
		resendMessages();
	}

	//thread is finished
	transfer_active = thread_active;
	thread_finished = true;

	//ShowMessage("Thread terminated OK");
}
//---------------------------------------------------------------------------

void MessageMgr::addToHistory (const T3Message& what_messg)
{
	//currently only messages with "NORMAL" status are added to history
	if (what_messg.getAttribute("status") != "NORMAL")
		return;

	//copy to history
	string mess_rec = what_messg.toXML();

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
		T3Message nxt("MESSAGE", tempstr.c_str());
		//now add each to collection
		//this is always true except for blank or garbage lines
		if (nxt.getAttribute("from") == IniOpt->getValue("user_name").c_str())
		{				
			UnconfCollection[nxt.getAttribute("id")] = nxt;
		}
	}

	unconf.close();
}
//---------------------------------------------------------------------------

void MessageMgr::addToUnconfirmed ()
{
	//copies all NORMAL from SendBuffer to UnconfCollection
	vector<T3Message>::const_iterator it;
	for (it = SendBuffer.begin(); it != SendBuffer.end(); it++)
	{
		if (it->getAttribute("status") == "NORMAL")
		{
			//note: it's not added if it is already there
			UnconfCollection.insert(make_pair(it->getAttribute("id"), *it));
		}
	}

}
//---------------------------------------------------------------------------

void MessageMgr::confirmDelivery (const T3Message& what_messg)
{
	//sends out confirmation of a message that was received
	//build status message to send out (the 'from' of received will now be 'to')
	map<string, string> attr;
	attr["id"] = what_messg.getAttribute("id");
	attr["from"] = IniOpt->getValue("user_name").c_str(); 
	attr["to"] = what_messg.getAttribute("from");
	attr["status"] = "NORMAL_DLVD";
	attr["location"] = IniOpt->getValue("user_location").c_str();
	T3Message trans_out("MESSAGE", attr, "");

	//put it out for the mailman to pick up on next go round
	SendBuffer.push_back(trans_out);
}
//---------------------------------------------------------------------------

void MessageMgr::confirmMessages ()
{

	//process message confirmations received from others
	// -- later may also want to clean up status codes not currently recognized

	multimap<string, T3Message>::iterator it;

	for (it = StatusBuffer.begin(); it != StatusBuffer.end(); )
	{
		string status = it->second.getAttribute("status");
        string id = it->second.getAttribute("id");

		map<string, T3Message>::iterator loc = UnconfCollection.find(id);

		if (status == "NORMAL_RCVD")
		{
			//replace in UnconfCollection
			if (loc != UnconfCollection.end() &&
						loc->second.getAttribute("status") == "NORMAL")
			{
				loc->second.setAttribute("status", status);

			}

			//delete in StatusBuffer
			StatusBuffer.erase(it++);
			//ShowMessage("Confirmed:  RCVD");
		}
		else if (status == "NORMAL_DLVD")
		{
			//replace in UnconfCollection
			if (loc != UnconfCollection.end())
			{
				loc->second.setAttribute("status", status);
			}

			//delete in StatusBuffer
			StatusBuffer.erase(it++);
			//ShowMessage("Confirmed:  DLVD");
		}
		else if (status == "NORMAL_READ")
		{
			//delete in UnconfCollection
			if (loc != UnconfCollection.end())
			{
				UnconfCollection.erase(loc);
			}

			//delete in StatusBuffer
			StatusBuffer.erase(it++);
			//ShowMessage("Confirmed:  READ");
		}
		else
        {
        	// go to next one
			++it;
        }
	}

    //to keep latest updates of UnconfCollection persistent
	saveUnconfirmed();

    return;
}
//---------------------------------------------------------------------------

void MessageMgr::resendMessages ()
{
	// This function is called from the ping timer
	// However, if the ping timer goes off before the TransThread has
	// finished then this function will start to stack messages that
	// may get confirmed by the TransThread.  This will cause duplicate
	// messages to be sent.  
	
	// Therefore, we need to do some mutex-like checking.

	// if thread active set some flags to call this fcn from ThreadDone fcn
	if ( thread_active )
	{
		// set flag
		m_should_resend_now = true;

		// get out here
		return;
	}

	// reset flag
	m_should_resend_now = false;

	time_t t1;		//the current time
	time_t t0;		//the message's time (most recent time update)
	time(&t1);		//read the current time
	char t1str[50];
	sprintf(t1str, "%ld", t1);

	map<string, T3Message>::iterator it;

	for (it = UnconfCollection.begin(); it != UnconfCollection.end(); it++)
	{
		//read message's time
		istringstream(it->second.getAttribute("time")) >> t0;

		//check if addressee has on-line status (so it will not resend undelivd)
		bool isonline = false;
		map<string, T3Message>::iterator usrit;
		usrit = UserCollection.find(it->second.getAttribute("to"));
		if (usrit != UserCollection.end() )
		{
			// check user status
			if ( usrit->second.getAttribute("status") != "IMOFF" )
				isonline = true;
		}

		string status = it->second.getAttribute("status");
		if (status == "NORMAL")				
		{
			//means NORMAL_RCVD was not received
			int defvalue = IniOpt->getValueInt("resend_if_no_rcvd_interval");
			if ( defvalue > 0 && (t1 - t0) > defvalue )
			{
				//update time and resend
				it->second.setAttribute("time", t1str);
				SendBuffer.push_back(it->second);
			}
		}
		else if (status == "NORMAL_RCVD")	
		{
			//means NORMAL_DLVD was not received
			int defvalue = 60 * IniOpt->getValueInt("resend_if_no_dlvd_interval");
			if ( isonline && defvalue > 0 && (t1 - t0) > defvalue )
			{
				//update time and resend
				it->second.setAttribute("time", t1str);

				//need a copy to recreate NORMAL
				T3Message temp_msg(it->second);	
				temp_msg.setAttribute("status", "NORMAL");
				SendBuffer.push_back(temp_msg);
			}
		}
		else if (status == "NORMAL_DLVD")	
		{
			//means NORMAL_READ was not received
			int defvalue = 3600 * IniOpt->getValueInt("resend_if_no_read_interval");
			if ( isonline && defvalue > 0 && (t1 - t0) > defvalue )
			{
				//update time and resend
				it->second.setAttribute("time", t1str);

				//need a copy to recreate NORMAL
				T3Message temp_msg(it->second);	
				temp_msg.setAttribute("status", "NORMAL");
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
	if (!unconfs)
    	return;

	map<string, T3Message>::const_iterator it;
	for (it = UnconfCollection.begin(); it != UnconfCollection.end(); it++)
	{
		unconfs << it->second.toXML() << '\n';
	}

	unconfs.close();
}
//---------------------------------------------------------------------------

