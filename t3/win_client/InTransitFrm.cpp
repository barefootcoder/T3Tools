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
	MessageList->Clear();
	DeliveryStatus->Clear();
	unconf_id_list.clear();

	int pos = MessageList->ItemIndex;

	map<string, Message>::iterator it;
	for (it = MessagePump->UnconfCollection.begin();
							it != MessagePump->UnconfCollection.end(); it++)
	{
		MessageList->Items->Add(it->second.message_text);
		unconf_id_list.push_back(it->first);
		string status = it->second.status.c_str();
		if  (status == "NORMAL")
			DeliveryStatus->Items->Add("Unacknowledged");
		else if (status == "NORMAL_RCVD")
			DeliveryStatus->Items->Add("Received by Server");
		else if (status == "NORMAL_DLVD")
			DeliveryStatus->Items->Add("Delivered but Not Read");
		else
			DeliveryStatus->Items->Add("");
	}

	if (MessageList->Items->Count > 0 && pos == -1)
		pos = 0;
	MessageList->ItemIndex = pos;
	DeliveryStatus->ItemIndex = pos;

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
		MessageList->Items->Delete(curr_pos);
		DeliveryStatus->Items->Delete(curr_pos);
		MessagePump->UnconfCollection.erase(unconf_id_list[curr_pos]);
	}
}
//---------------------------------------------------------------------------

