//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include <io.h>

#include "t3client.h"
#include "OptionsFrm.h"
#include "IniOptions.h"
#include "MainFrm.h"	//limit calling MainFrm interface to OptionsFrm OnClose

using namespace user_options;

//---------------------------------------------------------------------------
#pragma package(smart_init)
#pragma resource "*.dfm"
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

	else
	{
		gatherOptions();	//save the values displayed on the form fields
		//do other updates that may be needed immediately after picking options:
		MainForm->activateTimerFeatures();
	}

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
	//populate form fields with current user options (from options buffer)

	UserName->Text = IniOpt->getValue("user_name").c_str();
	UserLocation->Text = IniOpt->getValue("user_location").c_str();
	UserStatus->Text = IniOpt->getValue("user_status").c_str();
	ServerURL->Text = IniOpt->getValue("server_url").c_str();
	HistoryDivider->Text = (IniOpt->getValue("hist_message_divider") == "") ?
					"--------------------" :	//default value
					IniOpt->getValue("hist_message_divider").c_str();
	CloseOnSend->Checked = (IniOpt->getValue("close_on_send", "1") == "1");
	SelectMode->Checked = (IniOpt->getValue("multiselect_mode") == "1");
	ConfirmOnClear->Checked = (IniOpt->getValue("confirm_on_clear", "1") == "1");
	CommTimeout->Text = IniOpt->getValueInt("communication_timeout", 10);
	RefreshFrequencyChange->Position =
							IniOpt->getValueInt("server_refresh_interval", 30);
	ResendAfterNoRCVDChange->Position =
							IniOpt->getValueInt("resend_if_no_rcvd_interval", 10);
	ResendAfterNoDLVDChange->Position =
							IniOpt->getValueInt("resend_if_no_dlvd_interval", 2);
	ResendAfterNoREADChange->Position =
							IniOpt->getValueInt("resend_if_no_read_interval", 2);
	UnconfsRefreshChange->Position =
							IniOpt->getValueInt("refresh_unconfs_view", 5);


	//sound settings
	MessageSound->Text = IniOpt->getValue("sound_file").c_str();
	ReplaySoundChange->Position = IniOpt->getValueInt("sound_interval", 180);
	SoundOff->Checked = (IniOpt->getValue("sound_none") == "1");

	//message-window font attributes options  (from ini file buffer)
	if (IniOpt->getValue("messagefont_name") != "")
	{
		MessageFont->Font->Name = IniOpt->getValue("messagefont_name").c_str();
		MessageFont->Text = MessageFont->Font->Name;
		MessageFont->Font->Size = IniOpt->getValueInt("messagefont_size", 8);
		MessageFont->Font->Color = (TColor) IniOpt->getValueInt("messagefont_color", clBlack); //OK for 32-bit int
		if (IniOpt->getValueInt("messagefont_bold", 0))
			MessageFont->Font->Style = MessageFont->Font->Style << fsBold;
		if (IniOpt->getValueInt("messagefont_italic", 0))
			MessageFont->Font->Style = MessageFont->Font->Style << fsItalic;
	}

	//timer settings
	ShowTimer->Checked = !!IniOpt->getValueInt("timer_active", 0);
	txtTimerPingInterval->Text = IniOpt->getValueInt("timer_ping_interval", 10);

	// test mode
	chkTestMode->Checked = !!IniOpt->getValueInt("test_mode", 0);

	return;
}
//---------------------------------------------------------------------------

void TOptionsForm::gatherOptions()
{
	//read values from the form fields to the options buffer (IniOpt object)

	IniOpt->setValue("user_name", UserName->Text.c_str());
	IniOpt->setValue("user_location", UserLocation->Text.c_str());
	IniOpt->setValue("user_status", UserStatus->Text.c_str());
	IniOpt->setValue("server_url", ServerURL->Text.c_str());
	IniOpt->setValue("hist_message_divider", HistoryDivider->Text.c_str());
	IniOpt->setValue("close_on_send", CloseOnSend->Checked ? "1" : "0");
	IniOpt->setValue("multiselect_mode", SelectMode->Checked ? "1" : "0");
	IniOpt->setValue("confirm_on_clear", ConfirmOnClear->Checked ? "1" : "0");
	IniOpt->setValueInt("communication_timeout", CommTimeout->Text.ToIntDef(10));
	IniOpt->setValueInt("server_refresh_interval",
									RefreshFrequency->Text.ToIntDef(30));
	IniOpt->setValueInt("resend_if_no_rcvd_interval",
									ResendAfterNoRCVD->Text.ToIntDef(10));
	IniOpt->setValueInt("resend_if_no_dlvd_interval",
									ResendAfterNoDLVD->Text.ToIntDef(2));
	IniOpt->setValueInt("resend_if_no_read_interval",
									ResendAfterNoREAD->Text.ToIntDef(2));
	IniOpt->setValueInt("refresh_unconfs_view",
									UnconfsRefresh->Text.ToIntDef(5));

	//message sound alert settings
	IniOpt->setValue("sound_file", MessageSound->Text.c_str());
	IniOpt->setValueInt("sound_interval", ReplaySound->Text.ToIntDef(180));
	IniOpt->setValue("sound_none", SoundOff->Checked ? "1" : "0");

	//message window font
	int bold, italic;
	bold = MessageFont->Font->Style.Contains(fsBold);
	italic = MessageFont->Font->Style.Contains(fsItalic);

	IniOpt->setValue("messagefont_name", MessageFont->Font->Name.c_str());
	IniOpt->setValueInt("messagefont_size", MessageFont->Font->Size);
	IniOpt->setValueInt("messagefont_color", MessageFont->Font->Color);
	IniOpt->setValueInt("messagefont_bold", bold);
	IniOpt->setValueInt("messagefont_italic", italic);

	//timer settings
	IniOpt->setValue("timer_active", ShowTimer->Checked ? "1" : "0");
	IniOpt->setValueInt("timer_ping_interval",
    								txtTimerPingInterval->Text.ToIntDef(10));

	// test mode
	IniOpt->setValue("test_mode", chkTestMode->Checked ? "1" : "0");

	return;
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
	MessageSound->Clear();
	string filespec = T3Pathname() + SOUNDSFOLDER + string("*.wav");

	WIN32_FIND_DATA fileinfo;
	HANDLE hFiles = ::FindFirstFile(filespec.c_str(), &fileinfo); 
	if ( hFiles != INVALID_HANDLE_VALUE )
	{
		string name = fileinfo.cFileName;
		while ( !name.empty() ) 
		{
			int pos = name.rfind(".");
			if ( pos > -1 )
				name.erase(pos);

			MessageSound->Items->Add(name.c_str());

			if ( ::FindNextFile(hFiles, &fileinfo) )
				name = fileinfo.cFileName;
			else
				name = "";
		}

		::FindClose(hFiles);
	}

	return;
}
//---------------------------------------------------------------------------

