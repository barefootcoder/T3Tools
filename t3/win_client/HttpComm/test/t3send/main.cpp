
#include <iostream>
#include <string>
#include <map>
#include <fstream>
using namespace std;

#include "comm.h"

int main (int argc, char* argv[])
{
	if ( argc < 3 )
	{
		cout << "usage t3send username \"message\"" << endl;
		cout << endl;  
		return 0;
	}

	string url = "http://www.barefoot.net/cgi-bin/t3/Barefoot/talker_server?";

	ofstream fs("socket.log", ios::trunc);
	fs.close();

	map<string, string> attr;
	attr["status"] = "NO_REPLY";
	attr["to"] = argv[1];
	attr["from"] = "beeker";

	T3Message t3im("MESSAGE", attr, argv[2]);
	T3MultiMap t3rm;
	for ( int i = 0; i < 2; ++i )
	{
		if ( sendT3Message(t3im, t3rm, url, 2, true) )
		{
			cout << "Message sent successfully.\n";
			cout << "Displaying information:\n";

			// display the status of everyone
			T3MultiMap::const_iterator it = t3rm.begin();
			for ( ; it != t3rm.end(); it++)
			{
				cout << it->second.toXML() << endl;
			}

			// done
			break;
		}
		else
		{
			// failed 
			cout << "Try " << i << " failed.\n";
		}
	}
	
	return 0;
}
