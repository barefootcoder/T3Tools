//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "TestFrm.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TTestForm *TestForm;
//---------------------------------------------------------------------------
__fastcall TTestForm::TTestForm(TComponent* Owner)
	: TForm(Owner)
{
}
//---------------------------------------------------------------------------