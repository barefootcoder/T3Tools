//---------------------------------------------------------------------------
#ifndef NewTimrH
#define NewTimrH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
#include <Buttons.hpp>
//---------------------------------------------------------------------------
class TNewTimer : public TForm
{
__published:	// IDE-managed Components
	TMemo *TimerNotes;
	TEdit *TimerName;
	TLabel *Label1;
	TLabel *Label2;
	TEdit *TimerDate;
	TLabel *Label3;
	TLabel *Label4;
	TEdit *TimerHours;
	TComboBox *TimerProject;
	TComboBox *TimerPhase;
	TLabel *Label5;
	TLabel *Label6;
	TLabel *Label7;
	TComboBox *TimerClient;
	TBitBtn *Save;
	TBitBtn *Cancel;
	void __fastcall FormKeyDown(TObject *Sender, WORD &Key,
          TShiftState Shift);
private:	// User declarations

public:		// User declarations
	__fastcall TNewTimer(TComponent* Owner);

};
//---------------------------------------------------------------------------
extern PACKAGE TNewTimer *NewTimer;
//---------------------------------------------------------------------------
#endif
