#ifndef __timermgr_h__
#define __timermgr_h__

#include <iostream>
#include <string>
#include <map>
using namespace std;

#include "TimersImp.h"
#include "stringlist.h"
using namespace arinbe;

namespace barefoot
{
	class TimerMgr
	{
	public:
		TimerMgr ();
		~TimerMgr ();

		void setOptions (const map<string, string>& options);
		void setPingInterval (unsigned int seconds);
		bool pingServer ();
		bool isNewDataAvail () { return m_new_data_avail; };
		void clearNewDataAvail () { m_new_data_avail = false; };

		void pingServerInThread ();

		bool startTimer (const Timer& timer);
		bool startTimer (const string& name, bool halftime);
		bool pauseTimer (const string& name);
		bool cancelTimer (const string& name);
		bool renameTimer (const string& oldname, const Timer& timer);

		bool logTimer (const Timer& timer);
		bool doneTimer (const Timer& timer);

		bool deleteTimer (const string& name);
		bool isTimerActive (const string& name) const;
		bool isTimerHalfTime (const string& name) const;

		StringList getTimerNames () const;
		StringList getTimerBreakdown (const string& name) const;

		string getActiveTimer () const;
		void addMinute ();

		int getTimerMinutes (const string& name) const;
		int getTimerHours (const string& name) const;

		string getTimerClient (const string& name) const;
		string getTimerPhase (const string& name) const;
		string getTimerProject (const string& name) const;
		string getTimerDescription (const string& name) const;
		string getTimerDate (const string& name) const;
		string getTimerOption (const string& tmrname, 
							   const string& optname) const;
		string getElapsedTime (const string& tmrname) const;

		void setTimerOption (const string& tmrname, const string& optname,
							 const string& value);

		// retrieves the last error message
		string getLastError () const { return m_errmsg; };

	protected:

		// update the list of timers from T3 message list
		void updateTimers (T3MultiMap& msgs);
		bool executeCommand (map<string, string>& attr, 
							 const string & content);

		Timer getTimer (const string& name) const;

	private:

		#ifdef __WIN32__
			static unsigned int m_tmrhandle;
			static HANDLE m_tmrthread;
			static HANDLE m_mutex;
		#endif
		
		bool m_new_data_avail;

		TimerMap m_timers;
		map<string, string> m_options;

		string m_errmsg; 

		void lockMutex () const;
		void unlockMutex () const;
	};

	// singleton function
	TimerMgr& theTimerMgr ()
	{
		// create a singleton
		static TimerMgr ttm;
		return ttm;
	};


};

#endif
