//---------------------------------------------------------------------------
#ifndef TestFrmH
#define TestFrmH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
//---------------------------------------------------------------------------
class TTestForm : public TForm
{
__published:	// IDE-managed Components
	TMemo *ShowWhatever;
private:	// User declarations
public:		// User declarations
	__fastcall TTestForm(TComponent* Owner);
};
//---------------------------------------------------------------------------
extern PACKAGE TTestForm *TestForm;
//---------------------------------------------------------------------------
#endif
