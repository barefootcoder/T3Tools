//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "NewTimr.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TNewTimer *NewTimer;
//---------------------------------------------------------------------------
__fastcall TNewTimer::TNewTimer(TComponent* Owner)
	: TForm(Owner)
{
	KeyPreview = true;		//for form to respond to keyboard events
}
//---------------------------------------------------------------------------
void __fastcall TNewTimer::FormKeyDown(TObject *Sender, WORD &Key,
      TShiftState Shift)
{
	if (Key == VK_RETURN && TimerName->Text != "")
		ModalResult = mrOk;
	else if (Key == VK_ESCAPE)
		ModalResult = mrCancel;
}
//---------------------------------------------------------------------------

