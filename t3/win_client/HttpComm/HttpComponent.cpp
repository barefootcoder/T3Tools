#include <iostream>
#include <cstdio>
#include <string>
using namespace std;

#include "HttpComponent.h"

//------------------------------------------------------------------------------
HttpComponent::HttpComponent (const string& url, int timeout)
: Socket (url, timeout)
{
	return;
}
//------------------------------------------------------------------------------
HttpComponent::~HttpComponent ()
{
	return;
}
//------------------------------------------------------------------------------
string HttpComponent::urlEscape (const string& str)
{
	const char hex_char [] = "0123456789ABCDEF"; 
	string result;

	for ( int i = 0; i < (int) str.length(); ++i )
	{
		if ( isalnum(str[i]) ) // Don't escape letters or digits 
			result += str[i];
		else if (str[i] == ' ')	// Spaces are replaced by '+' 
			result += '+';
		else if (str[i] == '\n')
			result += "%0A";
		else if (str[i] == '\r')
			result += "%0D";
		else
		{
			result += '%';    // Some other escaped character 
			result += hex_char [str[i] >> 4]; 
			result += hex_char [str[i] & 15]; 
		} 
	} 

	return result;
}
//------------------------------------------------------------------------------
string HttpComponent::urlUnescape (const string& str)
{
	// This lookup table gives us a quick way to convert a hex digit
	// into a binary value. Note that the index must be [0..127].
	static char hex_to_bin [128] = { 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,	/* */ 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,	/* */ 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,	/* */ 
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0,	/* 0..9 */ 
		0,10,11,12,13,14,15, 0, 0, 0, 0, 0, 0, 0, 0, 0,	/* A..F */ 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,	/* */ 
		0,10,11,12,13,14,15, 0, 0, 0, 0, 0, 0, 0, 0, 0,	/* a..f */ 
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; /* */

	string result = "";
	
	for ( int i = 0; i < (int) str.length(); ++i )
	{
		if ( str[i] == '+' )
			result += ' ';
		else if ( str[i] == '%' )
		{
			result += (char) (hex_to_bin [str[i + 1] & 127] * 16 
								+ hex_to_bin [str[i + 2] & 127]);
			i += 2;
		}
		else
			result += str[i];
	}

	return result;
}
//------------------------------------------------------------------------------
HTTPRequest HttpComponent::sendHttpRequest ()
{
	StringList tmp1;
	string tmp2 = "";

	return sendHttpRequest(tmp1,tmp2);
}
//------------------------------------------------------------------------------
HTTPRequest HttpComponent::sendHttpRequest (const StringList& headers,
											const string& post)
{
	m_error_description = "";
	string resp_data = "";
	if ( sendHeaders(headers, post) )
	{
		// send the post
		if ( post.length() )
			sendString(post);

		string buf = "";
		int num_bytes = 256;
		while ( recvString(buf, num_bytes) )
		{
			if ( !num_bytes )
				break;

			resp_data += buf;
			buf = "";
			num_bytes = 256;
		}
	}
	else
	{
		// sendHeaders failed
		m_error_description = "Unable to send header information.";
	}

	return parseResponse(resp_data);
}
//------------------------------------------------------------------------------
bool HttpComponent::sendHeaders (const StringList& headers, const string& post)
{
	bool result;

	// send request
	if ( post.length() )
	{
		result = sendString("POST " + m_request + " HTTP/1.0\r\n");

		char str[50];
		sprintf(str, "Content-Length: %d\r\n", post.length());
		sendString(str);
	}
	else
	{
		result = sendString("GET " + m_request + " HTTP/1.0\r\n");
	}

	// send headers
	if ( result )
		result = sendString("User-Agent: Mozilla/4.0\r\n");

	if ( result )
		result = sendString("Host: " + m_host + "\r\n");

	// send other headers
	if ( headers.Count() && result )
		result = sendString(headers.Text());

	// finish headers
	if ( result )
		result = sendString("\r\n");

	return result;
}
//------------------------------------------------------------------------------
HTTPRequest HttpComponent::parseResponse (const string& data)
{
	HTTPRequest result;

	if ( data.length() )
	{
		int pos = data.find("\r\n\r\n");
		if ( pos > -1 )
		{
			result.headers.Text(data.substr(0, pos));
			result.message.Text(data.substr(pos + 4));
			result.error = false;
		}
		else
		{
			// error?
			result.headers.Text("");
			result.message.Text(data);
			m_error_description = "Could not find body in returned data.";
			result.error = true;
		}
	}
	else
	{
		// set the error flag
		result.headers.Text("");
		result.message.Text("");
		result.error = true;
		m_error_description = "No data returned.";
	}

	if ( result.error )
	{
		// if an error, set the description
		result.error_description = m_error_description;
	}

	return result;
}
//------------------------------------------------------------------------------
