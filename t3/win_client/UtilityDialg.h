//---------------------------------------------------------------------------

#ifndef UtilityDialgH
#define UtilityDialgH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
//---------------------------------------------------------------------------
class TUtilityDialog : public TForm
{
__published:	// IDE-managed Components
	TLabel *Label1;
	void __fastcall FormDblClick(TObject *Sender);
private:	// User declarations
public:		// User declarations
	__fastcall TUtilityDialog(TComponent* Owner);
};
//---------------------------------------------------------------------------
extern PACKAGE TUtilityDialog *UtilityDialog;
//---------------------------------------------------------------------------
#endif
