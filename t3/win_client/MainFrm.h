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
#include <ComCtrls.hpp>
#include <MPlayer.hpp>
#include <Menus.hpp>

#include <map>
#include <string>
#include <vector>
using namespace std;

#include "TimerMgr.h"
using namespace barefoot;

#include "TimersImp.h"
#include "T3Message.h"
#include "TimerActionFrm.h"

const String CONNECTING_TO_SERVER = "COMMUNICATING";		//display on status bar
const String CONNECT_ERROR = "CANNOT CONNECT TO SERVER";
const String CONNECT_ERROR_STATUS = "ERROR COMMUNICATING";	//display on status bar

const int TIMER_DIGITS_WIDTH = 80;
const int TIMER_ICONS_WIDTH = 212;
const int SPACE_AFTER_DIGITS = 16;
const int SPACE_BEFORE_NAMES = 2;
const int DIGITS_PLUS_ICONS = TIMER_DIGITS_WIDTH + SPACE_AFTER_DIGITS
												 + TIMER_ICONS_WIDTH;

class TMessageActionForm;	//just forward declaration

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
	TImage *RunningDude;
	TImage *ImOn;
	TImage *ImageOff;
	TImage *ImageOn;
	TTimer *MessageTimer;
	TTimer *Blinker;
	TImage *Options;
	TStatusBar *StatBar;
	TImage *ImageBusy;
	TMediaPlayer *SoundPlayer;
	TImageList *MinutesRed;
	TImageList *MinutesBlack;
	TImageList *HoursRed;
	TImageList *HoursBlack;
	TImageList *ContactsGlyphs;
	TImage *InTransit;
	TImageList *TimerIcons;
	TPopupMenu *mnuTimerCmd;
	TMenuItem *mnuStart;
	TMenuItem *mnuFullTime;
	TMenuItem *mnuHalfTime;
	TMenuItem *mnuPauseTimer;
	TMenuItem *mnuDoneTimer;
	TMenuItem *mnuCancelTimer;
	TMenuItem *mnuOptions;
	TMenuItem *mnuBarMaxHours;
	TMenuItem *N1;
	TMenuItem *mnuBreakdownTimer;
	TMenuItem *N2;
	TMenuItem *mnuTotalTimer;
	TPopupMenu *mnuTimerNew;
	TMenuItem *mnuNewTimer;
	TMenuItem *mnuLogTimer;
	TMenuItem *N3;
	TMenuItem *mnuTotalTimer2;
	TMenuItem *mnuRename;
	TMenuItem *mnuUseBars;
	TMenuItem *mnuUpdate;
	TMenuItem *mnuUpdate2;
	TImageList *MessageIcons;
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
	void __fastcall HideContactsClick(TObject *Sender);
	void __fastcall HideTimersClick(TObject *Sender);
	void __fastcall RunningDudeClick(TObject *Sender);
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
	void __fastcall FormKeyDown(TObject *Sender, WORD &Key,
          TShiftState Shift);
	void __fastcall InTransitClick(TObject *Sender);
	void __fastcall mnuNewTimerClick(TObject *Sender);
	void __fastcall mnuLogTimerClick(TObject *Sender);
	void __fastcall mnuFullTimeClick(TObject *Sender);
	void __fastcall mnuHalfTimeClick(TObject *Sender);
	void __fastcall mnuTotalTimerClick(TObject *Sender);
	void __fastcall mnuBreakdownTimerClick(TObject *Sender);
	void __fastcall mnuCancelTimerClick(TObject *Sender);
	void __fastcall mnuDoneTimerClick(TObject *Sender);
	void __fastcall mnuPauseTimerClick(TObject *Sender);
	void __fastcall mnuRenameClick(TObject *Sender);
	void __fastcall mnuBarMaxHoursClick(TObject *Sender);
	void __fastcall mnuUseBarsClick(TObject *Sender);
	void __fastcall mnuUpdateClick(TObject *Sender);
private:	// User declarations

	// Timer Message Manager
	TimerMgr& m_tmrmgr;

	bool newmode;
	bool online;							//this user is on-line for messaging
	bool available;							//this user is available to talk
	bool have_messages;						//there's new messages to read
	bool busy_on_shut_down;
	bool blink;
	bool hidden_timer_panes[3];				//to keep track of timer panes display
	bool no_timer_update;					//prevents repainting of the timers
	unsigned __int64 message_base_id;		//64-bit message id for a session

	int contacts_width;	//width of Contacts list
	int timernames_width;	//width of leftmost (variable) pane of timers list

	//helper methods
	void ClearDisplay ();
	void updateClocks ();
	bool canNixWidth (bool caller_is_talker);

	int getScrollPosition(HWND handle);
	void setScrollPosition(HWND handle, short int pos);
	void keepWithinScreen();

	void doContactMaintenance ();
	void doTimerMaintenance ();

public:		// User declarations
	__fastcall TMainForm(TComponent* Owner);

			//TO REMOVE
	multimap<string, T3Message>* pMessageBuffer;	//collection of unread messages
	multimap<string, T3Message>* pStatusBuffer;	//collectn of unprocessed status
	map<string, T3Message>* pUserCollection;	//collection of ON/OFF mssgs = Users
	vector<string>* puser_list;

	TMessageActionForm* form_last_viewed;	//last message form that had focus
	String status1, status2;				//strings to display on status bar

	//Timers management methods
	void activateTimerFeatures();

	//Messages management methods
	void ferryMessage(T3Message what_messg);		//the only message-out gateway

	void openMessageForm (int what_item);
	void readMessage (TMessageActionForm* MessageActionForm);
	bool sendMessage (TMessageActionForm* MessageActionForm, int what_item,
						String what_users_to);
	void broadcastMessage (TMessageActionForm* MessageActionForm);
	void sendStatusMessage (String what_status);

	//Ini file management methods and properties
	void initApp ();
	void cleanupApp ();
	//TStringList* ini_settings;

	//Other methods
	void playSound();
};

//---------------------------------------------------------------------------
extern PACKAGE TMainForm *MainForm;
//---------------------------------------------------------------------------
#endif
