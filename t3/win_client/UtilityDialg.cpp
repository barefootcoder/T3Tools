//---------------------------------------------------------------------------

#include <vcl.h>
#pragma hdrstop

#include "UtilityDialg.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TUtilityDialog *UtilityDialog;
//---------------------------------------------------------------------------
__fastcall TUtilityDialog::TUtilityDialog(TComponent* Owner)
	: TForm(Owner)
{
}
//---------------------------------------------------------------------------

void __fastcall TUtilityDialog::FormDblClick(TObject *Sender)
{
	ModalResult = mrOk;
}
//---------------------------------------------------------------------------

