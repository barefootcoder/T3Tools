#ifndef __HttpComponent_h__
#define __HttpComponent_h__

#include "Socket.h"
#include "stringlist.h"
using namespace arinbe;

namespace arinbe
{
	typedef struct HTTPRequest 
	{
		StringList headers;
		StringList message;
		bool  	error;
		string	error_description;

		HTTPRequest ()
		{
			headers.Text("");
			message.Text("");
			error = false;
		}

	} HTTPRequest;

	class HttpComponent : protected Socket
	{

	public:

		HttpComponent (const string& url, int timeout);
		virtual ~HttpComponent();

		static string urlEscape (const string& str);
		static string urlUnescape (const string& str);

		HTTPRequest sendHttpRequest ();
		HTTPRequest sendHttpRequest (const StringList& hdrs, 
									 const string& post);

	protected:

		bool sendHeaders (const StringList& hdrs, const string& post);
		HTTPRequest parseResponse (const string& data);

	private:

		string m_error_description;

	};
};

#endif
