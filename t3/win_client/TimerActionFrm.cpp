//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "TimerActionFrm.h"
#include "MainFrm.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TTimerActionForm *TimerActionForm;
//---------------------------------------------------------------------------
__fastcall TTimerActionForm::TTimerActionForm(TComponent* Owner)
	: TForm(Owner)
{
	KeyPreview = true;		//for form to respond to keyboard events

}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::FormShow(TObject *Sender)
{
	this->Width = 111;
	Options->Caption = "&Options >>";
}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::FormClose(TObject *Sender,
	  TCloseAction &Action)
{
	//sets options for an existing timer.
	//options for a new timer are set by MainForm->addNewTimer()

	if (ModalResult != mrYes)	// (note: be sure mrYes is only from New button)
		MainForm->setOptions(-1);
}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::AddNewTimerClick(TObject *Sender)
{
	MainForm->addNewTimer();
}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::StartTimerClick(TObject *Sender)
{
	MainForm->startTimer();	
}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::StopTimerClick(TObject *Sender)
{
	MainForm->stopTimer();	
}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::DoneWithTimerClick(TObject *Sender)
{
	MainForm->doneWithTimer();	
}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::CancelTimerClick(TObject *Sender)
{
	MainForm->cancelTimer();
}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::OptionsClick(TObject *Sender)
{

	if (this->Width == 111)
	{
		this->Width = 263;
		Options->Caption = "&Options <<";
	}
	else
	{
		this->Width = 111;
		Options->Caption = "&Options >>";
	}

}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::FormKeyDown(TObject *Sender, WORD &Key,
      TShiftState Shift)
{
	if (Key == VK_ESCAPE)
		ModalResult = mrCancel;

}
//---------------------------------------------------------------------------

