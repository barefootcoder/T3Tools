#ifndef __Socket_h__
#define __Socket_h__
		 
#include <iostream>
#include <string>
using namespace std;

namespace arinbe
{
	class Socket
	{

	public:

		Socket (const string& url, int timeout);
		virtual ~Socket ();

		bool isConnected ();
		bool sendString (const string& data);
		bool recvString (string& data, int& num_bytes);

	protected:

		virtual int getPortByName();

		void parseURL ();

		bool m_connected;

		int m_socket;
		int m_port;
		int m_timeout;

		string m_protocol;
		string m_host;
		string m_request; 
		string m_url;
	};

};

#endif
