//---------------------------------------------------------------------------

#ifndef InTransitFrmH
#define InTransitFrmH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
#include <Buttons.hpp>
#include <ExtCtrls.hpp>

#include <vector>

using namespace std;

//---------------------------------------------------------------------------
class TInTransitForm : public TForm
{
__published:	// IDE-managed Components
	TPanel *Panel1;
	TListBox *MessageList;
	TSplitter *Splitter1;
	TListBox *DeliveryStatus;
	TPanel *Panel3;
	TLabel *Label1;
	TLabel *Label2;
	TTimer *Refresher;
	TBitBtn *Cancel;
	void __fastcall RefresherTimer(TObject *Sender);
	void __fastcall FormShow(TObject *Sender);
	void __fastcall FormResize(TObject *Sender);
	void __fastcall CancelClick(TObject *Sender);
private:	// User declarations
	vector<string> unconf_id_list;		//local id list of unconfirmed messages
public:		// User declarations
	__fastcall TInTransitForm(TComponent* Owner);
};
//---------------------------------------------------------------------------
extern PACKAGE TInTransitForm *InTransitForm;
//---------------------------------------------------------------------------
#endif
