//---------------------------------------------------------------------------
#ifndef OptionsFrmH
#define OptionsFrmH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
#include <ComCtrls.hpp>
#include <Buttons.hpp>
#include <Dialogs.hpp>
#include <ExtCtrls.hpp>

//---------------------------------------------------------------------------

const String HOME = "HOME";		//holds name of env var w/ user path name
const String SOUNDSFOLDER = "sounds";

//---------------------------------------------------------------------------
class TOptionsForm : public TForm
{
__published:	// IDE-managed Components
	TPageControl *TabOptions;
	TTabSheet *TalkerOptions;
	TTabSheet *TimerOptions;
	TLabel *Label1;
	TEdit *UserName;
	TLabel *Label2;
	TEdit *RefreshFrequency;
	TUpDown *RefreshFrequencyChange;
	TLabel *Label3;
	TCheckBox *CloseOnSend;
	TEdit *ServerURL;
	TLabel *Label4;
	TLabel *Label5;
	TEdit *HistoryDivider;
	TLabel *Label6;
	TEdit *MessageFont;
	TSpeedButton *SetMessageFont;
	TFontDialog *FontDialog1;
	TCheckBox *TestMode;
	TEdit *UserStatus;
	TLabel *Label7;
	TPanel *Panel1;
	TBitBtn *Save;
	TBitBtn *Cancel;
	TCheckBox *SelectMode;
	TLabel *Label8;
	TLabel *Label9;
	TLabel *Label10;
	TEdit *ReplaySound;
	TUpDown *ReplaySoundChange;
	TLabel *Label11;
	TCheckBox *SoundOff;
	TComboBox *MessageSound;
	TLabel *Label12;
	TEdit *CommTimeout;
	TLabel *Label13;
	TLabel *Label14;
	TEdit *UserLocation;
	TTabSheet *TabSheet1;
	TLabel *Label15;
	TEdit *ResendAfterNoRCVD;
	TUpDown *ResendAfterNoRCVDChange;
	TLabel *Label16;
	TLabel *Label17;
	TEdit *ResendAfterNoDLVD;
	TUpDown *ResendAfterNoDLVDChange;
	TLabel *Label18;
	TLabel *Label19;
	TEdit *ResendAfterNoREAD;
	TUpDown *ResendAfterNoREADChange;
	TLabel *Label20;
	TLabel *Label21;
	TEdit *UnconfsRefresh;
	TUpDown *UnconfsRefreshChange;
	TLabel *Label22;
	void __fastcall FormClose(TObject *Sender, TCloseAction &Action);
	void __fastcall SetMessageFontClick(TObject *Sender);
	void __fastcall FormShow(TObject *Sender);
	void __fastcall SoundOffClick(TObject *Sender);
private:    // User declarations
	void scatterOptions();		//populate form fields with current ini values
	void gatherOptions();       //copy from form fields to ini values
	void readWavFilenames();

public:		// User declarations
	__fastcall TOptionsForm(TComponent* Owner);
	
};
//---------------------------------------------------------------------------
extern PACKAGE TOptionsForm *OptionsForm;
//---------------------------------------------------------------------------
#endif
