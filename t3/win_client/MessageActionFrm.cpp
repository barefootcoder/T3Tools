//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include <time.h>
#include <sstream>

#include "MessageActionFrm.h"
#include "IniOptions.h"
#include "MessageMgr.h"
#include "MainFrm.h"			//TODO :  eventually remove dependency on MainForm
								//		  and rely solely on MessageMgr instead

using namespace std;
using namespace user_options;
using namespace message_pump;

//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TMessageActionForm *MessageActionForm;
//---------------------------------------------------------------------------
__fastcall TMessageActionForm::TMessageActionForm(TComponent* Owner)
	: TForm(Owner)
{
	KeyPreview = true;		//for form to respond to keyboard events

	//read message window size and position from ini file
	if (IniOpt->getValue("messageform_left") != "")		//if not first time
	{
		Position = poDesigned;				//to override default Center
		Left = IniOpt->getValueInt("messageform_left", Left);
		Top = IniOpt->getValueInt("messageform_top", Top);
		Width = IniOpt->getValueInt("messageform_width", Width);
		Height = IniOpt->getValueInt("messageform_height", Height);

		//until a Message form closes, this is the new value for staggered view
		bool save_to_ini = true;
		IniOpt->setValueInt("messageform_left", Left + 10, save_to_ini);
		IniOpt->setValueInt("messageform_top", Top + 10, save_to_ini);
		IniOpt->setValueInt("messageform_width", Width + 10, save_to_ini);
		IniOpt->setValueInt("messageform_height", Height + 10, save_to_ini);
	}

	//set message window display font attributes
	//TheMessage->Font = OptionsForm->MessageFont->Font;

	TheMessage->Font->Name = IniOpt->getValue("messagefont_name").c_str();
	TheMessage->Font->Size = IniOpt->getValueInt("messagefont_size", 8);
	TheMessage->Font->Color = IniOpt->getValueInt("messagefont_color", clBlack);
	if (IniOpt->getValueInt("messagefont_bold", 0))
		TheMessage->Font->Style << fsBold;
	else
		TheMessage->Font->Style >> fsBold;
	if (IniOpt->getValueInt("messagefont_italic", 0))
		TheMessage->Font->Style << fsItalic;
	else
		TheMessage->Font->Style >> fsItalic;

	//set multi-select mode
	UserList->ExtendedSelect = (IniOpt->getValue("multiselect_mode") == "1");

	history_on = false;

}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::FormShow(TObject *Sender)
{

	//add users to dropdown lists (read users from Contacts panels
	//instead of UserCollection to preserve same order)
	for (int i = 0; i < MainForm->Contacts->Items->Count; i++)		//add others
	{
		UserList->Items->Add(MainForm->Contacts->Items->Strings[i]);
	}

	if (user == "") return;			//do nothing else if no user applies

	//if a user applies (was initially clicked) there's more to do:

	//select my current correspondent (default for Send):
	UserList->Selected[UserList->Items->IndexOf(user)] = true;

	//when form is created, if there's a message from
	//corresponding user, show it immediately:

	multimap<string, Message>::iterator it;
	it = MainForm->pMessageBuffer->find(user.c_str());	//locate a message from user

	if (it != MainForm->pMessageBuffer->end())	//if there's one,
		GetMessgClick(GetMessg);				//simulate pressing Read button

	manageMessageButtons(0);					//default for form create

}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::FormClose(TObject *Sender,
	  TCloseAction &Action)
{
	TheMessage->Clear();

	//save current size and position of Message form (last one to close overwrites)
	bool save_to_ini = true;
	IniOpt->setValueInt("messageform_left", Left, save_to_ini);
	IniOpt->setValueInt("messageform_top", Top, save_to_ini);
	IniOpt->setValueInt("messageform_width", Width, save_to_ini);
	IniOpt->setValueInt("messageform_height", Height, save_to_ini);

	if (MainForm->Contacts->Items->Count > 0)		//Repaint
		MainForm->Contacts->Items->Strings[0] = MainForm->Contacts->Items->Strings[0];

	if (MainForm->form_last_viewed == this)
		MainForm->form_last_viewed = 0;

	Action = caFree	;		//destroy form on close
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::GetMessgClick(TObject *Sender)
{
	MainForm->readMessage(this);

	manageMessageButtons(2);
	ReplyMessg->Enabled = true;
	BroadcastMessg->Enabled = false;
	SendMessg->Enabled = false;			//disable after clicking ReadNext
										//later turned on by typing
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::SendMessgClick(TObject *Sender)
{
	String who_to;

	//send to each selected user
	for (int i = 0; i < UserList->Items->Count; i++)
		if (UserList->Selected[i])
		{
			if (who_to.Length() > 0) who_to += ',';
			who_to += UserList->Items->Strings[i];
		}

	MainForm->sendMessage(this, -2, who_to);	//-2 means who_to arg is read

	manageMessageButtons(1);
	ActiveControl = TheMessage;

}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::ReplyMessgClick(TObject *Sender)
{
	//all this does is create string that goes in the Topic edit control

	String tempstr;

	tempstr = last_read_message.thread;
	int lkpos = tempstr.Pos(">>");
	if (lkpos)
		tempstr = tempstr.SubString(1, lkpos - 1);
	tempstr += " >>";
					
	tempstr += makeTag(last_read_message.message_text);

	Topic->Text = tempstr;

	ReplyMessg->Enabled = false;
	ClearMessageClick(ClearMessage);
	ReplyLED->Visible = true;
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::BroadcastMessgClick(TObject *Sender)
{
	TMsgDlgButtons buttons;
	buttons << mbYes << mbNo;
	int check;
	check = MessageDlg("BROADCAST this message to EVERY user?",
							mtConfirmation, buttons, 0);

	if (check != mrYes) return;

	MainForm->sendMessage(this, -2, "ALL");		//-2 means who_to arg is read

	manageMessageButtons(1);
	ActiveControl = TheMessage;

}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::CloseFormClick(TObject *Sender)
{
	this->Close();

}
//---------------------------------------------------------------------------

void TMessageActionForm::manageMessageButtons(int state)
{
	//manages the visuals on the Message form. These depend on the current
	//state of the form.  These are the current options:
	//
	//	0 - when the form is first created
	//	1 - right after a Send or Broadcast
	//	2 - right after a Read
	//	3 - disable all except History
	//	4 - restores to state of previous call

	static bool read_state = false;
	static bool send_state = false;
	static bool clear_state = true;
	static bool history_state = true;
	static bool reply_state = false;

	//remember previous state in case it needs to be restored
	if (state != 4)		//but don't overwrite it if this is a restore call
	{
		read_state = GetMessg->Enabled;
		send_state = SendMessg->Enabled;
		clear_state = ClearMessage->Enabled;
		history_state = ShowHistory->Enabled;
		reply_state = ReplyMessg->Enabled;
	}

	switch (state)
	{
		case 0:							//on create
			SendMessg->Enabled = false;			//later turned on/off by typing
			BroadcastMessg->Enabled = false;	//later turned on/off by typing
			GetMessg->Enabled = false;			//turned on by autoread or case 2
			ClearMessage->Enabled = (TheMessage->Text != "");
			break;
		case 1:							//after Send/Broadcast
			TheMessage->Clear();
			Topic->Clear();
			ReplyLED->Visible = false;
			SendMessg->Enabled = false;
			BroadcastMessg->Enabled = false;
			if (IniOpt->getValue("close_on_send") == "1") this->Close();
			break;
		case 2:							//after Read
			{
			multimap<string, Message>::iterator it;
			it = MainForm->pMessageBuffer->find(user.c_str());	//locate message from user
			//enable ReadNext button if there's still another message from this user:
			GetMessg->Enabled = (it != MainForm->pMessageBuffer->end());
			}
			break;
		case 3:							//disable all except history
			GetMessg->Enabled = false;
			SendMessg->Enabled = false;
			BroadcastMessg->Enabled = false;
			ClearMessage->Enabled = false;
			ReplyMessg->Enabled = false;
			break;
		case 4:							//restore to previous state
			GetMessg->Enabled = read_state;
			SendMessg->Enabled = send_state;
			BroadcastMessg->Enabled = send_state;
			ClearMessage->Enabled = clear_state;
			ShowHistory->Enabled = history_state;
			ReplyMessg->Enabled = reply_state;
			break;
		default:
			this->Close();
	}

	//TheMessageChange() also affects the state of the buttons
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::TheMessageChange(TObject *Sender)
{
	if (history_on)
		return;		//this does not apply in view history mode

	if (TheMessage->Text == "")
	{
		SendMessg->Enabled = false;
		BroadcastMessg->Enabled = false;
		ClearMessage->Enabled = false;
	}
	else
	{
		SendMessg->Enabled = true;
		BroadcastMessg->Enabled = true;
		ClearMessage->Enabled = true;
	}

	if (Caption != (user + " - Message"))	//this forces the Caption to revert
		Caption = user + " - Message";		//to its default
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::ClearMessageClick(TObject *Sender)
{
	TheMessage->Clear();
	TheMessageChange(TheMessage);	//because above line won't trigger it
	ActiveControl = TheMessage;

	ReplyLED->Visible = false;		//for now, it also clears reply status
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::FormKeyDown(TObject *Sender, WORD &Key,
      TShiftState Shift)
{
	if (Key == VK_ESCAPE)
		this->Close();

	if (Key == VK_CAPITAL && Shift.Contains(ssAlt))
	{
		MainForm->SetFocus();
		MainForm->form_last_viewed = this;
		return;
	}

	int this_one = -1;
	//alt-shift to display next Message form
	if (Key == VK_SHIFT && Shift.Contains(ssAlt))
	{
		for (int i = 0; i < Application->ComponentCount; i++)
		{
			if (this_one != -1 && Application->Components[i]->Name.Pos("MessageActionForm"))
			{
				((TForm*) Application->Components[i])->SetFocus();
				break;
			}
			if (Application->Components[i] == this)  this_one = i;
			if (i == Application->ComponentCount - 1)  i = 0;
		}
	}

}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::UserListClick(TObject *Sender)
{
	if (!history_on)
	{
		ActiveControl = TheMessage;
		return;
	}

	//the rest of the code in this event is only for history mode
	//selects which messages to view

	TheMessage->Clear();

	vector<string>* temp_history1 = &(MessagePump->hist_buffer);
	//TStringList* temp_history1; 						//now is just a pointer
	TStringList* temp_history2 = new TStringList();		//selected, formatted

	//temp_history1 = MainForm->hist_buffer;		//new way, so it displays faster

	String last_thread;		//needs to persist from one for-iteration to next
	for (int i = temp_history1->size() - 1; i >= 0 ; i--)	//read messgs in reverse order
	{
		Message mess((*temp_history1)[i].c_str());			//next message

		if (UserList->Items->IndexOf(mess.from) == -1 ||
			!UserList->Selected[UserList->Items->IndexOf(mess.from)])
			continue;	//do not select this message if sender is either
						//not in the list or not selected

		//since there can be multiple recipients, check each one
		String recipients = mess.to;
		bool found_one = false;
		do
		{
			int pos = recipients.Pos(',');
			String who_to = recipients.SubString(1, pos ? pos - 1 : recipients.Length());
			//remove who_to from recipients:
			recipients.Delete(1, pos ? who_to.Length() + 1 : who_to.Length());

			if (UserList->Items->IndexOf(who_to) != -1 &&	//in list & selected
					UserList->Selected[UserList->Items->IndexOf(who_to)])
			{
				found_one = true;
				break;						//only need a match on one
			}
		}
		while (recipients.Length());

		if (!found_one) 	//do not select this message if none of its
			continue;   	//recipients is selected
						

		String subject = mess.thread;				//for subject part of thread
		String curr_thread = mess.thread;			//for the true thread

		//to display subject, we only want subject part of thread, if any
		if (int pos = subject.Pos(">>"))
		{                                    			//make:
			curr_thread.Delete(1, pos + 1);				//the true thread
			subject = subject.SubString(1, pos - 1);	//subject part of thread
		}

		//format time
		String messg_time = mess.time;
		time_t t;
		stringstream(messg_time.c_str()) >> t;

		//this inactive code could be used for displaying custom time formats
		/*struct tm* timeis = localtime(&t);
		stringstream timestamp;
		timestamp << (timeis->tm_mon + 1) << '/' << timeis->tm_mday << '/';
		timestamp << (1900 + timeis->tm_year) << ' ';
		timestamp << timeis->tm_hour << ':' << timeis->tm_min << ':';
		timestamp << timeis->tm_sec;
		//ShowMessage(timestamp.str().c_str());
		//ShowMessage(ctime(&t));					*/

		messg_time = ctime(&t);
		messg_time.Delete(messg_time.Length(), 1);	//delete '\n' at the end

		//check more filters and exclude appropriately:
		//by Subject
		if (FilterSubject->Text != "" && FilterSubject->Text != subject)
			continue;
		//by Keyword
		if (FilterKw->Text != "" && !mess.message_text.Pos(FilterKw->Text))
			continue;
		//by Thread
		if (i == temp_history1->size() - 1)	//keep first message (last in history)
		{									//and it serves as the starting seed
			last_thread = curr_thread;
		}
		else if (FilterThread->Checked)		//if filter is to get thread only
		{
			if (last_thread != makeTag(mess.message_text))
				continue;					//don't keep if no match on thread
			else
				last_thread = curr_thread;	//rearm for next match up the line
		}

		//add formatted output (of selected hist messages) to double-buffer:
		temp_history2->Add(String("From:  ") + mess.from + "     To:  " + mess.to);
		temp_history2->Add(messg_time);
		if (subject.Length() > 0)
			temp_history2->Add(String("Subject:  ") + subject);
		temp_history2->Add("");
		temp_history2->Add(mess.message_text);
		temp_history2->Add(IniOpt->getValue("hist_message_divider").c_str());

	}

	TheMessage->Lines = temp_history2;		//copy from double-buffer

	delete temp_history2;
	ActiveControl = TheMessage;
	TheMessage->SelStart = 0;
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::MessageCheckTimer(TObject *Sender)
{
	//to check if new messages have arrived in order to activate ReadNext button
	if (!history_on)			//only if not in view-history mode
		manageMessageButtons(2);
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::AllClick(TObject *Sender)
{
	//called by All and None buttons

	for (int i = 0; i < UserList->Items->Count; i++)
		UserList->Selected[i] = (Sender == All);	//select all or none

	UserListClick(Sender);		//same action as if UserList itself were clicked
}
//---------------------------------------------------------------------------
//this is an out-of-view simulator button for ShowHistory so that AltH works
void __fastcall TMessageActionForm::HistButtonClick(TObject *Sender)
{
	ShowHistory->Down = !ShowHistory->Down;
	ShowHistoryClick(ShowHistory);
}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::ShowHistoryClick(TObject *Sender)
{

	static String temp_message("");
	static String temp_caption("");

	for (int i = 0; i < UserList->Items->Count; i++)
		UserList->Selected[i] = false;			//unselect all items

	history_on = ShowHistory->Down;		//formerly = !history_on

	if (history_on)				//we're now in history view mode
	{
		//select me and my current correspondent (default for history)
		UserList->Selected[UserList->Items->IndexOf(IniOpt->getValue("user_name").c_str())] = true;
		UserList->Selected[UserList->Items->IndexOf(user)] = true;

		temp_message = TheMessage->Text;	//hold on to display so we can restore
		temp_caption = Caption;				//hold on to caption so we can restore
		Caption = user + " - Message";		//then replace caption w/ default
		TheMessage->Clear();
		UserListClick(UserList);			//simulate UserList control click
		TheMessage->ReadOnly = true;
		//History->Caption = "Hide &History";	//left over from button caption
		manageMessageButtons(3);			//disable message action buttons

		Topic->Visible = false;
		FilterSubject->Visible = true;
		FilterKw->Visible = true;
		FilterThread->Visible = true;
		ApplyFilter->Visible = true;

	}
	else						//we're now in regular send/read mode
	{
		//UserList->Items->Delete(UserList->Items->Count - 1);		//delete me

		//select only my correspondent (default for Send)
		UserList->Selected[UserList->Items->IndexOf(IniOpt->getValue("user_name").c_str())] = false;
		UserList->Selected[UserList->Items->IndexOf(user)] = true;

		TheMessage->Clear();
		TheMessage->Text = temp_message;	//restore previous display
		Caption = temp_caption;				//restore Caption
		manageMessageButtons(4);			//restore previous states of buttons
		//History->Caption = "View &History";
		TheMessage->ReadOnly = false;
		ActiveControl = TheMessage;

		FilterSubject->Visible = false;
		FilterKw->Visible = false;
		FilterThread->Visible = false;
		ApplyFilter->Visible = false;
		Topic->Visible = true;
	}

}
//---------------------------------------------------------------------------

void __fastcall TMessageActionForm::ApplyFilterClick(TObject *Sender)
{
	UserListClick(UserList);			//simulate UserList control click
}
//---------------------------------------------------------------------------

String TMessageActionForm::makeTag (String& what_message)
{
	//creates a message identifier -- currently the first 30 chars of the
	//									message, with newlines replcd by spaces

	String tempstr = what_message.TrimLeft();
	tempstr = tempstr.SubString(1, 30);

	while (int pos = tempstr.Pos("\r"))		//need to modify for Unix
	{
		tempstr.Delete(pos, 2);
		tempstr.Insert("  ", pos);
	}

	return tempstr;
}
//---------------------------------------------------------------------------

