


#include <iostream>
#include <string>
#include <map>
using namespace std;

#include "TimerMgr.h"
using namespace barefoot;

#include "comm.h"

#ifdef __WIN32__
	#include <windows.h>
	#include "TimerFcns.h"

	// set the static member
	unsigned int TimerMgr::m_tmrhandle = 0;
	HANDLE TimerMgr::m_tmrthread = 0;
	HANDLE TimerMgr::m_mutex = 0;
#endif
//------------------------------------------------------------------------------
TimerMgr::TimerMgr ()
	: m_new_data_avail(false)
{
	#ifdef __WIN32__

		// create a mutex
		::CreateMutex(NULL, false, "TIMERMGR_MUTEX");

	#endif
	
	return;
}
//------------------------------------------------------------------------------
TimerMgr::~TimerMgr ()
{
	#ifdef __WIN32__

		// kill the timer
		if ( m_tmrhandle )
		{
			::KillTimer(NULL, m_tmrhandle);
			m_tmrhandle = 0;
		}

		// kill the thread
		if ( m_tmrthread )
		{
			DWORD status;
			::GetExitCodeThread(m_tmrthread, &status);
			if ( status == STILL_ACTIVE )
			{
				// kill the sommbina bitch
				::TerminateThread(m_tmrthread, 0);
			}

			// free the handle
			::CloseHandle(m_tmrthread);
			m_tmrthread = 0;
		}

		// release the mutex
		if ( m_mutex )
		{
			WaitForSingleObject(m_mutex, INFINITE);
			::ReleaseMutex(m_mutex);
			::CloseHandle(m_mutex);
		}

	#endif
		
	return;
}
//------------------------------------------------------------------------------
void TimerMgr::setOptions (const map<string, string>& options)
{
	m_options = options;

	// get the ping interval
	int secs = atoi(m_options["timer_ping_interval"].c_str());
	setPingInterval(secs);


	return;
}
//------------------------------------------------------------------------------
bool TimerMgr::startTimer (const string& name, bool halftime)
{
	bool rc = false;

	TimerMap::iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
	{
		Timer timer(it->second);
		timer.setHalfTime(halftime);
		rc = startTimer(timer);
	}
	else
	{
		// The GUI should not let this happen?????
		m_errmsg = "Timer " + name + 
					" is not in the list of available timers.";
	}

	return rc;
}
//------------------------------------------------------------------------------
bool TimerMgr::startTimer (const Timer& timer)
{
	// create a Timer Message
	map<string, string> attr;
	attr["command"] = "START";
	attr["name"] = timer.getName();
	attr["client"] = timer.getClient();
	attr["project"] = timer.getProject();
	attr["phase"] = timer.getPhase();
    if ( timer.isHalfTime() )
        attr["halftime"] = "YES";

	return executeCommand(attr, "");
}
//------------------------------------------------------------------------------
bool TimerMgr::pauseTimer (const string& name)
{
	// create a Timer Message
	map<string, string> attr;
	attr["command"] = "PAUSE";
	attr["name"] = name;

	return executeCommand(attr, "");
}
//---------------------------------------------------------------------------
bool TimerMgr::cancelTimer (const string& name)
{
	map<string, string> attr;
	attr["command"] = "CANCEL";
	attr["name"] = name;

	return executeCommand(attr, "");
}
//---------------------------------------------------------------------------
bool TimerMgr::renameTimer (const string& oldname, const Timer& timer)
{
	map<string, string> attr;
	attr["command"] = "RENAME";
	attr["name"] = oldname;
	attr["client"] = timer.getClient();
	attr["project"] = timer.getProject();
	attr["phase"] = timer.getPhase();
    if ( timer.isHalfTime() )
        attr["halftime"] = "YES";

	return executeCommand(attr, timer.getName()); 
}
//---------------------------------------------------------------------------
bool TimerMgr::logTimer (const Timer& timer)
{
	map<string, string> attr;
	attr["command"] = "LOG";
	attr["name"] = timer.getName();
	attr["client"] = timer.getClient();
	attr["project"] = timer.getProject();
	attr["phase"] = timer.getPhase();

	return executeCommand(attr, timer.getDescription()); 
}
//---------------------------------------------------------------------------
bool TimerMgr::doneTimer (const Timer& timer)
{
	map<string, string> attr;
	attr["command"] = "DONE";
	attr["name"] = timer.getName();
	attr["client"] = timer.getClient();
	attr["project"] = timer.getProject();
	attr["phase"] = timer.getPhase();
    if ( timer.isHalfTime() )
        attr["halftime"] = "YES";

	return executeCommand(attr, timer.getDescription()); 
}
//------------------------------------------------------------------------------
bool TimerMgr::executeCommand (map<string, string>& attr,
							   const string& content)
{
	#ifdef __WIN32__
		// get access to this critical section
		::WaitForSingleObject(m_mutex, INFINITE);
	#endif
	
	// DEBUG
	//::MessageBox(NULL, "In Execute Command.", "DEBUG", MB_OK);

	bool rc = false;
	m_errmsg = "";

	// add common attributes
	attr["module"] = "TIMER";
	attr["user"] = m_options["user_name"];

	// create a message and received messages container
	T3Message msg("MESSAGE", attr, content);
	string curcmd = msg.getAttribute("command");

	T3MultiMap rcvmsgs;
	string url = m_options["server_url"];
	bool keeplog = !!atoi(m_options["test_mode"].c_str());
	int timeout = atoi(m_options["communication_timeout"].c_str());
	if ( sendT3Message(msg, rcvmsgs, "name", url, timeout, keeplog) )
	{
		// find the ack
		T3MultiMap::iterator it = rcvmsgs.begin();
		for ( ; it != rcvmsgs.end(); ++it )
		{
			if ( it->second.getAttribute("command") == curcmd )
			{
				if ( it->second.getContent() == "OK" )
				{
					// remove the nack
					rcvmsgs.erase(it);

					// set the return code
					rc = true;
				}
				else
				{
					// set the error message (skip FAIL:)
					m_errmsg = it->second.getContent().substr(5);
				}
				break;
			}
		}

		if ( it == rcvmsgs.end() )
		{
			// no ack was sent
			m_errmsg = "Protocol Error: Server failed to send an (n)ack.";
		}

		// update timer list 
		theTimerMgr().updateTimers(rcvmsgs);
	}
	else
	{
		// http failed, set error
		m_errmsg = "There was a communication problem at the HTTP layer.";
	}

	// DEBUG
	//::MessageBox(NULL, "Out Execute Command.", "DEBUG", MB_OK);

	#ifdef __WIN32__
		// we're done
		::ReleaseMutex(m_mutex);
	#endif

	return rc;
}
//------------------------------------------------------------------------------
void TimerMgr::setPingInterval (unsigned int seconds)
{

	#ifdef __WIN32__
		if ( seconds )
		{
			// don't allow anything less than a minute
			if ( seconds < 60 )
			{
				// default is 10 minutes
				seconds = 600;
			}

			// DEBUG
			//char str[50];
			//sprintf(str, "Using %d seconds for interval.", seconds);
			//::MessageBox(NULL, str, "DEBUG", MB_OK);

			if ( m_tmrhandle )
			{
				// kill the current timer
				::KillTimer(NULL, m_tmrhandle);
			}

			// start a new timer
			m_tmrhandle = ::SetTimer(NULL, 0, seconds * 1000, 
									 (TIMERPROC) TimerMgrProc);
		}
		else
		{
			// stop pinging
			if ( m_tmrhandle )
			{
				::KillTimer(NULL, m_tmrhandle);
				m_tmrhandle = 0;
			}
		}
	#endif

	return;
}
//------------------------------------------------------------------------------
bool TimerMgr::pingServer ()
{
	map<string, string> attr;
	attr["command"] = "LIST";

	return executeCommand(attr, ""); 
}
//------------------------------------------------------------------------------
void TimerMgr::pingServerInThread ()
{

	#ifdef __WIN32__
		if ( m_tmrthread )
		{
			// check the previous thread
			DWORD status;
			::GetExitCodeThread(m_tmrthread, &status);
			if ( status == STILL_ACTIVE )
			{
				// wait for the other thread to finish
				// TODO read options for wait state
				WaitForSingleObject(m_tmrthread, 60000);

				// check status again
				::GetExitCodeThread(m_tmrthread, &status);
				if ( status == STILL_ACTIVE )
				{
					// kill the sommbina bitch
					TerminateThread(m_tmrthread, 0);
				}
			}

			// free the handle
			CloseHandle(m_tmrthread);
			m_tmrthread = 0;
		}

		// create a thread
		DWORD dwid;
		m_tmrthread = CreateThread(NULL, 0, TimerThreadFunc, 0, 0, &dwid);
		if ( !m_tmrthread )
		{
			// TODO - HELP!!!!!!!!!
			::MessageBox(NULL, "Unable to create thread.", "Thread Error",
						 MB_OK | MB_ICONERROR);
		}

	#endif
	
	return;
}
//------------------------------------------------------------------------------
void TimerMgr::updateTimers (T3MultiMap& msgs)
{
	T3MultiMap::iterator it;
	TimerMap::iterator tt;

	// delete any timers that are no longer pertinent 
	for ( tt = m_timers.begin(); tt != m_timers.end(); ++tt )
	{
		if ( msgs.find(tt->first) == msgs.end() ) 
		{
			m_timers.erase(tt);
			--tt;
		}
	}

	// add any timers not in our list
	for (it = msgs.begin(); it != msgs.end(); it++)
	{
		string name = it->first;
		tt = m_timers.find(name);
		if ( tt == m_timers.end() )
		{
			// add timer
			m_timers.insert(make_pair(name, Timer(it->second)));
		}
		else
		{
			// update the timer
			tt->second.updateTimer(it->second); 
		}
	}

	// set the new data avail flag
	m_new_data_avail = true;

	return;
}
//---------------------------------------------------------------------------
void TimerMgr::addMinute ()
{
	// find the active timer
	TimerMap::iterator it = m_timers.begin();
	for ( ; it != m_timers.end(); ++it )
	{
		if ( it->second.isActive() )
		{
			it->second.addMinute();
			break;
		}
	}

	return;
}
//---------------------------------------------------------------------------
string TimerMgr::getActiveTimer () const
{
	string rc = "";

	// find the active timer
	TimerMap::const_iterator it = m_timers.begin();
	for ( ; it != m_timers.end(); ++it )
	{
		if ( it->second.isActive() )
		{
			rc = it->second.getName();
			break;
		}
	}

	return rc;
}
//---------------------------------------------------------------------------
string TimerMgr::getTimerClient (const string& name) const
{
	string rc = "";

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		rc = it->second.getClient();

	return rc;
}
//---------------------------------------------------------------------------
string TimerMgr::getTimerPhase (const string& name) const
{
	string rc = "";

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		rc = it->second.getPhase();

	return rc;
}
//---------------------------------------------------------------------------
string TimerMgr::getTimerProject (const string& name) const
{
	string rc = "";

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		rc = it->second.getProject();

	return rc;
}
//---------------------------------------------------------------------------
string TimerMgr::getTimerDescription (const string& name) const
{
	string rc = "";

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		rc = it->second.getDescription();

	return rc;
}
//---------------------------------------------------------------------------
string TimerMgr::getTimerDate (const string& name) const
{
	string rc = "";

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		rc = it->second.getDate();

	return rc;
}
//---------------------------------------------------------------------------
string TimerMgr::getElapsedTime (const string& name) const
{
	string rc = "";

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		rc = it->second.getElapsedTime();

	return rc;
}
//---------------------------------------------------------------------------
int TimerMgr::getTimerMinutes (const string& name) const
{
	int min = 0;

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		min = it->second.getMinutes();

	return min;
}
//---------------------------------------------------------------------------
int TimerMgr::getTimerHours (const string& name) const
{
	int hours = 0;

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		hours = it->second.getHours();

	return hours;
}
//---------------------------------------------------------------------------
bool TimerMgr::isTimerActive (const string& name) const
{
	bool rc = false;

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		rc = it->second.isActive();


	return rc;
}
//---------------------------------------------------------------------------
bool TimerMgr::isTimerHalfTime (const string& name) const
{
	bool rc = false;

	TimerMap::const_iterator it = m_timers.find(name);
	if ( it != m_timers.end() )
		rc = it->second.isHalfTime();


	return rc;
}
//---------------------------------------------------------------------------
StringList TimerMgr::getTimerNames () const
{
	StringList rc;

	TimerMap::const_iterator it = m_timers.begin();
	for ( ; it != m_timers.end(); ++it )
		rc.Add(it->second.getName());

	return rc;
}
//---------------------------------------------------------------------------
