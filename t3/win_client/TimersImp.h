//---------------------------------------------------------------------------
#ifndef TimersImpH
#define TimersImpH
//---------------------------------------------------------------------------

#include <string>
using namespace std;

#include "T3Message.h"

class Timer;
typedef map<string, Timer> TimerMap;

class Timer
{
public:
	Timer (const string& name, const string& client = "",
		   const string& project = "", const string& phase = "");
	Timer (const Timer& timer);
	Timer (const T3Message& t3msg);

	void updateTimer (const T3Message& t3msg);

	void addMinute ();
	void setTime (long minutes);
	void setHalfTime (bool active);
	void setActive (bool active);
	string getElapsedTime () const;

	int getHours () const { return m_hours; };
	int getMinutes () const { return m_minutes; };

	string getName () const { return m_name; };
	void setName (const string& n) { m_name = n; };

	string getClient () const { return m_client; };
	void setClient (const string& c) { m_client = c; };

	string getProject () const { return m_project; };
	void setProject (const string& c) { m_project = c; };

	string getPhase () const { return m_phase; };
	void setPhase (const string& c) { m_phase = c; };

	string getDescription () const { return m_description; };
	void setDescription (const string& d) { m_description = d; };

	string getDate () const { return m_date; };
	void setDate (const string& d) { m_date = d; };

	string getBreakdown () const { return m_breakdown; };
	void setBreakdown (const string& b) { m_breakdown = b; };

	string getOption (const string& key) const;
	void setOption (const string& key, const string& value);

	bool isActive () const { return m_active; };
	bool isHalfTime () const { return m_halftime; };

private:

	string m_name;
	string m_client;
	string m_project;
	string m_phase;
	string m_date;
	string m_description;
	string m_breakdown;

	int m_hours;
	int m_minutes;

	// sets the active state
	bool m_active;
	bool m_halftime;
	bool m_half_toggle;

	map<string, string> m_options;
};

//---------------------------------------------------------------------------
#endif
