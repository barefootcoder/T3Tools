//---------------------------------------------------------------------------
#ifndef TimersImpH
#define TimersImpH
//---------------------------------------------------------------------------



const TDateTime one_minute(0,1,0,0);

//---------------------------------------------------------------------------
class Timer
{
public:
	Timer (String what_name);

	void addMinute ();
	String getElapsedTime ();

	String name;
	String client;
	String description;
	int hours;
	int minutes;
	int max_hours_bar;			//max length of progress bar - set by user
	bool showbar;

};

//---------------------------------------------------------------------------
#endif
