
#include <iostream>
#include <string>
using namespace std;

#include "TimersImp.h"

//---------------------------------------------------------------------------
Timer::Timer (const string& name, const string& client,
			  const string& project, const string& phase)
	: m_name(name), m_client(client), m_project(project), m_phase(phase)
{
	m_breakdown = "";
	m_description = "";

	m_hours = 0;
	m_minutes = 0;
	m_active = false;
	m_halftime = false;
	m_half_toggle = false;

	return;
}
//---------------------------------------------------------------------------
Timer::Timer (const Timer& timer)
{
	m_name = timer.m_name;
	m_client = timer.m_client;
	m_project = timer.m_project;
	m_phase = timer.m_phase;
	m_breakdown = timer.m_breakdown;
	m_description = timer.m_description; 

	m_hours = timer.m_hours;
	m_minutes = timer.m_minutes;
	m_active = timer.m_active;
	m_halftime = timer.m_halftime;
	m_half_toggle = timer.m_half_toggle;

	return;
}
//---------------------------------------------------------------------------
Timer::Timer (const T3Message& t3msg)
{
	updateTimer(t3msg);
	return;
}
//---------------------------------------------------------------------------
void Timer::updateTimer (const T3Message& t3msg)
{
	m_name = t3msg.getAttribute("name");
	m_client = t3msg.getAttribute("client");
	m_project = t3msg.getAttribute("project");
	m_phase = t3msg.getAttribute("phase");
	m_active = (t3msg.getAttribute("status") == "ACTIVE");
	m_halftime = (t3msg.getAttribute("halftime") == "YES");
	setTime(atol(t3msg.getAttribute("elapsed").c_str()));
	m_breakdown = t3msg.getContent();

	return;
}
//---------------------------------------------------------------------------
void Timer::addMinute ()
{
	if ( (m_half_toggle || !m_halftime) && isActive() )
	{
		m_minutes += 1;
		if (m_minutes > 59)
		{
			m_hours += m_minutes / 60;
			m_minutes = m_minutes % 60;
		}
	}

	// only toggle if we are half-timing
	m_half_toggle = !m_half_toggle & m_halftime;

	return;
}
//---------------------------------------------------------------------------
void Timer::setActive (bool active)
{
	m_active = active;
	if ( !m_active )
	{
		m_halftime = false;
		m_half_toggle = false;
	}
	
	return;
}
//---------------------------------------------------------------------------
void Timer::setHalfTime (bool half)
{
	m_halftime = half;

	return;
}
//---------------------------------------------------------------------------
void Timer::setTime (long minutes)
{
	m_hours = minutes / 60;
	minutes = minutes - m_hours * 60;
	m_minutes = minutes;

	return;
}
//---------------------------------------------------------------------------
string Timer::getElapsedTime () const
{
	char str[80];
	sprintf(str, "%02d:%02d", m_hours, m_minutes);

	return string(str);
}
//---------------------------------------------------------------------------
void Timer::setOption (const string& key, const string& value)
{
	m_options[key] = value;
	return;
}
//---------------------------------------------------------------------------
string Timer::getOption (const string& key)	const
{
	string rc = "";
	map<string, string>::const_iterator it = m_options.find(key);
	if ( it != m_options.end() )
		rc = it->second;

	return rc;
}
//---------------------------------------------------------------------------
