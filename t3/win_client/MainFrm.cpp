//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include <iostream>
#include <fstream>
#include <sstream>
#include <ctime>
using namespace std;

#include "t3client.h"

#include "stringlist.h"
using namespace arinbe;

#include "MainFrm.h"
#include "IniOptions.h"
#include "MessageMgr.h"
#include "NewTimr.h"
#include "TimerActionFrm.h"
#include "MessageActionFrm.h"
#include "OptionsFrm.h"
#include "TransThread.h"
#include "UtilityDialg.h"
#include "InTransitFrm.h"
#include "comm.h"

using namespace user_options;
using namespace message_pump;

//pointers to objects to be used by any units in application
IniOptions* user_options::IniOpt;
MessageMgr* message_pump::MessagePump;

//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TMainForm *MainForm;
//---------------------------------------------------------------------------
__fastcall TMainForm::TMainForm(TComponent* Owner)
	: TForm(Owner), m_tmrmgr(theTimerMgr())
{

	KeyPreview = true;		//for form to respond to keyboard events

	online = false;						//start off-line for messages
	available = true;
	blink = false;
	no_timer_update = false;
	have_messages = false;
	busy_on_shut_down = false;
	message_base_id = 0x0ui64;		//****SET TO 0x0ui64 BEFORE RELEASE****

	initApp();							//read ini settings, etc.


	contacts_width = Contacts->Width;
	activateTimerFeatures();

	// TODO, GET RID OF THIS HACK
	OptionsClick(NULL);
	if ( m_tmrmgr.pingServer() )
	{
    	doTimerMaintenance();
        updateClocks();
    }
    else
	{
		ShowMessage("Unable to retrieve timer list.  Reason:\n\n" + 
					AnsiString(m_tmrmgr.getLastError().c_str()));
	}

	MessagePump = new MessageMgr(T3HisFilename().c_str());
	pUserCollection = &(MessagePump->UserCollection);
	pMessageBuffer = &(MessagePump->MessageBuffer);
	pStatusBuffer = &(MessagePump->StatusBuffer);
	puser_list = &(MessagePump->user_list);

	//seed initial user names from values read from ini file
	for (int i = 0; i < (int) puser_list->size(); i++)
		Contacts->Items->Add((*puser_list)[i].c_str());

	if (hidden_timer_panes[0])  HideTimerNames->Picture = ShowArrow->Picture;
	else  HideTimerNames->Picture = HideArrow->Picture;

	if (hidden_timer_panes[1])  HideTimerDigits->Picture = ShowArrow->Picture;
	else  HideTimerDigits->Picture = HideArrow->Picture;

	if (hidden_timer_panes[2])  HideTimerIcons->Picture = ShowArrow->Picture;
	else  HideTimerIcons->Picture = HideArrow->Picture;

	Contacts->DoubleBuffered = true;
	TimersList->DoubleBuffered = true;
	Panel1->DoubleBuffered = true;
	StatBar->DoubleBuffered = true;

}
//---------------------------------------------------------------------------
void __fastcall TMainForm::FormShow(TObject *Sender)
{
	keepWithinScreen();

	ImOnClick(ImOn);				//immediately go on-line at startup

	Blinker->Enabled = true;		//can start Blinker now that form is ready

	//if no hidden panes, create new init value (otherwise retains ini value):
	//(this will reset proper width of timer names if it gets out of whack)
	//(also called by HideTimersClick)
	if (!hidden_timer_panes[0] && !hidden_timer_panes[1] && !hidden_timer_panes[2])
		timernames_width = TimersList->Width - DIGITS_PLUS_ICONS;
}
//---------------------------------------------------------------------------
void TMainForm::keepWithinScreen()
{
	//prevent form from showing outside viewable screen area

	int hidden_area;
	if ((hidden_area = Left + Width - Screen->Width) > 0)
		Left -= (hidden_area + 1);
	if ((hidden_area = Top + Height - Screen->Height) > 0)
		Top -= (hidden_area + 1);

	if (Left < 0) Left = 1;
	if (Top < 0) Top = 1;
	
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::FormClose(TObject *Sender, TCloseAction &Action)
{
	static bool dejavu = false;

	//this is to prevent code below from being called twice
	if (dejavu) 
		return;	

	dejavu = true;

	// stop the TimerMgr pings
	m_tmrmgr.setPingInterval(0);	

	if (MessagePump->transfer_active)	//we're currently communicating, so
		busy_on_shut_down = true;		//we'll have to wait for it too

	if (online)
		ImOnClick(ImOn);	//if user still on-line, press on/off-line button

	//show closing dialog and check whether there are messages in SendBuffer

	if (MessagePump->transfer_active)
	{
		if (UtilityDialog->ShowModal() != mrOk)		//closed by Blinker
		{
			ShowMessage("There are still unsent messages. Attempts to resend "
						"them will continue next time you go back online.");
			MessagePump->addToUnconfirmed();
			//Because above line now always saves unsent messages for later
			//resend, the following option to go back on-line is no longer needed
			/*
			TMsgDlgButtons buttons;
			buttons << mbYes << mbNo;
			int check = MessageDlg("Due to communication problems, there are "
							"still messages that have not been sent.\n"
							"Closing T3Client now will "
							"terminate further attempts to deliver "
							"these messages.\n\nClose Anyway?",
							mtConfirmation, buttons, 0);
			if (check != mrYes)
			{
				Action = caNone;		//do not close this form
				dejavu = false;			//so this code can be called again
				busy_on_shut_down = false;
				ImOnClick(ImOn);		//go back on-line
				return;					//don't execute code below
			}
			*/
		}
	}

	cleanupApp();			//save ini settings, etc

	delete MessagePump;
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::FormKeyDown(TObject *Sender, WORD &Key,
	  TShiftState Shift)
{
	if (Key == VK_CAPITAL && Shift.Contains(ssAlt))
		if (form_last_viewed)
			form_last_viewed->SetFocus();
}
//---------------------------------------------------------------------------

void TMainForm::activateTimerFeatures()
{
	//Activates and deactivates whether Timer functionality is available

	if (IniOpt->getValueInt("timer_active"))
	{
		//icons
		AddTimer->Visible = true;
		RunningDude->Visible = true;
		HideContacts->Visible = true;
		HideTimerNames->Visible = true;
		HideTimerDigits->Visible = true;
		HideTimerIcons->Visible = true;

		Contacts->Align = alLeft;
		Contacts->Left = 0;
		Contacts->Width = 80;
		Splitter1->Left = 81;
		TimersList->Left = 84;
		//TimersList->Align = alClient;
		Splitter1->Visible = true;
		TimersList->Visible = true;
	}
	else
	{
		//icons
		AddTimer->Visible = false;
		RunningDude->Visible = false;
		HideContacts->Visible = false;
		HideTimerNames->Visible = false;
		HideTimerDigits->Visible = false;
		HideTimerIcons->Visible = false;

		//TimersList->Align = alNone;
		TimersList->Visible = false;
		Splitter1->Visible = false;
		Contacts->Align = alClient;
	}

}
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//	METHODS TO MANAGE FORM GEOMETRY AND FORM REPAINT
//---------------------------------------------------------------------------

void __fastcall TMainForm::FormConstrainedResize(TObject *Sender,
      int &MinWidth, int &MinHeight, int &MaxWidth, int &MaxHeight)
{
	//this event happens when form is about to be resized (before resize)

	/* TO REEXPOSE TIMER PANELS DO THE FOLLOWING
		1. Reexpose code as described in other ToDo's below
		2. Make TimersList->Align = alLeft -- at design time (Obj Inspector)
		3. Make visible: Spliter1, TimersList, applicable toolbar icons (design)
		4. Set ImOn->Left = 30  (design time)
		5. Options and RunningDune should exchange Left values (design time)

	/* REEXPOSE FOLLOWING CODE FOR TIMERS REACTIVATION */
				//AND RESTORE LAST LINE TO "MinWidth = 120;"

	if (IniOpt->getValueInt("timer_active"))
	{
		//for continuously measuring width of timer pames
		int timerdigits_w = (hidden_timer_panes[1] ?
						0 : (TIMER_DIGITS_WIDTH + SPACE_AFTER_DIGITS));
		int timericons_w = (hidden_timer_panes[2] ? 0 : TIMER_ICONS_WIDTH);

		if (hidden_timer_panes[0] && hidden_timer_panes[1] && hidden_timer_panes[2])
			MinWidth = 120;
		else
			MinWidth = Contacts->Width + 12 + timerdigits_w + timericons_w;

		if (MinWidth < 120)
			MinWidth = 120;		//should be 120 while Timer panes are active
	}
	else
		MinWidth = 60;			//should be ~60 when Timer panes are inactive
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::FormResize(TObject *Sender)
{
	//this event happens after form is resized

	if (IniOpt->getValueInt("timer_active"))
	{
		no_timer_update = true;

		//guarantee minimum size when all timer panes are hidden
		if (hidden_timer_panes[0] && hidden_timer_panes[1] && hidden_timer_panes[2])
		{
			Contacts->Width = this->Width - 12;
			contacts_width = Contacts->Width;	//so splitter will know new position
		}

		//for continuously measuring width of timer pames
		int timerdigits_w = (hidden_timer_panes[1] ?
						0 : (TIMER_DIGITS_WIDTH + SPACE_AFTER_DIGITS));
		int timericons_w = (hidden_timer_panes[2] ? 0 : TIMER_ICONS_WIDTH);
		int timernames_w = TimersList->Width - timerdigits_w - timericons_w;

		//update timernames_width only if not hidden, so it'll remember when hidden
		if (!hidden_timer_panes[0])
			timernames_width = timernames_w;

		//when user manually hides timer panes, coordinate with Hide buttons:
		if (!hidden_timer_panes[0] && timernames_w <= 5)
		{
			timernames_width = 50;		//arbitrary value that will restore to
			HideTimerNames->Picture = ShowArrow->Picture;
			hidden_timer_panes[0] = true;
		}
		else if (hidden_timer_panes[0] && timernames_w > 5)
		{
			HideTimerNames->Picture = HideArrow->Picture;
			hidden_timer_panes[0] = false;
		}

		//guarantee position of arrow icons
		//should be automatic, but is not always, so this is needed
		HideTimerNames->Left = Width - 52;
		HideTimerDigits->Left = Width - 37;
		HideTimerIcons->Left = Width - 22;

		//manage the toolbar
		if (Options->Left > HideTimerNames->Left - 36)
		{
			Panel1->Height = 42;
			HideContacts->Left = 5;
			HideContacts->Top = 24;
			HideTimerNames->Top = 24;
			HideTimerDigits->Top = 24;
			HideTimerIcons->Top = 24;
		}
		else
		{
			Panel1->Height = 22;
			HideContacts->Left = 96;
			HideContacts->Top = 4;
			HideTimerNames->Top = 4;
			HideTimerDigits->Top = 4;
			HideTimerIcons->Top = 4;
		}

		no_timer_update = false;
		TimersList->Refresh();
	}
	else		//when timer functionality is not available
	{
		Panel1->Height = 22;	//fixed height, since resize arrows don't show
	}

	keepWithinScreen();		//always adjust position so some of it is not hidden
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::ContactsDrawItem(TWinControl *Control,
	  int Index, TRect &Rect, TOwnerDrawState State)
{

	map<string, T3Message>::iterator it;				//who is on?
	it = pUserCollection->find(Contacts->Items->Strings[Index].c_str());

	multimap<string, T3Message>::iterator mess_it;	//who has sent messages?
	mess_it = pMessageBuffer->find(Contacts->Items->Strings[Index].c_str());
	bool has_message = (mess_it != pMessageBuffer->end());


	int i;
	if (it->second.getAttribute("status") == "IMON" )
	{
		i = (has_message && blink) ? 2 : 0;
		if (i != 2 && !online) i = 3;		//!=2 so it will still blink offline
	}
	else if (it->second.getAttribute("status") == "IMBUSY" )
	{
		i = (has_message && blink) ? 2 : 4;
		if (i != 2 && !online) i = 3;
	}
	else	//status == "IMOFF"
	{
		i = (has_message && blink) ? 2 : 1;
		if (i != 2 && !online) i = 3;
	}

	ContactsGlyphs->Draw(Contacts->Canvas, Rect.Left + 2, Rect.Top + 2, i, true);
	Contacts->Canvas->TextOut(Rect.Left + ContactsGlyphs->Width + 6, Rect.Top + 3,
		Contacts->Items->Strings[Index]);        // and write the text to its right


	//hide automatic outline of selected item
	Contacts->Canvas->Font->Color = clBlack;				//will auto-invert
	Contacts->Canvas->Brush->Style = bsClear;				//no show
	Contacts->Canvas->TextOut(Rect.Left, Rect.Top, "");		//last text out
	Contacts->Canvas->Brush->Style = bsSolid;				//restore


	//code to draw a bitmap from a file -- not currently used
	//Graphics::TBitmap* BitMap = new Graphics::TBitmap();
	//BitMap->LoadFromFile("bitmaps/NotAvailable.bmp");
	//Contacts->Canvas->Draw(Rect.Left + 2, Rect.Top + 2, BitMap); // draw the bitmap
	//delete BitMap;

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::TimersListDrawItem(TWinControl *Control,
	  int Index, TRect &Rect, TOwnerDrawState State)
{
	if (no_timer_update)
		return;						//do not repaint timer panes

	const int indent1 = SPACE_BEFORE_NAMES;			//lm for timer names
	const int indent2 = (hidden_timer_panes[2]) ?   //lm for timer digits:
			TimersList->Width - TIMER_DIGITS_WIDTH - 2 * SPACE_AFTER_DIGITS :
			TimersList->Width - DIGITS_PLUS_ICONS;

	const int indent3 = TimersList->Width - TIMER_ICONS_WIDTH;	//lm timer icons
	const int digitbar = TIMER_DIGITS_WIDTH;		//width of digits blocl

	//locate the Timer that the display is updating
	string name = TimersList->Items->Strings[Index].c_str();

	if ( m_tmrmgr.isTimerActive(name) )
		TimersList->Canvas->Font->Color = clRed;	//paint in red if active timer
	//else
	//	TimersList->Canvas->Font->Color = clBlack;	//not used - uses defaults

	//TimersList->Canvas->Brush->Color = clWhite;	//to hide selected item bkgd

	//write the names of the timers
	if (!hidden_timer_panes[0])
	{
		TimersList->Canvas->TextOut(Rect.Left + indent1, Rect.Top + 10,
									TimersList->Items->Strings[Index]);
	}

	//retrieve elapsed time, calculate space needed, and write digital time:
	if (!hidden_timer_panes[1])
	{
		TimersList->Canvas->Font->Size = 18;
		String display = m_tmrmgr.getElapsedTime(name).c_str();	//digital elapsed time
		int digits_indent = digitbar - TimersList->Canvas->TextWidth(display);

		TimersList->Canvas->Brush->Color = clWhite;		//hide selection bar for digits

		if (!m_tmrmgr.isTimerActive(name))
		{                                               //so do not write in red
			if (Index == TimersList->ItemIndex)
				TimersList->Canvas->Font->Color = clBlue;
			else
				TimersList->Canvas->Font->Color = clBlack;
		}
		else if (Index == TimersList->ItemIndex)
		{
			if ( m_tmrmgr.isTimerHalfTime(name) )
				TimersList->Canvas->Font->Color = clYellow;
			else
				TimersList->Canvas->Font->Color = clFuchsia;
		}

		TimersList->Canvas->Pen->Color = clWhite;
		TimersList->Canvas->Rectangle(Rect.Left + indent2, Rect.Top, 
									  Rect.Right, Rect.Bottom);
								//clear to end
		TimersList->Canvas->TextOut(Rect.Left + indent2 + digits_indent, 
									Rect.Top + 2, display);
								// and write right-justified digital display
	}

	//paint the timer icons (clock faces or timer bar):
	if (!hidden_timer_panes[2])
	{
	Rect.Left += indent3;
	TimersList->Canvas->Font->Size = 10;
	//clear the space first
	TimersList->Canvas->Brush->Color = clWhite;
	TimersList->Canvas->Pen->Color = clWhite;
	TimersList->Canvas->Rectangle(Rect.Left, Rect.Top, 
								  Rect.Right, Rect.Bottom);
	TimersList->Canvas->Pen->Color = clBlack;

	int minutes = m_tmrmgr.getTimerMinutes(name);
	int hours = m_tmrmgr.getTimerHours(name); 
	/*
	if (it->second.getShowBar())		//draw display for progressive bar mode
	{
		TimersList->Canvas->Rectangle(Rect.Left + 6, Rect.Top + 6,
								Rect.Left + 182, Rect.Top + 26);
		TimersList->Canvas->Brush->Color = clYellow;
		TimersList->Canvas->Pen->Color = clYellow;

		int max_hours = it->second.getMaxHourBar();
		float hours_bar;
		if (it->second.getHours() < max_hours)
		{
			hours_bar = it->second.getHours() + 
						(float) it->second.getMinutes()/60;
		}
		else
		{
			hours_bar = max_hours;		//total hours on bar may not exceed max
		}

		hours_bar = ( hours_bar * (180-7) ) / max_hours;	//scale to pixels

		TimersList->Canvas->Rectangle(Rect.Left + 7, Rect.Top + 7,
								Rect.Left + 7 + hours_bar, Rect.Top + 25);

		TimersList->Canvas->Brush->Color = clWhite;
		TimersList->Canvas->Brush->Style = bsClear;
		TimersList->Canvas->Pen->Color = clBlack;
		TimersList->Canvas->Font->Color = clBlack;

		//max hours display
		String digit_max = max_hours;
		digit_max += ":00";
		TimersList->Canvas->TextOut(Rect.Left + 178 - TimersList->Canvas->TextWidth(digit_max),
							Rect.Top + 8, digit_max);

	}
	else		//draw the clock icons
	{
	*/

		TImageList* HoursClocks;
		TImageList* MinutesClocks;

		if (m_tmrmgr.isTimerActive(name) )
		{
			HoursClocks = HoursRed;
			MinutesClocks = MinutesRed;
		}
		else
		{
			HoursClocks = HoursBlack;
			MinutesClocks = MinutesBlack;
		}


		int five_hrs = hours / 5;
		if (five_hrs > 10) five_hrs = 11;		//after 50 hrs display + clock face
			//note: to show past 50hrs, add more icons and simply edit above line
		int one_hrs = hours % 5;
		int quarter_hrs = (minutes - 1) / 15;
		if (minutes <= 0 || minutes >= 60) 
			quarter_hrs = -1;

		int left_pos = Rect.Left + 2;


		if (five_hrs > 0)						//draw 5-hour clock icon
		{
			HoursClocks->Draw(TimersList->Canvas, left_pos, Rect.Top, 
							  five_hrs, true);
			left_pos += HoursClocks->Width;
		}

		for (int i = 0; i < one_hrs; i++)		//draw 1-hour clock icons
		{
			HoursClocks->Draw(TimersList->Canvas, left_pos, 
							  Rect.Top, 0, true);
			left_pos += HoursClocks->Width;
		}

		if (quarter_hrs != -1)
		{
			MinutesClocks->Draw(TimersList->Canvas, left_pos, 
								Rect.Top, quarter_hrs, true);
		}
	//}
	}	//end paint timer icons

	//hide automatic outline of selected item
	TimersList->Canvas->Font->Color = clBlack;				//will auto-invert
	TimersList->Canvas->Brush->Style = bsClear;				//no show
	TimersList->Canvas->TextOut(Rect.Left, Rect.Top, "");	//last text out
	TimersList->Canvas->Brush->Style = bsSolid;				//restore

	return;
}

//---------------------------------------------------------------------------
void __fastcall TMainForm::StatBarDrawPanel(TStatusBar *StatusBar,
	  TStatusPanel *Panel, const TRect &Rect)
{
	//OnDraw event for Status Bar

	if (status1 == CONNECTING_TO_SERVER || status1 == CONNECT_ERROR_STATUS)
		StatBar->Canvas->Font->Color = clRed;
	else
		StatBar->Canvas->Font->Color = clBlack;

	StatBar->Canvas->Font->Name = "Arial";
	StatBar->Canvas->Font->Size = 8;

	int status2_indent = StatBar->Width - StatBar->Canvas->TextWidth(status2) - 20;
	StatBar->Canvas->TextOut(Rect.left + status2_indent, Rect.top, status2);
	StatBar->Canvas->TextOut(Rect.left + 3, Rect.top, status1);

}
//---------------------------------------------------------------------------
void __fastcall TMainForm::HideContactsClick(TObject *Sender)
{

	if (Contacts->Width > 1)
	{
		if (!canNixWidth(true)) return;
		Contacts->Width = 1;
		Splitter1Moved(Sender);		//act as if splitter had moved
	}
	else
	{
		Contacts->Width = contacts_width;
		Splitter1Moved(Sender);		//act as if splitter had moved
	}

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::HideTimersClick(TObject *Sender)
{
	no_timer_update = true;		//prevents items from dancing all over the place

	TImage* arrow;
	arrow = (TImage*) Sender;

	//hide or show pane
	hidden_timer_panes[arrow->Tag] = !hidden_timer_panes[arrow->Tag];

	int width_change;
	if (arrow->Tag == 0)
		width_change = timernames_width;
	else if (arrow->Tag == 1)
		width_change = TIMER_DIGITS_WIDTH + SPACE_AFTER_DIGITS;
	else if (arrow->Tag == 2)
		width_change = TIMER_ICONS_WIDTH - SPACE_AFTER_DIGITS;

	if (hidden_timer_panes[arrow->Tag])		//this pane is now hidden
	{                                       //so reduce form size
		if (canNixWidth(false))
		{
			MainForm->Width -= width_change;
			arrow->Picture = ShowArrow->Picture;
		}
		else	//abort -- roll back hidden status
			hidden_timer_panes[arrow->Tag] = !hidden_timer_panes[arrow->Tag];
	}
	else									//this pane is now showing
	{                                       //so increase form size
		MainForm->Width += width_change;
		arrow->Picture = HideArrow->Picture;
	}

	no_timer_update = false;
	TimersList->Refresh();
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::Splitter1Moved(TObject *Sender)
{
	static bool was_hidden = false;

	if (Contacts->Width == 0)
	{
		Contacts->Width = 1;	//disallow 0 size because it messes up controls
	}
	else if (Contacts->Width == 1)
	{
		MainForm->Width -= (contacts_width - 1);
		HideContacts->Picture = ShowArrow->Picture;
		was_hidden = true;
	}
	else
	{
		if (was_hidden)
			MainForm->Width += (Contacts->Width - 1);	//restore from hidden
		else if (hidden_timer_panes[0] && hidden_timer_panes[1]
					&& hidden_timer_panes[2] && Contacts->Width < this->Width - 12)
			Contacts->Width = contacts_width;	//revert, cannot be < min width
		else
			MainForm->Width += (Contacts->Width - contacts_width);

		contacts_width = Contacts->Width;	//remember this position for next call
		HideContacts->Picture = HideArrow->Picture;
		was_hidden = false;
	}

	//TimersList->Refresh();
}
//---------------------------------------------------------------------------

bool TMainForm::canNixWidth (bool caller_is_talker)
{
	bool can;

	if (caller_is_talker)
	{
		can = !(hidden_timer_panes[0] && hidden_timer_panes[1]
									&& hidden_timer_panes[2]);
	}
	else	//caller is timer
	{
		can = !(hidden_timer_panes[0] && hidden_timer_panes[1]
				&& hidden_timer_panes[2] && Contacts->Width == 1);
	}

	if (!can)
		ShowMessage("At least one panel must remain visible.");

	return can;
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::TimersListMouseMove(TObject *Sender,
	  TShiftState Shift, int X, int Y)
{
	//called both by Contacts and Timers lists
												
	TListBox* WhatList = (TListBox*) Sender;

	int item_number = (Y / WhatList->ItemHeight) +
								getScrollPosition(WhatList->Handle);

	String empty = "";
	String temp_str = empty;

	if (item_number < WhatList->Items->Count)
	{
		if (WhatList == TimersList)
			temp_str = WhatList->Items->Strings[item_number];
		else	//if contacts
		{
			map<string, T3Message>::iterator it;
			it = pUserCollection->find(Contacts->Items->Strings[item_number].c_str());
			if (it != pUserCollection->end())
				temp_str = it->second.getContent().c_str();
		}
	}
	else
		temp_str = empty;

	status2 = (WhatList == TimersList) ? temp_str : empty;		//show on right
	if (status1 != CONNECTING_TO_SERVER)
		status1 = (WhatList == TimersList) ? empty : temp_str;	//show on left
	//setting both prevents the two statuses from drawing over each other

	//this clears the status as the mouse leaves the control (outer 5 pixls)
	//this is redundant since TTimer Blinker also does it, but this makes it
	//a bit faster sometimes  (and this alone would not always work)
	if (X < 5 || X > (WhatList->Width - 10) || Y < 5 || Y > (WhatList->Height - 10))
	{
		status2 = empty;
		if (status1 != CONNECTING_TO_SERVER)
			status1 = empty;
	}

	StatBar->Refresh();
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::BlinkerTimer(TObject *Sender)
{
	//fast timer (< 0.5 secs) to do any interface updates needing quick refresh

	have_messages = !pMessageBuffer->empty();

	//process any status messages that may exist
	if (!pStatusBuffer->empty())
	{
		map<string, T3Message>::iterator it;
		for (it = pStatusBuffer->begin(); it != pStatusBuffer->end(); )
		{
			//if we still don't have first message id, get it now if available
			if (message_base_id == 0x0ui64 && 
				it->second.getAttribute("status") == "ID")
			{
				string id_value = it->second.getAttribute("id");
				if (id_value.empty())
					id_value = "0";

				if (!(istringstream(id_value) >> hex >> message_base_id))
					message_base_id = 0x0ui64;	//if assignment fails, guarantee 0

				pStatusBuffer->erase(it++);

				//we now have id, so immediately issue IMON
				sendStatusMessage(available ? "IMON" : "IMBUSY");
			}
			else
				++it;

			//else if () -- add here other statuses that may need processing

		}
	}


	// true once for every communication event
	if (MessagePump->thread_finished)	
	{

		//update status bar
		status1 = "";
		StatBar->Refresh();

		//keep contacts display updated, since it can change w/ ea comm
		doContactMaintenance();

		MessagePump->thread_finished = false;	//rearm for next comm use

		//next code needs to be after above because it may start another comm
		//this 'if' is only meaningful during shutdown when UtilityDialog is up
		if (busy_on_shut_down) //don't close it yet, pending comm just ended
		{
			busy_on_shut_down = false;		//dialog will close after next comm
			sendStatusMessage("IMOFF");		//which we need to regenerate
		}
		else if (MessagePump->SendBuffer.empty())
			UtilityDialog->ModalResult = mrOk;
		else
			UtilityDialog->ModalResult = mrCancel;
	}


	blink = !blink;

	if (have_messages)
	{
		//there's messages, so application icon blinks
		int bOn = (blink ? 1 : 0);
		TimerIcons->GetIcon(bOn, Application->Icon);
		Contacts->Refresh();
	}
	else												//no messages
	{
		const string name = m_tmrmgr.getActiveTimer();
		if ( !name.empty() )
		{
			TimerIcons->GetIcon(1, Application->Icon);
		}
		else
		{
			TimerIcons->GetIcon(0, Application->Icon);
		}
	}


	//if so selected, play sound to indicate if recvd messages are in buffer
	static int usecs_since_last_sound = 0;
	if (have_messages && IniOpt->getValue("sound_none") == "0")
	{
		if (usecs_since_last_sound == 0)
			playSound();					//first upon message receipt
		usecs_since_last_sound += Blinker->Interval;
		int ini_usecs = 1000 * IniOpt->getValueInt("sound_interval", 180);
		if (ini_usecs != 0  &&  usecs_since_last_sound >= ini_usecs)
		{
			//play sound
			playSound();
			usecs_since_last_sound = 1;		//1 to distinguish from 0 (initial)
		}
	}
	else
		usecs_since_last_sound = 0;



	//also use this TTimer to clean the status bar from mouse hover hangovers
	if (Mouse->CursorPos.x < Left || Mouse->CursorPos.x > (Left + Width) ||
		Mouse->CursorPos.y < (Top + Panel1->Height + 20) ||
		Mouse->CursorPos.y > (Top + Height - StatBar->Height) )
	{
		if (status1 != CONNECTING_TO_SERVER)
			status1 = "";
		status2 = "";
	}
	StatBar->Refresh();
}
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//	METHODS RELATING TO TIMER INTERFACE
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuNewTimerClick(TObject *Sender)
{
	// starts a timer
	TNewTimer* dlg = new TNewTimer(this, m_tmrmgr, "", "START");
	dlg->Caption = T3Caption().c_str() + AnsiString(" - New Timer");
	dlg->ActiveControl = dlg->TimerName;
	dlg->ShowModal();
	delete dlg;

	// could have cancelled and still gotten ping info
	doTimerMaintenance();
	updateClocks();

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuFullTimeClick(TObject *Sender)
{
	int idx = TimersList->ItemIndex;
	if ( idx > -1 ) 
	{
		string name = TimersList->Items->Strings[idx].c_str();
		if ( !m_tmrmgr.startTimer(name, false) )
		{
			string msg = "The server responded with\n\n" + 
						  m_tmrmgr.getLastError();
			string cpt = T3Caption() + " - Timer Error";
			Application->MessageBox(msg.c_str(), cpt.c_str(), 
									MB_OK | MB_ICONERROR);
		}

		doTimerMaintenance();
		updateClocks();
	}

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuHalfTimeClick(TObject *Sender)
{
	int idx = TimersList->ItemIndex;
	if ( idx > -1 ) 
	{
		string name = TimersList->Items->Strings[idx].c_str();
		if ( !m_tmrmgr.startTimer(name, true) )
		{
			string msg = "The server responded with\n\n" + 
						  m_tmrmgr.getLastError();
			string cpt = T3Caption() + " - Timer Error";
			Application->MessageBox(msg.c_str(), cpt.c_str(), 
									MB_OK | MB_ICONERROR);
			ShowMessage(m_tmrmgr.getLastError().c_str());
		}

		doTimerMaintenance();
		updateClocks();
	}

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuTotalTimerClick(TObject *Sender)
{
	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuBreakdownTimerClick(TObject *Sender)
{
	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuCancelTimerClick(TObject *Sender)
{
	int idx = TimersList->ItemIndex;
	if ( idx > -1 ) 
	{
		string name = TimersList->Items->Strings[idx].c_str();
		string msg = "Are you sure you want to cancel Timer " +
						name + "?";
		string cpt = T3Caption() + " - Timer Cancel";
		if ( Application->MessageBox(msg.c_str(), cpt.c_str(), 
									 MB_YESNO | MB_ICONQUESTION) == mrYes )
		{
			if ( !m_tmrmgr.cancelTimer(name) )
			{
				string msg = "The server responded with\n\n" + 
							  m_tmrmgr.getLastError();
				string cpt = T3Caption() + " - Timer Error";
				Application->MessageBox(msg.c_str(), cpt.c_str(), 
										MB_OK | MB_ICONERROR);
				ShowMessage(m_tmrmgr.getLastError().c_str());
			}

			doTimerMaintenance();
			updateClocks();
		}
	}

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuDoneTimerClick(TObject *Sender)
{
	int idx = TimersList->ItemIndex;
	if ( idx > -1 ) 
	{
		string name = TimersList->Items->Strings[idx].c_str();
		TNewTimer* dlg = new TNewTimer(this, m_tmrmgr, name, "DONE");
		dlg->TimerName->Enabled = false;
		dlg->Caption = T3Caption().c_str() + AnsiString(" - Done Timer");
		dlg->ActiveControl = dlg->TimerClient;
		dlg->ShowModal();
		delete dlg;

		// could have cancelled and still gotten ping info
		doTimerMaintenance();
		updateClocks();
	}

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuPauseTimerClick(TObject *Sender)
{
	int idx = TimersList->ItemIndex;
	if ( idx > -1 ) 
	{
		string name = TimersList->Items->Strings[idx].c_str();
		if ( m_tmrmgr.pauseTimer(name) )
		{
			TimersList->Items->Move(idx, 0);

			TimerIcons->GetIcon(0, Application->Icon);
			TimerIcons->GetIcon(0, MainForm->Icon);
		}
		else
		{
			string msg = "The server responded with\n\n" + 
						  m_tmrmgr.getLastError(); 
			string cpt = T3Caption() + " - Timer Error";
			Application->MessageBox(msg.c_str(), cpt.c_str(), 
									MB_OK | MB_ICONERROR);
		}

		doTimerMaintenance();
		updateClocks();
	}

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuLogTimerClick(TObject *Sender)
{
	// logs a timer
	TNewTimer* dlg = new TNewTimer(this, m_tmrmgr, "", "LOG");
	dlg->TimerName->Text = "LOG_TIMER";
	dlg->TimerName->Enabled = false;
	dlg->Caption = T3Caption().c_str() + AnsiString(" - Log Timer");
	dlg->ActiveControl = dlg->TimerClient;
	dlg->ShowModal();
	delete dlg;

	// could have cancelled and still gotten ping info
	doTimerMaintenance();
	updateClocks();

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuRenameClick(TObject *Sender)
{
	int idx = TimersList->ItemIndex;
	if ( idx > -1 ) 
	{
		string name = TimersList->Items->Strings[idx].c_str();

		// renames a timer
		TNewTimer* dlg = new TNewTimer(this, m_tmrmgr, name, "RENAME");
		dlg->Caption = T3Caption().c_str() + AnsiString(" - Rename Timer");
		dlg->ActiveControl = dlg->TimerName;
		dlg->ShowModal();
		delete dlg;

		// could have cancelled and still gotten ping info
		doTimerMaintenance();
		updateClocks();
	}

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuUseBarsClick(TObject *Sender)
{
	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuBarMaxHoursClick(TObject *Sender)
{
	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::mnuUpdateClick(TObject *Sender)
{
	// update now
	m_tmrmgr.pingServer();
	doTimerMaintenance();
	updateClocks();

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::TimersListClick(TObject *Sender)
{
	TimersList->Refresh();
	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::SystemTimerTimer(TObject *Sender)
{
	//every minute update the current timer if one exists
	m_tmrmgr.addMinute();
    doTimerMaintenance();
	updateClocks();

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::RunningDudeClick(TObject *Sender)
{
	SystemTimer->Interval = (SystemTimer->Interval == 60000) ? 600 : 60000;
}
//---------------------------------------------------------------------------
//clears display when no timer is selected
void TMainForm::ClearDisplay()
{
	// not needed -- unused for now
}
//---------------------------------------------------------------------------
void TMainForm::updateClocks ()
{
	//causes a repaint
	TimersList->Refresh();
	
	const string name = m_tmrmgr.getActiveTimer();
	if ( !name.empty() ) 
	{
		Application->Title = String(T3Caption().c_str()) +  " " +
									m_tmrmgr.getElapsedTime(name).c_str();
		MainForm->Caption = String(T3Caption().c_str()) + " - " + name.c_str();
	}
	else
	{
		// no active timer
		MainForm->Caption = AnsiString(T3Caption().c_str()) + " - " +
					AnsiString(IniOpt->getValue("user_name").c_str());
		Application->Title = MainForm->Caption;
	}

	return;
}
//---------------------------------------------------------------------------
void TMainForm::doTimerMaintenance ()
{
	if ( m_tmrmgr.isNewDataAvail() )
	{
		StringList tmrlist = m_tmrmgr.getTimerNames();

		//delete from display any timers that are no longer pertinent 
		for (int i = 0; i < TimersList->Items->Count; i++)
		{
			if ( tmrlist.IndexOf(TimersList->Items->Strings[i].c_str()) < 0 )
			{
				TimersList->Items->Delete(i);
				--i;
			}
		}

		// add any timers not in our display
		for (int i = 0; i < tmrlist.Count(); ++i ) 
		{
			string name = tmrlist.String(i);
			int idx = TimersList->Items->IndexOf(name.c_str());
			if ( idx < 0 )
			{
				//add to contact display any contacts not yet there
				TimersList->Items->Add(name.c_str());
			}
		}

		// clear the new data avail
		m_tmrmgr.clearNewDataAvail();
	}

	return;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::TimersListMouseDown(TObject *Sender,
	  TMouseButton Button, TShiftState Shift, int X, int Y)
{

	int idx = Y / 32;
	idx = idx + TimersList->TopIndex;
	if (Button == mbRight)		//open TimerActionfForm
	{
		TPopupMenu* mnu;
		if (idx < TimersList->Items->Count)		//clicked on a timer
		{
            // select this timer
			TimersList->ItemIndex = idx;

			// needed so that two items don't look selected
			TimersList->Refresh();

			// popup Command menu
			mnu = mnuTimerCmd;

			// setup menu reflect "selected" timer
			string name = TimersList->Items->Strings[idx].c_str();
			bool act = m_tmrmgr.isTimerActive(name);
			bool hlf = m_tmrmgr.isTimerHalfTime(name);
			mnuPauseTimer->Enabled = act;
			mnuFullTime->Enabled = !act || (hlf && act);
			mnuHalfTime->Enabled = !act || (!hlf && act);
		}
		else	
		{
			// popup the TimerNew menu
			mnu = mnuTimerNew;
		}

		// pop up the menu
		TPoint p(X,Y);
		p = TimersList->ClientToScreen(p);
		mnu->Popup(p.x, p.y);
	}
	else if (Button == mbLeft)		
	{
		//toggle between clock icons and hours bar
		if (idx < TimersList->Items->Count && !hidden_timer_panes[2]
								&& X > TimersList->Width - 190)
		{
			//map<string, Timer>::iterator it;
			//it = TimerCollection.find(TimersList->Items->Strings[idx].c_str());
			//it->second.setShowBar(!it->second.getShowBar());
			//updateClocks();		//refresh already done by OnClick
		}
		else if (idx > TimersList->Items->Count - 1)
		{
			//but if clicking outside a timer, just deselect
			TimersList->ItemIndex = -1;
		}

		TimersList->Refresh();
	}


	return;
}
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//      SOME METHODS FOR TESTING STUFF DURING DEVELOPMENT
//---------------------------------------------------------------------------

void __fastcall TMainForm::TestButtonClick(TObject *Sender)
{
	//Just for Testing Stuff

	//Message new_message("Jay", "", "IMON", "A very\n fine\n day");
	//ShowMessage(new_message.toXML());
	//Message newer_message(new_message.toXML());
	//ShowMessage(newer_message.message_text);

	//for (int i = 0; i < Application->ComponentCount; i++)
	//	ShowMessage(Application->Components[i]->Name);

	/*
	String Testme = "Today <and> tomorrow <<< \"\" are mighty \"fine\" days";
	ShowMessage(Testme);
	Message mess1;
	mess1.xmlEscape(Testme);
	ShowMessage(Testme);
	mess1.xmlUnEscape(Testme);
	ShowMessage(Testme);
	*/
					/*
	String TestMe = "<MESSAGE from=\"Frog\" to=\"Lizz\" location=\"here >now\">Hey<BOLD> <A a=\"cr\">xxx</A>There</MESSAGE>";
	//String TestMe = "<MESSAGE>Hey There</MESSAGE>";
	Message mess1;

	TStringList* attrs = new TStringList;
	String content;
	mess1.parseXmlElement(TestMe, attrs, content);
	for (int i = 0; i < attrs->Count; i++)
    {
		ShowMessage(String('*') + attrs->Strings[i] + '*');
	}
	ShowMessage(String('*') + content + '*');

	delete attrs;  */

	//ShowMessage(getScrollPosition(Contacts->Handle));
	//setScrollPosition(Contacts->Handle, 1);

	//ShowMessage("Before Thread");
	//TransferThread *test = new TransferThread(false);
	//ShowMessage("After Thread");

}
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//      METHODS RELATING TO TALKER INTERFACE
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

void __fastcall TMainForm::ContactsClick(TObject *Sender)
{
	//causes a repaint of contacts in talker pane without the funny outlines
	if (Contacts->Items->Count > 0)
		Contacts->Items->Strings[0] = Contacts->Items->Strings[0];
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::ContactsDblClick(TObject *Sender)
{
	openMessageForm(Contacts->ItemIndex);

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::ContactsMouseDown(TObject *Sender,
	  TMouseButton Button, TShiftState Shift, int X, int Y)
{
	if (Button == mbRight)		
	{
		// open MessageActionfForm
		int item_number = Y / 20;	
		openMessageForm(item_number);
	}

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::ContactsKeyDown(TObject *Sender, WORD &Key,
	  TShiftState Shift)
{
	if (Key == VK_RETURN || Key == VK_SPACE)
		openMessageForm(Contacts->ItemIndex);

}
//---------------------------------------------------------------------------

void TMainForm::openMessageForm (int what_item)
{
	//each call creates a new instance of the message form (deletes automatically)
	TMessageActionForm* MessageActionForm = new TMessageActionForm(Application);

	if (what_item < Contacts->Items->Count)		//clicked on a contact
	{
		//so set caption and options to reflect "selected" user
		MessageActionForm->user = Contacts->Items->Strings[what_item];
		//map<String, Message>::iterator it;
		//it = UserCollection.find(Contacts->Items->Strings[what_item]);
		//MessageActionForm->Caption = it->second.from + " - Message";
		MessageActionForm->Caption = MessageActionForm->user + " - Message";
	}
	else
	{
		//clicked, but not on a contact
		//what_item = -1;
		MessageActionForm->user = "";
		MessageActionForm->Caption = " ";
	}

	MessageActionForm->Show();	//not Modal, so it supports multi instances

}
//---------------------------------------------------------------------------

void TMainForm::readMessage (TMessageActionForm* MessageActionForm)
{
	multimap<string, T3Message>::iterator it;
	it = pMessageBuffer->find(MessageActionForm->user.c_str());

	if (it != pMessageBuffer->end())	//if there's a message from this user
	{
		MessageActionForm->TheMessage->Text = it->second.getContent().c_str();
		MessageActionForm->last_read_message = it->second;

		//display info about this message on the message form title bar -- this
		//code must come after TheMessage->Text is set (above) to prevent it
		//being overriden by the TheMessage control OnChange event
		String title_bar = "Message from ";
		title_bar += MessageActionForm->
							last_read_message.getAttribute("from").c_str();
		title_bar += " to ";
		title_bar += MessageActionForm->
							last_read_message.getAttribute("to").c_str();

		//format time
		time_t t;
		stringstream(MessageActionForm->last_read_message.getAttribute("time")) >> t;
		String messg_time = ctime(&t);
		messg_time.Delete(messg_time.Length(), 1);	//delete '\n' at the end
		title_bar += ", sent on ";
		title_bar += messg_time;

		MessageActionForm->Caption = title_bar;

		//send confirmation that message has been read
		//build status message to send out (the 'from' of received will now be 'to')
		map<string, string> attr;
		attr["id"] = it->second.getAttribute("id");
		attr["from"] = IniOpt->getValue("user_name").c_str();
		attr["to"] = it->second.getAttribute("from");
		attr["status"] = "NORMAL_READ";
		attr["location"] = IniOpt->getValue("user_location").c_str();

		T3Message trans_out("MESSAGE", attr, "");
		ferryMessage(trans_out);

		pMessageBuffer->erase(it);
	}

	//display the message subject/thread:
	String tempstr = MessageActionForm->
							last_read_message.getAttribute("subject").c_str();

	if (int loc = tempstr.Pos(">>"))
		tempstr.Insert(" ", loc);

	MessageActionForm->Topic->Text = tempstr;


}
//---------------------------------------------------------------------------

bool TMainForm::sendMessage (TMessageActionForm* MessageActionForm, int what_item,
								String what_users_to)
{
	//send a message

	/* TODO 4 -cTalker :
	Simplify sendMessage() by reducing to a single arg, Message
	-- requires adding a makeMessage() method to MessageActionForm that does the stuff done here,
	then that form's send and broadcast simply passes the Message to sendMessage() */

	if (message_base_id == 0x0ui64)
	{
		ShowMessage("Messages cannot be sent yet because authentication with "
					"server is not completed. Please wait a few seconds and "
					"try again.");
		return false;		//did not send
	}

	String send_to;

	if (what_item == -1)			//-1 is for standard, clicked-on user
		send_to = MessageActionForm->user;		
	else if (what_item == -2)		//-2 is for user-to string sent by caller
		send_to = what_users_to;
	else
		send_to = Contacts->Items->Strings[what_item];	//caller selects user

	String subject;		//the contents of the subject (thread) attribute
	subject += MessageActionForm->Topic->Text;
	int pos = subject.Pos(">>");
	if (pos) subject = subject.SubString(1, pos - 2);

	if (MessageActionForm->ReplyLED->Visible)	//is a reply to another message
	{
		AnsiString str = MessageActionForm->
								last_read_message.getContent().c_str();
		subject += ">>";
		subject += MessageActionForm->makeTag(str);
	}

	// create an attribute list
	map<string, string> attr;
	attr["status"] = "NORMAL";
	attr["subject"] = subject.c_str();
	attr["from"] = IniOpt->getValue("user_name").c_str();
	attr["to"] = send_to.c_str();
	attr["location"] = IniOpt->getValue("user_location").c_str();

	// set the message_id
	stringstream mess_id;
	mess_id << hex << ++message_base_id;
	attr["id"] = mess_id.str().c_str();

	// set the time to now
	time_t t;
	char tstr[50];
	sprintf(tstr, "%ld", time(&t));
	attr["time"] = tstr;

	T3Message trans_out("MESSAGE", attr, 
						MessageActionForm->TheMessage->Text.c_str());
	ferryMessage(trans_out);

	return true;
}
//---------------------------------------------------------------------------

void TMainForm::broadcastMessage (TMessageActionForm* MessageActionForm)
{
	//send to all the listed contacts  -- OBSOLETE - DO NOT USE

	for (int i = 0; i < Contacts->Items->Count; i++)
		sendMessage(MessageActionForm, i, "");
}
//---------------------------------------------------------------------------

void TMainForm::sendStatusMessage (String what_status)
{
	//called by other functions to send any kind of content-free status message
	map<string, string> attr;
	//attr["id"] = "";
	//attr["to"] = "";
	attr["from"] = IniOpt->getValue("user_name").c_str();
	//attr["subject"] = "";
	attr["status"] = what_status.c_str();
	attr["location"] = IniOpt->getValue("user_location").c_str();
	T3Message trans_out("MESSAGE", attr, 
						IniOpt->getValue("user_status").c_str());

	ferryMessage(trans_out);
	return;
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::ImOnClick(TObject *Sender)
{
	//toggle on/off-line for messaging purposes

	if (IniOpt->getValue("user_name") == "")
	{
		ShowMessage("Please enter a UserName in General Options.");
		return;
	}

	online = !online;
	available = true;				//this always resets available

	MessageTimer->Enabled = online;	//ping is on only when user is on-line

	String status = online ? "LOGON" : "LOGOFF";

	sendStatusMessage(status);

	//this now only means that an update was requested -- not necessarily ack'd
	ImOn->Picture = online ? ImageOn->Picture : ImageOff->Picture;

	if (status == "LOGOFF")
		message_base_id = 0x0ui64;	//then base id is no longer valid

	doContactMaintenance();		//for immediate refresh w/o waiting for Blinker
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::ImOnMouseDown(TObject *Sender,
	  TMouseButton Button, TShiftState Shift, int X, int Y)
{
	//when on-line, right-click toggles between available and not-available

	if (Button == mbRight && online)
	{
		available = !available;

		String status = available ? "IMON" : "IMBUSY";

		sendStatusMessage(status);

		//this now only signals that status change was *requested*
		ImOn->Picture = available ? ImageOn->Picture : ImageBusy->Picture;
	}
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::MessageTimerTimer(TObject *Sender)
{
	// check to resend messages
	MessagePump->resendMessages();

	//if user is on-line, periodically issue IMON message to server
	//it is redundant since offline disables MessageTimer
	if (online)			
	{
		String status;
		status = available ? "IMON" : "IMBUSY";

		//but if there's no id, just keep sending LOGON
		if (!message_base_id) 
			status = "LOGON";

		sendStatusMessage(status);
	}


	//reset interval in case it has changed
	MessageTimer->Interval =
					IniOpt->getValueInt("server_refresh_interval", 30) * 1000;

	return;
}
//---------------------------------------------------------------------------
void TMainForm::ferryMessage (T3Message what_messg)
{
	//this is the output gateway for messages of any status that need to
	//go out.  all functions with messages to go out must call ferryMessage()

	MessagePump->initTransfer(what_messg);
	if (MessagePump->transfer_active)
	{
		status1 = CONNECTING_TO_SERVER;
		StatBar->Refresh();
	}

}
//---------------------------------------------------------------------------
void TMainForm::doContactMaintenance ()
{
	//maintemance of Contacts list to catch up with received messages, etc.
	map<string, T3Message>::const_iterator it;

	//delete from display any contacts that are no longer in collection
	for (int i = 0; i < Contacts->Items->Count; i++)
	{
		it = pUserCollection->find(Contacts->Items->Strings[i].c_str());
		if (it == pUserCollection->end())
		{
			Contacts->Items->Delete(i);
			--i;
		}
	}

	for (it = pUserCollection->begin(); it != pUserCollection->end(); it++)
	{
		//add to contact display any contacts not yet there
		if (Contacts->Items->IndexOf(it->first.c_str()) == -1)
			Contacts->Items->Add(it->first.c_str());
	}

	String last_cursor = "";	//keep track of current focus b4 rearranging items
	if (Contacts->ItemIndex > -1)
		last_cursor = Contacts->Items->Strings[Contacts->ItemIndex];

	//move to top any contacts from which a message was received
	for (it = pMessageBuffer->begin(); it != pMessageBuffer->end(); it++)
	{
		//move from current position to top position:
		int index = Contacts->Items->IndexOf(it->first.c_str());
		if ( index > -1 )
		{
			Contacts->Items->Move(index, 0);

			//and scroll to the top so it's obvious a new message arrived
			setScrollPosition(Contacts->Handle, 0);
		}
	}

	//restore item focus
	if (last_cursor != "")
		Contacts->ItemIndex = Contacts->Items->IndexOf(last_cursor);

	Contacts->Refresh();

	return;
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::OptionsClick(TObject *Sender)
{
	static int tabsheet = 0;

	if ( Sender )
	{
		TOptionsForm* dlg = new TOptionsForm(this);
    	dlg->TabOptions->ActivePageIndex = tabsheet;
		dlg->ShowModal();

        // set the new page
        tabsheet = dlg->TabOptions->ActivePageIndex;

		delete dlg;
	}

	// added this because IniOpts uses VCL stuff
	map<string, string> options;
	options["user_name"] = IniOpt->getValue("user_name");
	options["server_url"] = IniOpt->getValue("server_url");
	options["test_mode"] = IniOpt->getValue("test_mode");
	options["communication_timeout"] = IniOpt->getValue("communication_timeout");

	char str[50];
	sprintf(str, "%d", IniOpt->getValueInt("timer_ping_interval") * 60);
	options["timer_ping_interval"] = str; 
	theTimerMgr().setOptions(options);
	theTimerMgr().setPingInterval(IniOpt->getValueInt("timer_ping_interval",
													   10) * 60);


	return;
}
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//	METHODS TO MANAGE INI FILE AND EQUIVALENT MEMORY BUFFER
//---------------------------------------------------------------------------
void TMainForm::initApp ()
{
	//reads ini file and sets values accordingly
	try
	{
		IniOpt = new IniOptions(T3IniFilename().c_str());

		//General Options, other forms positions, etc. are done in respective
		//forms (MessageActionForm, OptionsForm) -- they must exist first anyway
		//set main window size and position from ini file
		if (IniOpt->getValue("mainform_left") != "")	//otherwise, it's 1st time
		{
			MainForm->Position = poDesigned;
			MainForm->Left = IniOpt->getValueInt("mainform_left", MainForm->Left);
			MainForm->Top = IniOpt->getValueInt("mainform_top", MainForm->Top);
			MainForm->Width = IniOpt->getValueInt("mainform_width", MainForm->Width);
			MainForm->Height = IniOpt->getValueInt("mainform_height", MainForm->Height);
			Contacts->Width = IniOpt->getValueInt("talker_width", Contacts->Width);
			timernames_width = IniOpt->getValueInt("timernames_width", 50);
			hidden_timer_panes[0] = IniOpt->getValueInt("hide_timer_names", 0);
			hidden_timer_panes[1] = IniOpt->getValueInt("hide_timer_digits", 0);
			hidden_timer_panes[2] = IniOpt->getValueInt("hide_timer_icons", 0);

			/*
			MainForm->Left = ini_settings->Values["mainform_left"].ToIntDef(MainForm->Left);
			MainForm->Top = ini_settings->Values["mainform_top"].ToIntDef(MainForm->Top);
			MainForm->Width = ini_settings->Values["mainform_width"].ToIntDef(MainForm->Width);
			MainForm->Height = ini_settings->Values["mainform_height"].ToIntDef(MainForm->Height);
			Contacts->Width = ini_settings->Values["talker_width"].ToIntDef(Contacts->Width);
			timernames_width = ini_settings->Values["timernames_width"].ToIntDef(50);
			hidden_timer_panes[0] = ini_settings->Values["hide_timer_names"].ToIntDef(0);
			hidden_timer_panes[1] = ini_settings->Values["hide_timer_digits"].ToIntDef(0);
			hidden_timer_panes[2] = ini_settings->Values["hide_timer_icons"].ToIntDef(0);
			*/
		}
	}
	catch(...)
	{
		IniOpt = NULL;
		ShowMessage(String("Unable to read ") + 
					String(T3IniFilename().c_str()));

		// can't continue
		::PostQuitMessage(0);
	}

	return;
}
//---------------------------------------------------------------------------

void TMainForm::cleanupApp ()
{
	//save current user list order
	String user_list;
	for (int i = 0; i < Contacts->Items->Count; i++)
    {
		user_list += Contacts->Items->Strings[i];	//concat current contacts
		if (Contacts->Items->Count > i + 1)
			user_list += ',';
	}

	// we may be in here because the Ini file failed to initialize
	if ( !IniOpt )
		return;

	bool save_to_ini = true;
	IniOpt->setValue("contact_order", user_list.c_str(), save_to_ini);
	//ini_settings->Values["contact_order"] = user_list;

	//save current size and position of main window
	IniOpt->setValueInt("mainform_left", MainForm->Left, save_to_ini);
	IniOpt->setValueInt("mainform_top", MainForm->Top, save_to_ini);
	IniOpt->setValueInt("mainform_width", MainForm->Width, save_to_ini);
	IniOpt->setValueInt("mainform_height", MainForm->Height, save_to_ini);
	IniOpt->setValueInt("talker_width", Contacts->Width, save_to_ini);
	IniOpt->setValueInt("timernames_width", timernames_width, save_to_ini);
	IniOpt->setValueInt("hide_timer_names", (int) hidden_timer_panes[0], save_to_ini);
	IniOpt->setValueInt("hide_timer_digits", (int) hidden_timer_panes[1], save_to_ini);
	IniOpt->setValueInt("hide_timer_icons", (int) hidden_timer_panes[2], save_to_ini);

	/*
	//save current size and position of main window
	ini_settings->Values["mainform_left"] = MainForm->Left;
	ini_settings->Values["mainform_top"] = MainForm->Top;
	ini_settings->Values["mainform_width"] = MainForm->Width;
	ini_settings->Values["mainform_height"] = MainForm->Height;
	ini_settings->Values["talker_width"] = Contacts->Width;
	ini_settings->Values["timernames_width"] = timernames_width;
	ini_settings->Values["hide_timer_names"] = (int) hidden_timer_panes[0];
	ini_settings->Values["hide_timer_digits"] = (int) hidden_timer_panes[1];
	ini_settings->Values["hide_timer_icons"] = (int) hidden_timer_panes[2];
	*/

	//write to file, updating current user options as well
	//ini_settings->SaveToFile(ini_filename);

	delete IniOpt;
}
//---------------------------------------------------------------------------
void TMainForm::playSound()
{
	try
	{
		SoundPlayer->FileName = T3Pathname().c_str() + SOUNDSFOLDER +
				String(IniOpt->getValue("sound_file").c_str()) + ".wav";

		SoundPlayer->Open();
		SoundPlayer->Wait = true;
		SoundPlayer->Play();

		SoundPlayer->Close();
	}
	catch(...)
	{
		;	//sound cannot play if there's no hardware, etc., so do nothing
			//unless we're in test mode:
		if ((IniOpt->getValue("test_mode") == "1"))
			ShowMessage("Unable to play sound.");
	}

}
//---------------------------------------------------------------------------

int TMainForm::getScrollPosition(HWND handle)
{
	//NOTE:  This method calls Windows API so it's not portable to Linux
	//reads the current scrolling position

	SCROLLINFO scrllinfo;

	scrllinfo.cbSize = sizeof(SCROLLINFO);
	scrllinfo.fMask = SIF_ALL;

	GetScrollInfo(handle, SB_VERT, &scrllinfo);

	return scrllinfo.nPos;

}
//---------------------------------------------------------------------------

void TMainForm::setScrollPosition(HWND handle, short int pos)
{
	//NOTE:  This method calls Windows API so it's not portable to Linux
	//sets scroll position to the value pos

					/*
	SCROLLINFO scrllinfo;

	scrllinfo.cbSize = sizeof(SCROLLINFO);
	scrllinfo.fMask = SIF_ALL;

	GetScrollInfo(handle, SB_VERT, &scrllinfo);
	//ShowMessage( scrllinfo.nPos );

	scrllinfo.nPos = pos;
	//moves the scroll bar without updating the window -- not needed:
	SetScrollInfo(ListBox1->Handle, SB_VERT, &scrllinfo, true);
					*/
	struct
	{
		short int low_word;
		short int hi_word;
	} w_param;

	w_param.low_word = SB_THUMBPOSITION;
	w_param.hi_word = pos;

	WPARAM* wpar = (WPARAM*) &w_param;

	SendMessage(handle, WM_VSCROLL, *wpar, NULL);

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::InTransitClick(TObject *Sender)
{
	InTransitForm->Show();
}
//---------------------------------------------------------------------------

