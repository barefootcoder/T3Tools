//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include <io.h>

#include "OptionsFrm.h"
#include "MainFrm.h"
//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
TOptionsForm *OptionsForm;
//---------------------------------------------------------------------------
__fastcall TOptionsForm::TOptionsForm(TComponent* Owner)
	: TForm(Owner)
{
	//initialize controls
	scatterOptions();
}
//---------------------------------------------------------------------------

void __fastcall TOptionsForm::FormShow(TObject *Sender)
{
	readWavFilenames();
	//display current user options
	scatterOptions();
}
//---------------------------------------------------------------------------

void __fastcall TOptionsForm::FormClose(TObject *Sender,
      TCloseAction &Action)
{
	if (ModalResult == mrCancel)
		return;

	else 		//otherwise save the values displayed on the form fields
		gatherOptions();

}
//---------------------------------------------------------------------------

void __fastcall TOptionsForm::SetMessageFontClick(TObject *Sender)
{
	FontDialog1->Font = MessageFont->Font;

	if (FontDialog1->Execute())
		MessageFont->Font = FontDialog1->Font;

	MessageFont->Text = MessageFont->Font->Name;
}
//---------------------------------------------------------------------------

void TOptionsForm::scatterOptions()
{
	//populate form fields with current user options (from ini file buffer)

	UserName->Text = MainForm->ini_settings->Values["user_name"];
	UserStatus->Text = MainForm->ini_settings->Values["user_status"];
	ServerURL->Text = MainForm->ini_settings->Values["server_url"];
	HistoryDivider->Text = (HistoryDivider->Text == "") ?
					String("--------------------") :	//default value
					MainForm->ini_settings->Values["hist_message_divider"];
	RefreshFrequencyChange->Position =
		MainForm->ini_settings->Values["server_refresh_interval"].ToIntDef(30);
	CloseOnSend->Checked = (MainForm->ini_settings->Values["close_on_send"] == "1")
							? true : false;
	SelectMode->Checked = (MainForm->ini_settings->Values["multiselect_mode"] == "1")
							? true : false;

	//sound settings
	MessageSound->Text = MainForm->ini_settings->Values["sound_file"];
	ReplaySoundChange->Position =
				MainForm->ini_settings->Values["sound_interval"].ToIntDef(180);
	SoundOff->Checked = (MainForm->ini_settings->Values["sound_none"] == "1")
							? true : false;

	//message-window font attributes options  (from ini file buffer)
	if (MainForm->ini_settings->Values["messagefont_name"] != "")
	{
		MessageFont->Font->Name = MainForm->ini_settings->Values["messagefont_name"];
		MessageFont->Text = MessageFont->Font->Name;
		MessageFont->Font->Size = MainForm->ini_settings->Values["messagefont_size"].ToIntDef(8);
		MessageFont->Font->Color = MainForm->ini_settings->Values["messagefont_color"].ToIntDef(clBlack); //OK for 32-bit int
		if (MainForm->ini_settings->Values["messagefont_bold"].ToIntDef(0))
			MessageFont->Font->Style = MessageFont->Font->Style << fsBold;
		if (MainForm->ini_settings->Values["messagefont_italic"].ToIntDef(0))
			MessageFont->Font->Style = MessageFont->Font->Style << fsItalic;
	}
}
//---------------------------------------------------------------------------

void TOptionsForm::gatherOptions()
{
	//save user name, server refresh, etc.
	MainForm->ini_settings->Values["user_name"] = UserName->Text;
	MainForm->ini_settings->Values["user_status"] = UserStatus->Text;
	MainForm->ini_settings->Values["server_url"] = ServerURL->Text;
	MainForm->ini_settings->Values["server_refresh_interval"] =
									RefreshFrequency->Text.ToIntDef(30);
	MainForm->ini_settings->Values["hist_message_divider"] = HistoryDivider->Text;
	MainForm->ini_settings->Values["close_on_send"] = CloseOnSend->Checked ? "1" : "0";
	MainForm->ini_settings->Values["multiselect_mode"] = SelectMode->Checked ? "1" : "0";

	//save message sound alert settings
	MainForm->ini_settings->Values["sound_file"] = MessageSound->Text;
	MainForm->ini_settings->Values["sound_interval"] = ReplaySound->Text.ToIntDef(180);
	MainForm->ini_settings->Values["sound_none"] = SoundOff->Checked ? "1" : "0";

	//save message window font
	int bold, italic;
	bold = MessageFont->Font->Style.Contains(fsBold);
	italic = MessageFont->Font->Style.Contains(fsItalic);

	MainForm->ini_settings->Values["messagefont_name"] = MessageFont->Font->Name;
	MainForm->ini_settings->Values["messagefont_size"] = MessageFont->Font->Size;
	MainForm->ini_settings->Values["messagefont_color"] = MessageFont->Font->Color;
	MainForm->ini_settings->Values["messagefont_bold"] = bold;
	MainForm->ini_settings->Values["messagefont_italic"] = italic;
}
//---------------------------------------------------------------------------

void __fastcall TOptionsForm::SoundOffClick(TObject *Sender)
{
	MessageSound->Enabled = !SoundOff->Checked;
	ReplaySound->Enabled = !SoundOff->Checked;
	ReplaySoundChange->Enabled = !SoundOff->Checked;
}
//---------------------------------------------------------------------------

void TOptionsForm::readWavFilenames()
{
	String filespec;

	if (getenv(HOME.c_str()))
	{
		filespec = String(getenv(HOME.c_str())) + '\\' + SOUNDSFOLDER;
	}
	else
	{
		filespec = SOUNDSFOLDER;
	}

	filespec += "\\*.wav";

	struct _finddata_t fileinfo;
	long handle = _findfirst(filespec.c_str(), &fileinfo);
	bool theresmore;
	MessageSound->Clear();
	do
	{
		String filename = fileinfo.name;
		filename.Delete(filename.Pos("."), 4);
		MessageSound->Items->Add(filename);
	}
	while (theresmore = !_findnext(handle, &fileinfo));

}
//---------------------------------------------------------------------------
