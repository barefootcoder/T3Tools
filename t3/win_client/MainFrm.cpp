//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include <fstream>

#include <time.h>
#include <sstream>

#include "MainFrm.h"
#include "NewTimr.h"
#include "TimerActionFrm.h"
#include "MessageActionFrm.h"
#include "OptionsFrm.h"
#include "TestFrm.h"


const int TIMER_DIGITS_WIDTH = 80;
const int TIMER_ICONS_WIDTH = 212;
const int SPACE_AFTER_DIGITS = 16;
const int SPACE_BEFORE_NAMES = 2;
const int DIGITS_PLUS_ICONS = TIMER_DIGITS_WIDTH + SPACE_AFTER_DIGITS
												 + TIMER_ICONS_WIDTH;

//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TMainForm *MainForm;
//---------------------------------------------------------------------------
__fastcall TMainForm::TMainForm(TComponent* Owner)
	: TForm(Owner)
{
	KeyPreview = true;		//for form to respond to keyboard events

	CurrTimer = TimerCollection.end();	//no timer is active at startup

	online = false;						//start off-line for messages
	available = true;
	blink = false;
	no_timer_update = false;

	ini_settings = new TStringList();
	readIniFile();						//read ini settings

	//set after reading ini:
	contacts_width = Contacts->Width;
	hist_buffer = new TStringList();
	hist_buffer->LoadFromFile(hist_filename);

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

	Blinker->Enabled = true;		//don't start Blinker until form is ready

	ImOnClick(ImOn);				//immediately go on-line at startup

	//if no hidden panes, create new init value (otherwise retains ini value):
	//(this will reset proper width of timer names if it gets out of whack)
	//(also called by HideTimersClick)
	if (!hidden_timer_panes[0] && !hidden_timer_panes[1] && !hidden_timer_panes[2])
		timernames_width = TimersList->Width - DIGITS_PLUS_ICONS;
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::FormClose(TObject *Sender, TCloseAction &Action)
{
	static bool dejavu = false;

	if (dejavu) return;		//this is to prevent code below to be called twice
	dejavu = true;

	//check whether there are any messages in SendBuffer
	if (!SendBuffer.empty())
	{
		TMsgDlgButtons buttons;
		buttons << mbNo << mbYes;
		int check;
		check = MessageDlg(String("Due to communication problems, the last ") +
							SendBuffer.size() + " messages "
							"you sent have not yet been delivered.\n Closing the "
							"program now will terminate all attempts to deliver "
							"these messages. \nClose Anyway?",
							mtConfirmation, buttons, 0);
		if (check != mrYes)
		{
			Action = caNone;		//do not close this form
			dejavu = false;			//so this code can be called again
			return;					//don't execute code below
		}
	}

	if (online)
		ImOnClick(ImOn);	//if user still on-line, press on/off-line button

	writeIniFile();			//save ini settings
	delete ini_settings;
	delete hist_buffer;
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

//---------------------------------------------------------------------------
//	METHODS TO MANAGE FORM GEOMETRY AND FORM REPAINT
//---------------------------------------------------------------------------

void __fastcall TMainForm::FormConstrainedResize(TObject *Sender,
      int &MinWidth, int &MinHeight, int &MaxWidth, int &MaxHeight)
{
	//this event happens when form is about to be resized (before resize)

	/* TODO : TO REEXPOSE TIMER PANELS DO THE FOLLOWING
		1. Reexpose code as described in other ToDo's below
		2. Make TimersList->Align = alLeft -- at design time (Obj Inspector)
		3. Make visible: Spliter1, TimersList, applicabel toolbar icons (design)
		4. Set ImOn->Left = 30  (design time)
		5. Options and RunningDune should exchange Left values (design time)

	/* TODO : REEXPOSE FOLLOWING CODE FOR TIMERS REACTIVATION */
				//AND RESTORE LAST LINE TO "MinWidth = 120;"
	/*
	//for continuously measuring width of timer pames
	int timerdigits_w = (hidden_timer_panes[1] ?
						0 : (TIMER_DIGITS_WIDTH + SPACE_AFTER_DIGITS));
	int timericons_w = (hidden_timer_panes[2] ? 0 : TIMER_ICONS_WIDTH);

	
	if (hidden_timer_panes[0] && hidden_timer_panes[1] && hidden_timer_panes[2])
		MinWidth = 120;
	else
		MinWidth = Contacts->Width + 12 + timerdigits_w + timericons_w;

	if (MinWidth < 120)        */
		MinWidth = 60;	//should be 120, only less while Timer panes r inactive
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::FormResize(TObject *Sender)
{
	//this event happens after form is resized

	/* TODO : REEXPOSE FOLLOWING CODE FOR TIMERS REACTIVATION */
				   Panel1->Height = 22;  //AND ERASE THIS LINE
	/*

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
		timernames_width = 50;			//arbitrary value that will restore to
		HideTimerNames->Picture = ShowArrow->Picture;
		hidden_timer_panes[0] = true;
	}
	else if (hidden_timer_panes[0] && timernames_w > 5)
	{
		HideTimerNames->Picture = HideArrow->Picture;
		hidden_timer_panes[0] = false;
	}


	//manage the toolbar
	if (Options->Left > HideTimerNames->Left - 22)
	{
		Panel1->Height = 42;
		HideTimerNames->Top = 24;
		HideTimerDigits->Top = 24;
		HideTimerIcons->Top = 24;
	}
	else
	{
		Panel1->Height = 22;
		HideTimerNames->Top = 4;
		HideTimerDigits->Top = 4;
		HideTimerIcons->Top = 4;
	}

	no_timer_update = false;
	TimersList->Refresh();              */
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::ContactsDrawItem(TWinControl *Control,
	  int Index, TRect &Rect, TOwnerDrawState State)
{

	map<String, Message>::iterator it;				//who is on?
	it = UserCollection.find(Contacts->Items->Strings[Index]);

	multimap<String, Message>::iterator mess_it;	//who has sent messages?
	mess_it = MessageBuffer.find(Contacts->Items->Strings[Index]);
	bool has_message = (mess_it != MessageBuffer.end());


	int i;
	if (it->second.status == "IMON")
	{
		i = (has_message && blink) ? 2 : 0;
		if (i != 2 && !online) i = 3;		//!=2 so it will still blink offline
	}
	else if (it->second.status == "IMBUSY")
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
	map<String, Timer>::iterator it;
	it = TimerCollection.find(TimersList->Items->Strings[Index]);

	if (it == CurrTimer)
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
		String display = it->second.getElapsedTime();	//digital elapsed time
		int digits_indent = digitbar - TimersList->Canvas->TextWidth(display);

		TimersList->Canvas->Brush->Color = clWhite;		//hide selection bar for digits

		if (it != CurrTimer)
		{                                               //so do not write in red
			if (Index == TimersList->ItemIndex)
				TimersList->Canvas->Font->Color = clBlue;
			else
				TimersList->Canvas->Font->Color = clBlack;
		}
		else if (Index == TimersList->ItemIndex)
			TimersList->Canvas->Font->Color = clFuchsia;

		TimersList->Canvas->Pen->Color = clWhite;
		TimersList->Canvas->Rectangle(Rect.Left + indent2, Rect.Top, Rect.Right, Rect.Bottom);
								//clear to end
		TimersList->Canvas->TextOut(Rect.Left + indent2 + digits_indent, Rect.Top + 2, display);
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
	TimersList->Canvas->Rectangle(Rect.Left, Rect.Top, Rect.Right, Rect.Bottom);
	TimersList->Canvas->Pen->Color = clBlack;

	if (it->second.showbar)		//draw display for progressive bar mode
	{
		TimersList->Canvas->Rectangle(Rect.Left + 6, Rect.Top + 6,
								Rect.Left + 182, Rect.Top + 26);
		TimersList->Canvas->Brush->Color = clYellow;
		TimersList->Canvas->Pen->Color = clYellow;

		int max_hours = it->second.max_hours_bar;
		float hours_bar;
		if (it->second.hours < max_hours)
		{
			hours_bar = it->second.hours + (float) it->second.minutes / 60;
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

		TImageList* HoursClocks;
		TImageList* MinutesClocks;

		if (it == CurrTimer)
		{
			HoursClocks = HoursRed;
			MinutesClocks = MinutesRed;
		}
		else
		{
			HoursClocks = HoursBlack;
			MinutesClocks = MinutesBlack;
		}


		int five_hrs = it->second.hours / 5;
		if (five_hrs > 10) five_hrs = 11;		//after 50 hrs display + clock face
			//note: to show past 50hrs, add more icons and simply edit above line
		int one_hrs = it->second.hours % 5;
		int quarter_hrs = (it->second.minutes - 1) / 15;
		if (it->second.minutes <= 0 || it->second.minutes >= 60) quarter_hrs = -1;

		int left_pos = Rect.Left + 2;


		if (five_hrs > 0)						//draw 5-hour clock icon
		{
			HoursClocks->Draw(TimersList->Canvas, left_pos, Rect.Top, five_hrs, true);
			left_pos += HoursClocks->Width;
		}

		for (int i = 0; i < one_hrs; i++)		//draw 1-hour clock icons
		{
			HoursClocks->Draw(TimersList->Canvas, left_pos, Rect.Top, 0, true);
			left_pos += HoursClocks->Width;
		}

		if (quarter_hrs != -1)
		{
			MinutesClocks->Draw(TimersList->Canvas, left_pos, Rect.Top, quarter_hrs, true);
		}
	}
	}	//end paint timer icons

	//hide automatic outline of selected item
	TimersList->Canvas->Font->Color = clBlack;				//will auto-invert
	TimersList->Canvas->Brush->Style = bsClear;				//no show
	TimersList->Canvas->TextOut(Rect.Left, Rect.Top, "");	//last text out
	TimersList->Canvas->Brush->Style = bsSolid;				//restore

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
	bool can = true;

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

	String temp_str;
	String empty = "";

	if (item_number < WhatList->Items->Count)
	{
		if (WhatList == TimersList)
			temp_str = WhatList->Items->Strings[item_number];
		else	//if contacts
		{
			map<String, Message>::iterator it;
			it = UserCollection.find(Contacts->Items->Strings[item_number]);
			temp_str = it->second.message_text;
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
	blink = !blink;

	if (!MessageBuffer.empty())
	{
		//causes a repaint of contacts -- don't use, use Refresh() instead
		//if (Contacts->Items->Count > 0)
		//	Contacts->Items->Strings[0] = Contacts->Items->Strings[0];

		//there's messages, so application icon blinks
		Application->Icon = (blink) ? TimerActionForm->Icon : NewTimer->Icon;
		Contacts->Refresh();
	}
	else												//no messages
	{
		if (CurrTimer == TimerCollection.end())
			Application->Icon = NewTimer->Icon;			//icon is always off
		else
			Application->Icon = TimerActionForm->Icon;	//or always on
	}


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

void TMainForm::addNewTimer ()
{
	//adds a new timer to collection

	//display blank-fields dialog to enter new timer information
	NewTimer->TimerName->Clear();
	NewTimer->TimerNotes->Clear();
	NewTimer->Caption = "New Timer";
	NewTimer->Height = 204;		//adjust the height to show only desired fields
	NewTimer->ActiveControl = NewTimer->TimerName;
	NewTimer->ShowModal();

	if (NewTimer->ModalResult == mrOk)
	{
		String NewTimerName = NewTimer->TimerName->Text;
		if (NewTimerName == "")			//ignore blank timer names
			return;
		int suffix = 1;
		String temp_name = NewTimerName;
		while (TimersList->Items->IndexOf(temp_name) >= 0)
		{
			temp_name = NewTimerName;
			temp_name += suffix++;	//name already exists so append 1, 2, etc.
		}
		NewTimerName = temp_name;

		//create new timer, add to collection, add to display list

		Timer new_timer(NewTimerName);
		TimerCollection.insert(make_pair(NewTimerName, new_timer));

		int insert_index;	//where on the display new timers are inserted,
							//currently at top or just below active timer.
							//this can be edited for other positions if desired,
							//but, if so, also edit setOptions()
		if (CurrTimer != TimerCollection.end())
			insert_index = 1;		//insert after active timer
		else
			insert_index = 0;		//insert at the top

		TimersList->Items->Insert(insert_index, NewTimerName);

		setOptions(insert_index);	//user-set options for this new timer

		//don't select the timer, but keep this code here in case needed later
		//TimersList->ItemIndex = TimersList->Items->IndexOf(NewTimerName);
	}

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::AddTimerClick(TObject *Sender)
{
	addNewTimer();
}
//---------------------------------------------------------------------------

void TMainForm::startTimer ()
{

	CurrTimer = TimerCollection.find(TimersList->Items->Strings[item_number]);

	TimersList->Items->Move(item_number, 0);
	item_number = 0;

	Application->Icon = TimerActionForm->Icon;	//->LoadFromFile("TimerOn.ico");
	MainForm->Icon = TimerActionForm->Icon;		//->LoadFromFile("TimerOn.ico");

	updateClocks();

}
//---------------------------------------------------------------------------

void TMainForm::stopTimer ()
{
	CurrTimer = TimerCollection.end();

	Application->Icon = NewTimer->Icon;		//->LoadFromFile("TimerOff.ico");
	MainForm->Icon = NewTimer->Icon;		//->LoadFromFile("TimerOff.ico");

	updateClocks();

}
//---------------------------------------------------------------------------

void TMainForm::doneWithTimer ()
{

	map<String, Timer>::iterator it;
	it = TimerCollection.find(TimersList->Items->Strings[item_number]);

	//show the timer details screen so user can update before logging to server

	NewTimer->TimerName->Text = it->second.name;
	NewTimer->TimerNotes->Text = it->second.description;;
	NewTimer->TimerDate->Text = DateToStr(Date());
	NewTimer->TimerHours->Text = it->second.getElapsedTime();
	NewTimer->Caption = "Save To Database";
	NewTimer->Height = 310;
	NewTimer->ActiveControl = NewTimer->TimerNotes;
	NewTimer->ShowModal();

	if (NewTimer->ModalResult == mrOk)
	{
		//Code to Save this timer to Database goes here

		//if saved without problems, remove this timer:
		cancelTimer();
	}

}
//---------------------------------------------------------------------------

void TMainForm::cancelTimer ()
{
	//removes selected timer from collection without saving anything to database

	map<String, Timer>::iterator it;
	it = TimerCollection.find(TimersList->Items->Strings[item_number]);

	if (it == CurrTimer)	//we're deleting a timer, but might be current timer
		CurrTimer = TimerCollection.end();		//if so CurrTimer is no more

	TimerCollection.erase(it);						//delete from collection

	TimersList->Items->Delete(item_number);			//delete from display

	updateClocks();

}
//---------------------------------------------------------------------------

void TMainForm::setOptions (int item_index)
{
	//sets user options for a timer
	//this method is called when the TimerActionForm closes
	//and when a new timer is added

	int what_item;	//what timer in list are these options for?
					//if -1 is passed, it's just the clicked item number:
	what_item = (item_index == -1) ? item_number : item_index;

	if (what_item >= 0 && what_item < TimersList->Items->Count)	//valid bounds
	{
		map<String, Timer>::iterator it;
		it = TimerCollection.find(TimersList->Items->Strings[what_item]);

		it->second.max_hours_bar = TimerActionForm->TimerMaxHours->Text.ToIntDef(10);

		//add other options code here as needed
	}

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::TimersListClick(TObject *Sender)
{

	TimersList->Refresh();

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::SystemTimerTimer(TObject *Sender)
{
	//every minute update the current timer if one exists

	if (CurrTimer != TimerCollection.end())
	{
		CurrTimer->second.addMinute();

		updateClocks();
	}
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
	//if (TimersList->Items->Count > 0)
	//	TimersList->Items->Strings[0] = TimersList->Items->Strings[0];

	if (CurrTimer != TimerCollection.end())
	{
		Application->Title = String("Timer ") + CurrTimer->second.getElapsedTime();
		MainForm->Caption = String("Timer - ") + CurrTimer->second.name;
	}
	else
	{
		Application->Title = "Timer";
		MainForm->Caption = "Timer";
	}

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::TimersListMouseDown(TObject *Sender,
	  TMouseButton Button, TShiftState Shift, int X, int Y)
{

	if (Button == mbRight)		//open TimerActionfForm
	{
		TListBox* WhatList = (TListBox*) Sender;

		item_number = Y / 32;

		if (item_number < TimersList->Items->Count)		//clicked on a timer
		{
			//so set caption and options to reflect "selected" timer
			map<String, Timer>::iterator it;
			it = TimerCollection.find(TimersList->Items->Strings[item_number]);
			TimerActionForm->Caption = it->second.name;
			TimerActionForm->TimerMaxHours->Text = it->second.max_hours_bar;
		}
		else
		{
			item_number = -1;					//none "selected"
			TimerActionForm->Caption = " ";
		}

		//position the action box next to the click location
		TimerActionForm->Left = MainForm->Left + WhatList->Left + X;
		TimerActionForm->Top = MainForm->Top + WhatList->Top + Y;

		//enable/disable buttons, then show the action box
		manageTimerButtons();
		TimerActionForm->ShowModal();
	}

	else if (Button == mbLeft)		
	{
		//toggle between clock icons and hours bar
		int item_index = Y / 32;
		if (item_index < TimersList->Items->Count && !hidden_timer_panes[2]
								&& X > TimersList->Width - 190)
		{
			map<String, Timer>::iterator it;
			it = TimerCollection.find(TimersList->Items->Strings[item_index]);
			it->second.showbar = !it->second.showbar;
			//updateClocks();		//refresh already done by OnClick
		}
		//but if clicking outside a timer, just deselect
		else if (item_index >= TimersList->Items->Count)
		{
			TimersList->ItemIndex = -1;
		}

	}

}
//---------------------------------------------------------------------------

void TMainForm::manageTimerButtons ()
{
	//default is all available
	TimerActionForm->AddNewTimer->Enabled = true;
	TimerActionForm->StartTimer->Enabled = true;
	TimerActionForm->StopTimer->Enabled = true;
	TimerActionForm->DoneWithTimer->Enabled = true;
	TimerActionForm->CancelTimer->Enabled = true;

	if (item_number == -1)
	{
		//did not click on a timer
		TimerActionForm->StartTimer->Enabled = false;
		TimerActionForm->StopTimer->Enabled = false;
		TimerActionForm->DoneWithTimer->Enabled = false;
		TimerActionForm->CancelTimer->Enabled = false;
	}
	else if (CurrTimer != TimerCollection.end() &&
			 CurrTimer->second.name == TimersList->Items->Strings[item_number])
	{
		//this timer is running
		TimerActionForm->StartTimer->Enabled = false;
	}
	else
	{
		//this timer is not running
		TimerActionForm->StopTimer->Enabled = false;
	}

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

	ShowMessage(getScrollPosition(Contacts->Handle));

	setScrollPosition(Contacts->Handle, 1);

}
//---------------------------------------------------------------------------

void TMainForm::displayTestStuff (int what_test, String whatever)
{

	if (what_test == 1)		//this test displays whatever talker server returns
	{
		TestForm->Show();
		TestForm->ShowWhatever->Lines->Add(whatever);
		TestForm->ShowWhatever->Lines->Add("-----------------------");
	}


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
								//on right-click mouse
	if (Button == mbRight)		//open MessageActionfForm
	{
		item_number = Y / 20;	//same var used for timers; should be no conflict
								//even w/ multiple forms since it's used immediatly

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
		what_item = -1;							//clicked, but not on a contact
		MessageActionForm->user = "";
		MessageActionForm->Caption = " ";
	}

	MessageActionForm->Show();	//not Modal, so it supports multi instances

}
//---------------------------------------------------------------------------

void TMainForm::readMessage (TMessageActionForm* MessageActionForm)
{
	multimap<String, Message>::iterator it;
	it = MessageBuffer.find(MessageActionForm->user);

	if (it != MessageBuffer.end())		//if there's a message from this user
	{
		MessageActionForm->TheMessage->Text = it->second.message_text;
		MessageActionForm->last_read_message = it->second;

		//display info about this message on the message form title bar -- this
		//code must come after TheMessage->Text is set (above) to prevent it
		//being overriden by the TheMessage control OnChange event
		String title_bar = "Message from ";
		title_bar += MessageActionForm->last_read_message.from;
		title_bar += " to ";
		title_bar += MessageActionForm->last_read_message.to;

		//format time
		time_t t;
		stringstream(MessageActionForm->last_read_message.time.c_str()) >> t;
		String messg_time = ctime(&t);
		messg_time.Delete(messg_time.Length(), 1);	//delete '\n' at the end
		title_bar += ", sent on ";
		title_bar += messg_time;

		MessageActionForm->Caption = title_bar;

		MessageBuffer.erase(it);
	}
				  
	//display the message subject/thread:
	String tempstr = MessageActionForm->last_read_message.thread;

	if (int loc = tempstr.Pos(">>"))
		tempstr.Insert(" ", loc);

	MessageActionForm->Topic->Text = tempstr;

}
//---------------------------------------------------------------------------

void TMainForm::sendMessage (TMessageActionForm* MessageActionForm, int what_item,
								String what_users_to)
{
	//send a message

	/* TODO 4 -oJay -cTalker : 
	Simplify sendMessage() by reducing to a single arg, Message
	-- requires adding a makeMessage() method to MessageActionForm that does the stuff done here,
	then that form's send and broadcast simply passes the Message to sendMessage() */

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
		subject += ">>";
		subject += MessageActionForm->makeTag(
							MessageActionForm->last_read_message.message_text);
	}

	Message trans_out(ini_settings->Values["user_name"], send_to,
					"NORMAL", subject, MessageActionForm->TheMessage->Text);
	String response = doTransfer(trans_out);

	if (response != CONNECT_ERROR)		//if comm w/ server did not fail
	{
		processServerTrans(response);
	}
	else
	{
		SendBuffer.push_back(trans_out);
		ShowMessage("Unable to confirm message transmission. \nAttempts to resend "
					"message will continue automatically until receipt"
					" is confirmed by the server.");
	}

	//copy to history
	static String last_message("");		//to prevent multistore of broadcasts
	if (last_message != MessageActionForm->TheMessage->Text)
		addToHistory(trans_out);
	last_message = MessageActionForm->TheMessage->Text;		//reset

}
//---------------------------------------------------------------------------

void TMainForm::broadcastMessage (TMessageActionForm* MessageActionForm)
{
	//send to all the listed contacts  -- OBSOLETE - DO NOT USE

	for (int i = 0; i < Contacts->Items->Count; i++)
		sendMessage(MessageActionForm, i, "");
}
//---------------------------------------------------------------------------

void TMainForm::addToHistory(Message& what_messg)
{
	//assign now-time if the time is empty (as in a just-sent message)
	if (!what_messg.time.Length())
	{
		time_t t;
		time(&t);
		what_messg.time = t;
	}

	//copy to history
	String mess_rec = what_messg.toXML();

	ofstream history(hist_filename.c_str(), ios_base::app);

	history << mess_rec.c_str() << endl;
	history.close();
	
	hist_buffer->Add(mess_rec);			//keep sync'd with file
}
//---------------------------------------------------------------------------

String TMainForm::DataCGI(String WhatName, String WhatValue)
//encodes data in URLencoded format -- returns the encoded data in the format "name=value"
{
  URLencoder->InputString = WhatValue;
  return ( WhatName + '=' + URLencoder->Encode );
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::ImOnClick(TObject *Sender)
{
	//toggle on/off-line for messaging purposes

	if (ini_settings->Values["user_name"] == "")
	{
		ShowMessage("Please enter a UserName in General Options.");
		return;
	}

	online = !online;
	available = true;				//this always resets available

	String status = online ? "IMON" : "IMOFF";


	Message trans_out(ini_settings->Values["user_name"], "",
							status, "", ini_settings->Values["user_status"]);
	String ServerResponse = doTransfer(trans_out);

	if (ServerResponse != CONNECT_ERROR)
	{
		ImOn->Picture = online ? ImageOn->Picture : ImageOff->Picture;
		processServerTrans(ServerResponse);
	}
	else
		ShowMessage("No acknowledgment received from server. Please try"
					" to update your on-line status again.");
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


		Message trans_out(ini_settings->Values["user_name"], "",
							status, "", ini_settings->Values["user_status"]);
		String ServerResponse = doTransfer(trans_out);

		if (ServerResponse != CONNECT_ERROR)
		{
			ImOn->Picture = available ? ImageOn->Picture : ImageBusy->Picture;
			processServerTrans(ServerResponse);
		}
		else
			ShowMessage("No acknowledgment received from server. Please try"
					" to update your on-line status again.");

	}
}
//---------------------------------------------------------------------------

String TMainForm::doTransfer (Message& trans_out)
{
	//basic communication exchange -- sends a Transmission to server and
	//receives a Transmission from server

	String xml_trans = trans_out.toXML();

	xml_trans.Insert("DATA=", 1);	//add "DATA=" to beginning of message string

	String cgi_exe = ini_settings->Values["server_url"];

	String trans_in = CONNECT_ERROR;		//default
	WebConnection->Body = CONNECT_ERROR;	//default

	status1 = CONNECTING_TO_SERVER;
	StatBar->Refresh();

	talk_comm_error = true;		//default; will also set to true if comm failure
	int pingct = 0;
	while (talk_comm_error && pingct < 10)	//try to connect to server up to 10X
	{
		try
		{
			WebConnection->Post(cgi_exe, xml_trans);
							//will timeout and raise exception if no response
			trans_in = WebConnection->Body;
			talk_comm_error = false;	//if got here, connection was successful
		}
		catch(...)
		{
			talk_comm_error = true;		//redundant since also set by OnFailure
			pingct++;
		}
	}

	//Currently, valid strings received from server must start w/  "<MESSAGE"
	//  -- if that's not the case, then an error occurred:
	//TODO -cTalker : MainFrm should not know about format of "<MESSAGE" string

	if ( talk_comm_error || trans_in.SubString(1, 8) != "<MESSAGE" )
		trans_in = CONNECT_ERROR;

	//update status bar
	if (trans_in == CONNECT_ERROR)		
		status1 = CONNECT_ERROR_STATUS;
	else
		status1 = "";
	StatBar->Refresh();

	return trans_in;
}
//---------------------------------------------------------------------------

void __fastcall TMainForm::WebConnectionFailure(CmdType Cmd)
{
	talk_comm_error = true;
}
//---------------------------------------------------------------------------

void TMainForm::processServerTrans (String ServerResponse)
{
	//parses a set of messages received from server and acts on them as needed

	if (OptionsForm->TestMode->Checked)        //for Testing Only
		displayTestStuff(1, ServerResponse);

	TStringList* message_set = new TStringList();
	message_set->Text = ServerResponse;

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

	UserCollection.clear();		//empty local user collection,
								//we'll build a new updated one

	for (int i = 0; i < message_set->Count; i++)
	{
		Message new_message(message_set->Strings[i]);

		if (new_message.status == "NORMAL")
		{
			//add to message buffer
			MessageBuffer.insert(make_pair(new_message.from, new_message));
			//if so selected, play sound to indicate message arrival
			if (ini_settings->Values["sound_none"] == "0")
			{
				//play sound
				playSound();
			}
			//copy to history
			addToHistory(new_message);
		}
		else //if (new_message.from != ini_settings->Values["user_name"]) //!self -- self is now OK
		{
			//these are the "IMON" and "IMOFF" messages
			//add all contacts to collection
			UserCollection.insert(make_pair(new_message.from, new_message));
			//and to contact display if not already there
			if (Contacts->Items->IndexOf(new_message.from) == -1)
				Contacts->Items->Add(new_message.from);
		}
	}

	//delete from display any contacts that are no longer in collection
	map<String, Message>::iterator it;
	for (int i = 0; i < Contacts->Items->Count; i++)
	{
		it = UserCollection.find(Contacts->Items->Strings[i]);
		if (it == UserCollection.end())
			Contacts->Items->Delete(i);
	}

	//if any contacts sent a message, they should be moved to the top
	for (multimap<String, Message>::iterator mit = MessageBuffer.begin();
									mit != MessageBuffer.end(); mit++)
	{
		//move from current position to top position:
		Contacts->Items->Move(Contacts->Items->IndexOf(mit->first), 0);
		//and scroll to the top so it's obvious a new message arrived
		setScrollPosition(Contacts->Handle, 0);
    }

	//causes a repaint without flicker
	//if (Contacts->Items->Count > 0)  //don't use this, use Refresh()
	//	Contacts->Items->Strings[0] = Contacts->Items->Strings[0];
	Contacts->Refresh();

	delete message_set;
}
//---------------------------------------------------------------------------
void __fastcall TMainForm::MessageTimerTimer(TObject *Sender)
{
	//if user is on-line, periodically issue IMON message to server

	if (online)
	{
		String status;
		status = available ? "IMON" : "IMBUSY";

		Message trans_out(ini_settings->Values["user_name"], "",
							status, "", ini_settings->Values["user_status"]);
		String ServerResponse = doTransfer(trans_out);

		if (ServerResponse != CONNECT_ERROR)
			processServerTrans(ServerResponse);

		//if so selected, play sound to indicate that messages are in buffer
		static int secs_since_last_sound = 0;
		if (!MessageBuffer.empty() && ini_settings->Values["sound_none"] == "0")
		{
			secs_since_last_sound += (MessageTimer->Interval / 1000);
			int ini_secs = ini_settings->Values["sound_interval"].ToIntDef(180);
			if (ini_secs != 0  &&  secs_since_last_sound >= ini_secs)
			{
				//play sound
				playSound();
				secs_since_last_sound = 0;
			}
		}
		else
        	secs_since_last_sound = 0;
	}

	//also attempt to send any messages that may still be in SendBuffer
	//(it is not necessary for user to be on-line)

	if (!SendBuffer.empty())
	{
		for (int i = 0; i < SendBuffer.size(); i++)
        {
			String ServerResponse = doTransfer(SendBuffer[i]);

			if (ServerResponse != CONNECT_ERROR)
			{
				SendBuffer.erase(SendBuffer.begin() + i--);
				processServerTrans(ServerResponse);
			}
		}

		
	}

	//reset interval in case it has changed
	MessageTimer->Interval =
		ini_settings->Values["server_refresh_interval"].ToIntDef(30) * 1000;

}
//---------------------------------------------------------------------------

void __fastcall TMainForm::OptionsClick(TObject *Sender)
{
	OptionsForm->ShowModal();
}
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------
//	METHODS TO MANAGE INI FILE AND EQUIVALENT MEMORY BUFFER
//---------------------------------------------------------------------------

void TMainForm::readIniFile ()
{
	//reads ini file and sets values accordingly

	//add HOME path to filename if it exists
	if (getenv(HOME.c_str()))
	{
		ini_filename = String(getenv(HOME.c_str())) + '\\' + INIFILENAME;
		hist_filename = String(getenv(HOME.c_str())) + '\\' + HISTFILENAME;
	}
	else
	{
		ini_filename = INIFILENAME;
		hist_filename = HISTFILENAME;
	}

	try
	{
		ini_settings->LoadFromFile(ini_filename);
	}
	catch(...)
	{
		;
	}

	//General Options, other forms positions, etc. are done in respective
	//forms (MessageActionForm, OptionsForm) -- they must exist first anyway

	//recover the contact list order
	String users = ini_settings->Values["contact_order"];
	int pos;
	do
	{
		pos = users.Pos(",");
		String next = pos ? users.SubString(1, pos - 1) : users;
		users.Delete(1, pos);
		Contacts->Items->Add(next);
	}
	while (pos);

	//set main window size and position from ini file
	if (ini_settings->Values["mainform_left"] != "")	//otherwise, it's 1st time
	{
		MainForm->Position = poDesigned;
		MainForm->Left = ini_settings->Values["mainform_left"].ToIntDef(MainForm->Left);
		MainForm->Top = ini_settings->Values["mainform_top"].ToIntDef(MainForm->Top);
		MainForm->Width = ini_settings->Values["mainform_width"].ToIntDef(MainForm->Width);
		MainForm->Height = ini_settings->Values["mainform_height"].ToIntDef(MainForm->Height);
		Contacts->Width = ini_settings->Values["talker_width"].ToIntDef(Contacts->Width);
		timernames_width = ini_settings->Values["timernames_width"].ToIntDef(50);
		hidden_timer_panes[0] = ini_settings->Values["hide_timer_names"].ToIntDef(0);
		hidden_timer_panes[1] = ini_settings->Values["hide_timer_digits"].ToIntDef(0);
		hidden_timer_panes[2] = ini_settings->Values["hide_timer_icons"].ToIntDef(0);
	}

}
//---------------------------------------------------------------------------

void TMainForm::writeIniFile ()
{
	//save current user list order
	String user_list;
	for (int i = 0; i < Contacts->Items->Count; i++)
    {
		user_list += Contacts->Items->Strings[i];	//concat current contacts
		if (Contacts->Items->Count > i + 1)
			user_list += ',';
	}
	ini_settings->Values["contact_order"] = user_list;

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

	//write to file, updating current user options as well
	ini_settings->SaveToFile(ini_filename);
}
//---------------------------------------------------------------------------

String TMainForm::getPathFilename(String filename, String extension)
{
	//returns filename w/ full path -- arg filename can include extension if
	//arg extension is 0-length string;
	//(this is currently only being used for sound files)

	String pathfile;

	//add HOME path to filename if it exists
	if (getenv(HOME.c_str()))
	{
		pathfile = String(getenv(HOME.c_str())) + '\\' + SOUNDSFOLDER;
	}
	else
	{
		pathfile = SOUNDSFOLDER;
	}

	pathfile += '\\';
	pathfile += filename;
	pathfile += extension;

	return pathfile;
}
//---------------------------------------------------------------------------

void TMainForm::playSound()
{
	try
	{
		SoundPlayer->FileName =
			getPathFilename(ini_settings->Values["sound_file"], ".wav");

		SoundPlayer->Open();
		SoundPlayer->Wait = true;
		SoundPlayer->Play();

		SoundPlayer->Close();
	}
	catch(...)
	{
		;	//sound cannot play if there's no hardware, etc., so do nothing
			//unless we're in test mode:
		if (OptionsForm->TestMode->Checked)
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

