//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "TimerActionFrm.h"
#include "MainFrm.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
//---------------------------------------------------------------------------
__fastcall TTimerActionForm::TTimerActionForm(TComponent* Owner)
	: TForm(Owner)
{
	KeyPreview = true;		//for form to respond to keyboard events

}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::FormShow(TObject *Sender)
{
	this->Height = 144;
	Options->Caption = "&Options >>";

	//prevent form from showing outside screen
	keepWithinScreen();

}
//---------------------------------------------------------------------------

void TTimerActionForm::keepWithinScreen ()
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

void __fastcall TTimerActionForm::FormClose(TObject *Sender,
	  TCloseAction &Action)
{
	//sets options for an existing timer.
	//options for a new timer are set by MainForm->addNewTimer()

	if (ModalResult != mrYes)	// (note: be sure mrYes is only from New button)
		MainForm->setOptions(-1);
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

	if (this->Height == 144)
	{
		this->Height = 236;
		Options->Caption = "&Options <<";
	}
	else
	{
		this->Height = 144;
		Options->Caption = "&Options >>";
	}

	keepWithinScreen();

}
//---------------------------------------------------------------------------

void __fastcall TTimerActionForm::FormKeyDown(TObject *Sender, WORD &Key,
      TShiftState Shift)
{
	if (Key == VK_ESCAPE)
		ModalResult = mrCancel;

}
//---------------------------------------------------------------------------

