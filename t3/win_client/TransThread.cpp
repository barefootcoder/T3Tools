//---------------------------------------------------------------------------

#include <vcl.h>
#pragma hdrstop

#include "impmBFTalker.h"		//instant messaging personality module

#include "TransThread.h"
//#include "MainFrm.h"

#pragma package(smart_init)
//---------------------------------------------------------------------------

//   Important: Methods and properties of objects in VCL can only be
//   used in a method called using Synchronize, for example:
//
//      Synchronize(UpdateCaption);
//
//   where UpdateCaption could look like:
//
//      void __fastcall Unit1::UpdateCaption()
//      {
//        Form1->Caption = "Updated in a thread";
//      }
//---------------------------------------------------------------------------

__fastcall TransferThread::TransferThread(bool CreateSuspended)
	: TThread(CreateSuspended)
{
	Priority = tpNormal;
	FreeOnTerminate = true;
	timeout = TIMEOUT_DEFAULT;
	//OnTerminate = OnDone;			//OnTerminate event is now member of caller

}
//---------------------------------------------------------------------------
void __fastcall TransferThread::Execute()
{
	//basic communication exchange -- sends transmissions to server and
	//receives transmissions from server
	//--this function alone should know about the interface to
	//  the communications personality module(s)

  try
  {
	//send all the messages in the last TempSendBuffer
	for (int m = 0; m < pTempSendBuffer->size(); m++)
	{
		//add here code to terminate thread by caller request, if needed

		Message trans_out = (*pTempSendBuffer)[m];

		IMessage = new InstantMessage;

		IMessage->message_id = trans_out.message_id.c_str();
		IMessage->from = trans_out.from.c_str();
		IMessage->address = "";					//rfu
		IMessage->location = trans_out.location.c_str();
		IMessage->gmt_time = trans_out.time.c_str();
		IMessage->to = trans_out.to.c_str();
		IMessage->status = trans_out.status.c_str();
		IMessage->subject = trans_out.thread.c_str();
		IMessage->message_text = trans_out.message_text.c_str();

		result = EXIT_FAILURE;			//assume error as default

		for (int i = 0; i < 2; i++)		//attempt to connect to server up to 2X
		{
			result = sendIMessage(cgi_exe.c_str(), timeout, keeplog);
			if (result == EXIT_SUCCESS)
				break;
		}

		delete IMessage;

		//convert from map of structs coming in to maps of Message's for processing
		for (multimap<string, InstantMessage>::const_iterator it = RecvdIMessages->begin();
					it != RecvdIMessages->end(); it++)
		{
			Message new_message;

			new_message.message_id = it->second.message_id.c_str();
			new_message.from = it->second.from.c_str();
			new_message.location = it->second.location.c_str();
			new_message.time = it->second.gmt_time.c_str();
			new_message.to = it->second.to.c_str();
			new_message.status = it->second.status.c_str();
			new_message.thread = it->second.subject.c_str();
			new_message.message_text = it->second.message_text.c_str();

			if (new_message.status == "NORMAL")
				pTempMessageBuffer->insert(make_pair(new_message.from.c_str(), new_message));
			else if (new_message.status == "IMON" ||
					 new_message.status == "IMOFF" ||
					 new_message.status == "IMBUSY")
				(*pTempUserCollection)[new_message.from.c_str()] = new_message;
			else
				pTempStatusBuffer->insert(make_pair(new_message.from.c_str(), new_message));
				//this is the catch-all for all other types of messages
		}

		if (RecvdIMessages->empty())
			result = EXIT_FAILURE;		//if no data, it failed no matter what

		if (result == EXIT_SUCCESS)		//if comm w/ server did not fail, we
		{                               //can remove this message from send buff
			pTempSendBuffer->erase(pTempSendBuffer->begin() + m--);
		}

	} //go back up to send next message

  }
  catch (...)
  {
	//don't care - should affect nothing, just leaves unsent messages in buffer
  }

}
//---------------------------------------------------------------------------

