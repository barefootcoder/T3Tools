//---------------------------------------------------------------------------

#include <vcl.h>
#pragma hdrstop

#include "InTransitFrm.h"
#include "MessageMgr.h"
#include "IniOptions.h"


using namespace message_pump;
using namespace user_options;

//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TInTransitForm *InTransitForm;
//---------------------------------------------------------------------------
__fastcall TInTransitForm::TInTransitForm(TComponent* Owner)
	: TForm(Owner)
{

	MessageList->DoubleBuffered = true;
	DeliveryStatus->DoubleBuffered = true;
}
//---------------------------------------------------------------------------
void __fastcall TInTransitForm::RefresherTimer(TObject *Sender)
{

	int pos = MessageList->ItemIndex;
	string pos_id;
	if (pos == -1)
		Cancel->Enabled = false;
	else
		pos_id = unconf_id_list[pos];	//remember which one was selected

	MessageList->Clear();
	DeliveryStatus->Clear();
	unconf_id_list.clear();

	int idx = 0;

	map<string, T3Message>::const_iterator it;
	for (it = MessagePump->UnconfCollection.begin();
							it != MessagePump->UnconfCollection.end(); it++)
	{
		string status = it->second.getAttribute("status");
		if  (status == "NORMAL")
			DeliveryStatus->Items->Add("Unacknowledged");
		else if (status == "NORMAL_RCVD")
			DeliveryStatus->Items->Add("Received by Server");
		else if (status == "NORMAL_DLVD")
			DeliveryStatus->Items->Add("Delivered but Not Read");
		else if ( !status.empty() )
        	DeliveryStatus->Items->Add(status.c_str());
		else
			continue;		//nothing to add to in-transit display

		MessageList->Items->Add(it->second.getContent().c_str());
		unconf_id_list[idx++] = it->first;
	}

	pos = -1;
	//check if the previously selected one is still in the list
	map<int, string>::const_iterator pit;
	for (pit = unconf_id_list.begin(); pit != unconf_id_list.end(); pit++)
	{
		if (pos_id == pit->second)
			pos = pit->first;		//and if so, keep it selected
	}

	MessageList->ItemIndex = pos;
	DeliveryStatus->ItemIndex = pos;
	ActiveControl = 0;

	Refresher->Interval = 1000 * IniOpt->getValueInt("refresh_unconfs_view");

}
//---------------------------------------------------------------------------
void __fastcall TInTransitForm::FormShow(TObject *Sender)
{
	RefresherTimer(this);
}
//---------------------------------------------------------------------------

void __fastcall TInTransitForm::FormResize(TObject *Sender)
{
	if (MessageList->Width > Width - 40)
		MessageList->Width = Width - 40;
}
//---------------------------------------------------------------------------

void __fastcall TInTransitForm::CancelClick(TObject *Sender)
{
	int curr_pos = MessageList->ItemIndex;

	if (curr_pos > -1)
	{
		MessagePump->UnconfCollection.erase(unconf_id_list[curr_pos]);
		unconf_id_list.erase(curr_pos);
		MessageList->Items->Delete(curr_pos);
		DeliveryStatus->Items->Delete(curr_pos);
	}

	Cancel->Enabled = false;

}
//---------------------------------------------------------------------------

void __fastcall TInTransitForm::MessageListClick(TObject *Sender)
{
	if (MessageList->ItemIndex > -1)
		Cancel->Enabled = true;
	DeliveryStatus->ItemIndex = MessageList->ItemIndex;
}
//---------------------------------------------------------------------------

void __fastcall TInTransitForm::DeliveryStatusClick(TObject *Sender)
{
	MessageList->ItemIndex = DeliveryStatus->ItemIndex;
}
//---------------------------------------------------------------------------

