#include <iostream>
#include <string>
using namespace std;

#ifdef __WIN32__
  	#include <winsock.h>
#else
	#include <sys/types.h>
	#include <sys/socket.h>
	#include <sys/time.h>
	#include <netinet/in.h>
	#include <arpa/inet.h>
	#include <netdb.h>
	#include <unistd.h>
	#include <errno.h>
#endif

#include "Socket.h"
using namespace arinbe;
//------------------------------------------------------------------------------
Socket::Socket (const string& url, int timeout)
{		 
	m_url = url;
	m_host = "";
	m_protocol = "";

	parseURL();

	if ( m_host.length() )
	{
		m_socket = socket(AF_INET, SOCK_STREAM, 0);
		if ( m_socket > 0 )
		{
			struct hostent* h = gethostbyname(m_host.c_str());
			if ( h )
			{
				struct sockaddr_in sin;
				sin.sin_family = AF_INET;
				sin.sin_port = htons((unsigned short) m_port);
				memcpy((char *)&sin.sin_addr.s_addr,
					   h->h_addr_list[0], h->h_length);

				if ( !connect(m_socket, (struct sockaddr *)&sin, sizeof(sin)) )
				{
					m_connected = true;
				}
			}
		}
	}

	return;
}
//------------------------------------------------------------------------------
Socket::~Socket ()
{
	if ( isConnected() )
	{
		#ifdef __WIN32__
			closesocket(m_socket);
		#else
			close(m_socket);
		#endif
	}

	return;
}
//------------------------------------------------------------------------------
bool Socket::isConnected ()
{
	return m_connected;
}
//------------------------------------------------------------------------------
void Socket::parseURL ()
{
	int prpos = m_url.find("://");
	if ( prpos > -1 )
	{
		m_protocol = m_url.substr(0, prpos);

		int ptpos = m_url.find(":", prpos + 3);
		if ( ptpos > -1 )
		{
			// port is an integer after the :
			string port = m_url.substr(ptpos + 1); 
			m_port = atoi(port.c_str());

			m_host = m_url.substr(prpos + 3, ptpos - (prpos + 3));
		}
		else
		{
			// no port was specified
			m_port = getPortByName();
		}

		int reqpos = m_url.find("/", prpos + 3);
		if ( reqpos > -1 )
		{
			// request is the rest of string after the last /
			m_request = m_url.substr(reqpos); 

			if ( ptpos < 0 )
				m_host = m_url.substr(prpos + 3, reqpos - (prpos + 3));
		}
		else
		{
			// create a default request
			m_request = "/";
		}

		if ( !m_host.length() )
			m_host = m_url.substr(prpos + 3);
	}

	return;
}
//------------------------------------------------------------------------------
bool Socket::sendString (const string& data)
{
	bool result = false;

	if ( isConnected() )
	{
		if ( send(m_socket, data.c_str(), data.length(), 0) > 0 )
			result = true;
	}

	return result;
}
//------------------------------------------------------------------------------
bool Socket::recvString (string& data, int& num_bytes)
{
	bool result = false;

	if ( num_bytes > 1 )
	{	
		struct timeval timeout;
		timeout.tv_sec = m_timeout;	//timeout in secs if unavailable data
		timeout.tv_usec = 0;
		fd_set readfds;				//the set of file descriptors to read
		FD_ZERO(&readfds);			//start with none
		FD_SET(m_socket, &readfds);	//and just add our friendly socket to it

		select(m_socket + 1, &readfds, NULL, NULL, &timeout);

		if (FD_ISSET(m_socket, &readfds))
		{
			char* buf = new char[num_bytes];
			int len = recv(m_socket, buf, num_bytes - 1, 0);
			if ( len > -1 ) 
			{
				buf[len] = '\0';
				data = buf;
				num_bytes = len;
				result = true;
			}

			// free buffer
			delete buf;
		}
	}

	return result;
}
//------------------------------------------------------------------------------
int Socket::getPortByName ()
{
	int result = 0;
	if ( m_protocol.length() )
	{
		//if ( !strcasecmp("http", m_protocol.c_str()) )
		if ( !strcmp("http", m_protocol.c_str()) )
			result = 80;
	}

	return result;
}
//------------------------------------------------------------------------------
