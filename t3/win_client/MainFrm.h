//---------------------------------------------------------------------------
#ifndef MainFrmH
#define MainFrmH
//---------------------------------------------------------------------------
#include <Classes.hpp>
#include <Controls.hpp>
#include <StdCtrls.hpp>
#include <Forms.hpp>
#include <ExtCtrls.hpp>
#include <Buttons.hpp>
#include <CheckLst.hpp>
#include <Graphics.hpp>
#include <ImgList.hpp>
#include <NMURL.hpp>
#include <ComCtrls.hpp>
#include <NMHttp.hpp>
#include <Psock.hpp>
#include <MPlayer.hpp>

#include <map>
#include <vector>

#include "TimersImp.h"
#include "MessagesImp.h"

class TMessageActionForm;	//just a forward declaration

const String INIFILENAME = "Timer.ini";
const String HISTFILENAME = "Timer.his";
const String SOUNDSFOLDER = "sounds";
const String HOME = "HOME";		//holds name of env var w/ user path name
const String CONNECTING_TO_SERVER = "COMMUNICATING";		//display on status bar
const String CONNECT_ERROR = "CANNOT CONNECT TO SERVER";
const String CONNECT_ERROR_STATUS = "ERROR COMMUNICATING";	//display on status bar

using namespace std;

//---------------------------------------------------------------------------
class TMainForm : public TForm
{
__published:	// IDE-managed Components
	TPanel *Panel1;
	TTimer *SystemTimer;
	TListBox *Contacts;
	TSplitter *Splitter1;
	TListBox *TimersList;
	TImage *HideContacts;
	TImage *HideTimerIcons;
	TImage *HideTimerNames;
	TImage *HideTimerDigits;
	TImage *ShowArrow;
	TImage *AddTimer;
	TImage *HideArrow;
	TImageList *HoursBlack;
	TImageList *HoursRed;
	TImageList *MinutesBlack;
	TImageList *MinutesRed;
	TImage *RunningDude;
	TImageList *ContactsGlyphs;
	TButton *TestButton;
	TNMURL *URLencoder;
	TImage *ImOn;
	TImage *ImageOff;
	TImage *ImageOn;
	TTimer *MessageTimer;
	TTimer *Blinker;
	TImage *Options;
	TStatusBar *StatBar;
	TImage *ImageBusy;
	TNMHTTP *WebConnection;
	TMediaPlayer *SoundPlayer;
	void __fastcall FormResize(TObject *Sender);
	void __fastcall TimersListClick(TObject *Sender);
	void __fastcall SystemTimerTimer(TObject *Sender);
	void __fastcall ContactsDrawItem(TWinControl *Control, int Index,
          TRect &Rect, TOwnerDrawState State);
	void __fastcall TimersListMouseMove(TObject *Sender, TShiftState Shift,
          int X, int Y);
	void __fastcall TimersListMouseDown(TObject *Sender, TMouseButton Button,
          TShiftState Shift, int X, int Y);
	void __fastcall TimersListDrawItem(TWinControl *Control, int Index,
          TRect &Rect, TOwnerDrawState State);
	void __fastcall AddTimerClick(TObject *Sender);
	void __fastcall HideContactsClick(TObject *Sender);
	void __fastcall HideTimersClick(TObject *Sender);
	void __fastcall RunningDudeClick(TObject *Sender);
	void __fastcall TestButtonClick(TObject *Sender);
	void __fastcall ContactsMouseDown(TObject *Sender, TMouseButton Button,
          TShiftState Shift, int X, int Y);
	void __fastcall ImOnClick(TObject *Sender);
	void __fastcall MessageTimerTimer(TObject *Sender);
	void __fastcall BlinkerTimer(TObject *Sender);
	void __fastcall FormClose(TObject *Sender, TCloseAction &Action);
	void __fastcall FormShow(TObject *Sender);
	void __fastcall OptionsClick(TObject *Sender);
	void __fastcall ContactsClick(TObject *Sender);
	void __fastcall ContactsDblClick(TObject *Sender);
	void __fastcall ContactsKeyDown(TObject *Sender, WORD &Key,
          TShiftState Shift);
	void __fastcall Splitter1Moved(TObject *Sender);
	void __fastcall FormConstrainedResize(TObject *Sender, int &MinWidth,
          int &MinHeight, int &MaxWidth, int &MaxHeight);
	void __fastcall StatBarDrawPanel(TStatusBar *StatusBar,
          TStatusPanel *Panel, const TRect &Rect);
	void __fastcall ImOnMouseDown(TObject *Sender, TMouseButton Button,
          TShiftState Shift, int X, int Y);
	void __fastcall WebConnectionFailure(CmdType Cmd);
	void __fastcall FormKeyDown(TObject *Sender, WORD &Key,
          TShiftState Shift);
private:	// User declarations
	bool newmode;
	bool online;							//this user is on-line for messaging
	bool available;							//this user is available to talk
	bool talk_comm_error;					//talker error connecting to server
	bool blink;
	bool hidden_timer_panes[3];				//to keep track of timer panes display
	bool no_timer_update;					//prevents repainting of the timers
	map<String, Message> UserCollection;	//collection of ON/OFF mssgs = Users
	map<String, Timer> TimerCollection;		//collection of timers indxd by name
	map<String, Timer>::iterator CurrTimer;		//to keep track of active timer
	int item_number;	//currently picked (right-clicked, etc.) item on GUI list
	int contacts_width;	//width of Contacts list
	int timernames_width;	//width of leftmost (variable) pane of timers list
	String status1, status2;				//strings to display on status bar

	void ClearDisplay ();
	void updateClocks ();
	bool canNixWidth (bool caller_is_talker);

	void displayTestStuff (int what_test, String whatever);	//development only

	String getPathFilename(String filename, String extension);

	int getScrollPosition(HWND handle);
	void setScrollPosition(HWND handle, short int pos);

public:		// User declarations
	__fastcall TMainForm(TComponent* Owner);

	multimap<String, Message> MessageBuffer;	//collection of unread messages
	vector<Message> SendBuffer;				//collection of to-send messages
	String ini_filename;					//full-path name of ini file
	String hist_filename;					//full-path name of history file
	TStringList* hist_buffer;				//memory copy of history file
	TMessageActionForm* form_last_viewed;	//last message form that had focus

	//Timers management methods
	void addNewTimer ();
	void startTimer ();
	void stopTimer ();
	void doneWithTimer ();
	void cancelTimer ();
	void setOptions (int item_index);
	void manageTimerButtons ();

	//Messages management methods
	void openMessageForm (int what_item);
	void readMessage (TMessageActionForm* MessageActionForm);
	void sendMessage (TMessageActionForm* MessageActionForm, int what_item,
						String what_users_to);
	void broadcastMessage (TMessageActionForm* MessageActionForm);
	String doTransfer (Message& trans_out);
	void processServerTrans (String ServerResponse);
	void addToHistory(Message& what_messg);

	String DataCGI(String WhatName, String WhatValue);

	//Ini file management methods and properties
	void readIniFile ();
	void writeIniFile ();
	TStringList* ini_settings;

	//Other methods
	void playSound();
};

//---------------------------------------------------------------------------
extern PACKAGE TMainForm *MainForm;
//---------------------------------------------------------------------------
#endif
