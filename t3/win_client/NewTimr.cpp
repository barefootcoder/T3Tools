//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "T3client.h"
#include "NewTimr.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
//---------------------------------------------------------------------------
__fastcall TNewTimer::TNewTimer(TComponent* Owner, TimerMgr& mgr,
								const string& tmrname,
								const string& command)
	: m_tmrmgr(mgr), m_tmrname(tmrname), m_command(command), TForm(Owner)
{
	TimerName->Text = tmrname.c_str(); 
	TimerClient->Text = mgr.getTimerClient(tmrname).c_str();
	TimerProject->Text = mgr.getTimerProject(tmrname).c_str();
	TimerPhase->Text = mgr.getTimerPhase(tmrname).c_str();
	TimerNotes->Text = mgr.getTimerDescription(tmrname).c_str();
	TimerDate->Text = DateToStr(Date());
	TimerHours->Text = mgr.getElapsedTime(tmrname).c_str();

	return;
}
//---------------------------------------------------------------------------
void __fastcall TNewTimer::FormKeyDown(TObject *Sender, WORD &Key,
      TShiftState Shift)
{
	if (Key == VK_RETURN)
		ModalResult = mrOk;
	else if (Key == VK_ESCAPE)
		ModalResult = mrCancel;

	return;
}
//---------------------------------------------------------------------------
void __fastcall TNewTimer::FormClose(TObject *Sender, TCloseAction &Action)
{
	bool closewin = true;
	if ( ModalResult == mrOk )
	{
		string name = "";

		// timer name can not be blank
		if ( TimerName->Text.IsEmpty() )
		{
			if ( TimerName->Enabled )
			{
				Action = caNone;
				ShowMessage("Please enter a timer name.");
				TimerName->SetFocus();
				return;
			}
			else
			{
				// set a default name
				name = "BUDDYS_EMPTY_TIMER_NAME";
			}
		}
		else
		{
			// get the name
			name = TimerName->Text.c_str();
		}

		Timer timer(name, TimerClient->Text.c_str(),
					TimerProject->Text.c_str(), TimerPhase->Text.c_str());
		timer.setHalfTime(chkHalfTime->Checked);
		timer.setDescription(TimerNotes->Lines->Text.c_str());

		if ( m_command == "START" )
			closewin = m_tmrmgr.startTimer(timer);
		else if ( m_command == "RENAME" )
			closewin = m_tmrmgr.renameTimer(m_tmrname, timer);
		else if ( m_command == "LOG" )
			closewin = m_tmrmgr.logTimer(timer);
		else if ( m_command == "DONE" )
			closewin = m_tmrmgr.doneTimer(timer);
		else
		{
			// unknown command; just exit window
			ShowMessage(AnsiString("Unrecognized command - ") + m_command.c_str());
		}

		if ( !closewin )
		{
			string msg = "The server responded with\n\n" + 
						  m_tmrmgr.getLastError() +
						"\n\nWould you like to re-enter values?";
			string cpt = T3Caption() + " - Timer Error";
			int rc = Application->MessageBox(msg.c_str(), cpt.c_str(),
									MB_RETRYCANCEL | MB_ICONERROR);
			if ( rc != mrRetry )
				closewin = true;
		}
	}

	// check users wishes
	if ( closewin )
	{
		// close the window
		Action = caFree;
	}
	else
	{
		// leave window open for corrective actions
		Action = caNone;
	}

	return;
}
//---------------------------------------------------------------------------
void __fastcall TNewTimer::TimerNameKeyPress(TObject *Sender, char &Key)
{
	if ( Key == ' ' )
	{
		Beep();
    	Key = 0;
	}
        
	return;
}
//---------------------------------------------------------------------------

