//---------------------------------------------------------------------------
#ifndef NewTimrH
#define NewTimrH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
#include <Buttons.hpp>
#include <ExtCtrls.hpp>

#include "TimerMgr.h"
using namespace barefoot;

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
	TCheckBox *chkHalfTime;
	TBevel *Bevel1;
	void __fastcall FormKeyDown(TObject *Sender, WORD &Key,
          TShiftState Shift);
	void __fastcall FormClose(TObject *Sender, TCloseAction &Action);
	void __fastcall TimerNameKeyPress(TObject *Sender, char &Key);

private:	// User declarations

	TimerMgr& m_tmrmgr;
	string m_tmrname;
	string m_command;


public:		// User declarations

	__fastcall TNewTimer(TComponent* Owner, TimerMgr& mgr,
						 const string& tmrname, const string& command);

};
//---------------------------------------------------------------------------
#endif
