//---------------------------------------------------------------------------
#include <vcl.h>
#pragma hdrstop

#include "TimersImp.h"

//---------------------------------------------------------------------------
#pragma package(smart_init)

//---------------------------------------------------------------------------
Timer::Timer (String what_name)
{
	name = what_name;

	hours = 0;
	minutes = 0;
	max_hours_bar = 10;		//by default time progress bar goes up to 10 hours
	showbar = false;
}
//---------------------------------------------------------------------------
void Timer::addMinute ()
{
	minutes += 1;

	if (minutes > 59)
	{
		hours += minutes / 60;
		minutes = minutes % 60;
	}
}
//---------------------------------------------------------------------------
String Timer::getElapsedTime ()
{
	String elapsed(hours);
	elapsed = elapsed + ':' + ( (minutes < 10) ? "0" : "" );
	elapsed += minutes;
	return elapsed;
}
//---------------------------------------------------------------------------
