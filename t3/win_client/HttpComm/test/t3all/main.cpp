
#include <iostream>
#include <string>
#include <map>
#include <fstream>
using namespace std;

#include "comm.h"

int main (int argc, char* argv[])
{
	string url = "http://www.barefoot.net/cgi-bin/t3test/talker_server?";

	ofstream fs("socket.log", ios::trunc);
	fs.close();

	map<string, string> attr;
	attr["status"] = "INFO";
	//attr["status"] = "LOGON";
	//attr["user"] = "Thong";

	T3Message t3im("MESSAGE", attr, "");
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
				string status = it->second.getAttribute("status");
				string from = it->second.getAttribute("from");

				cout << status.c_str() << "\t" << from.c_str() << "\n";
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
