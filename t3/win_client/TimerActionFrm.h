//---------------------------------------------------------------------------
#ifndef TimerActionFrmH
#define TimerActionFrmH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
#include <ExtCtrls.hpp>
#include <ComCtrls.hpp>
//---------------------------------------------------------------------------
class TTimerActionForm : public TForm
{
__published:	// IDE-managed Components
	TButton *AddNewTimer;
	TButton *StartTimer;
	TButton *StopTimer;
	TButton *DoneWithTimer;
	TButton *CancelTimer;
	TButton *Options;
	TPanel *Panel1;
	TEdit *TimerMaxHours;
	TLabel *Label1;
	TUpDown *TimerMaxHoursChange;
	TLabel *Label2;
	void __fastcall AddNewTimerClick(TObject *Sender);
	void __fastcall StartTimerClick(TObject *Sender);
	void __fastcall StopTimerClick(TObject *Sender);
	void __fastcall DoneWithTimerClick(TObject *Sender);
	void __fastcall CancelTimerClick(TObject *Sender);
	void __fastcall OptionsClick(TObject *Sender);
	void __fastcall FormShow(TObject *Sender);
	void __fastcall FormClose(TObject *Sender, TCloseAction &Action);
	void __fastcall FormKeyDown(TObject *Sender, WORD &Key,
          TShiftState Shift);
private:	// User declarations
public:		// User declarations
	__fastcall TTimerActionForm(TComponent* Owner);
};
//---------------------------------------------------------------------------
extern PACKAGE TTimerActionForm *TimerActionForm;
//---------------------------------------------------------------------------
#endif
