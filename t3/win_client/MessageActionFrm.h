//---------------------------------------------------------------------------
#ifndef MessageActionFrmH
#define MessageActionFrmH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
#include <ExtCtrls.hpp>
#include <ComCtrls.hpp>
#include <Buttons.hpp>
#include <Dialogs.hpp>

//class Message;	//fwd decl
#include "MessagesImp.h"

//---------------------------------------------------------------------------
class TMessageActionForm : public TForm
{
__published:	// IDE-managed Components
	TPanel *Panel2;
	TButton *GetMessg;
	TButton *CloseForm;
	TButton *BroadcastMessg;
	TButton *ClearMessage;
	TPanel *Panel1;
	TMemo *TheMessage;
	TFontDialog *FontDialog1;
	TListBox *UserList;
	TTimer *MessageCheck;
	TButton *All;
	TButton *None;
	TPanel *Panel3;
	TSpeedButton *ShowHistory;
	TBitBtn *ReplyMessg;
	TBitBtn *SendMessg;
	TEdit *Topic;
	TLabel *Label1;
	TLabel *ReplyLED;
	TEdit *FilterSubject;
	TEdit *FilterKw;
	TLabel *Label2;
	TCheckBox *FilterThread;
	TButton *ApplyFilter;
	TButton *HistButton;
	void __fastcall GetMessgClick(TObject *Sender);
	void __fastcall FormClose(TObject *Sender, TCloseAction &Action);
	void __fastcall BroadcastMessgClick(TObject *Sender);
	void __fastcall CloseFormClick(TObject *Sender);
	void __fastcall FormShow(TObject *Sender);
	void __fastcall TheMessageChange(TObject *Sender);
	void __fastcall ClearMessageClick(TObject *Sender);
	void __fastcall FormKeyDown(TObject *Sender, WORD &Key,
          TShiftState Shift);
	void __fastcall UserListClick(TObject *Sender);
	void __fastcall MessageCheckTimer(TObject *Sender);
	void __fastcall AllClick(TObject *Sender);
	void __fastcall ShowHistoryClick(TObject *Sender);
	void __fastcall ReplyMessgClick(TObject *Sender);
	void __fastcall SendMessgClick(TObject *Sender);
	void __fastcall ApplyFilterClick(TObject *Sender);
	void __fastcall HistButtonClick(TObject *Sender);
	void __fastcall TheMessageKeyDown(TObject *Sender, WORD &Key,
          TShiftState Shift);
	void __fastcall TheMessageKeyUp(TObject *Sender, WORD &Key,
          TShiftState Shift);
private:	// User declarations
	void manageMessageButtons(int state);
	bool history_on;
	bool confirmDialog(String saywhat);
	int editing_message_size;
public:		// User declarations
	__fastcall TMessageActionForm(TComponent* Owner);
	String user;		//each Message form usually has an associated user name
	Message last_read_message;	//so we have full info about a displayed messg
	String makeTag (String& what_message);	//creates a message identifier
};
//---------------------------------------------------------------------------
extern PACKAGE TMessageActionForm *MessageActionForm;
//---------------------------------------------------------------------------
#endif
 