//---------------------------------------------------------------------------

#include <vcl.h>
#pragma hdrstop

#include <iostream>
#include <fstream>
using namespace std;

#include "comm.h"
#include "TransThread.h"

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
	timeout = 2; //TIMEOUT_DEFAULT;

	return;
}
//---------------------------------------------------------------------------
void __fastcall TransferThread::Execute()
{
	try
	{
		//send all the messages in the last TempSendBuffer
		for (int m = 0; m < (int) pTempSendBuffer->size(); m++)
		{
			//add here code to terminate thread by caller request, if needed

			// set the message to be sent
			T3Message im((*pTempSendBuffer)[m]);
			T3MultiMap t3rm;

			//assume error as default
			result = EXIT_FAILURE;

			//attempt to connect to server up to 2X
			for (int i = 0; i < 2; i++)
			{
				if ( sendT3Message(im, t3rm, cgi_exe, timeout, keeplog) )
				{
					result = EXIT_SUCCESS;
					break;
				}
			}

			//convert from map of structs coming in to maps of Message's for processing
			T3MultiMap::const_iterator it = t3rm.begin();
			for ( ; it != t3rm.end(); it++)
			{
				T3Message new_message(it->second);
				string from = new_message.getAttribute("from");
				string status = new_message.getAttribute("status");
				if (status == "NORMAL")
				{
					pTempMessageBuffer->insert(make_pair(from, new_message));
				}
				else if (status == "IMON" || status == "IMOFF" ||
						 status == "IMBUSY")
				{
					(*pTempUserCollection)[from.c_str()] = new_message;
				}
				else
				{
					//this is the catch-all for all other types of messages
					pTempStatusBuffer->insert(make_pair(from.c_str(), new_message));
				}
			}

			if ( t3rm.empty() )
				result = EXIT_FAILURE;		//if no data, it failed no matter what

			if (result == EXIT_SUCCESS)		//if comm w/ server did not fail, we
			{
				//can remove this message from send buff
				pTempSendBuffer->erase(pTempSendBuffer->begin() + m--);
			}

		} //go back up to send next message

	}
	catch (Exception& e)
	{
    	// show the exception
		Application->ShowException(&e);
	}

}
//---------------------------------------------------------------------------

