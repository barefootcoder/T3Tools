//---------------------------------------------------------------------------

#include <sstream>

#include "httpcomm.h"

//for development testing only
//#include <fstream>
//ofstream testfile("socket.log", ios::app);


//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

int HTTPComm::doGet(string& receive_buffer, string URL, bool simple, bool keep_log)
{
	parseURL(URL);

	string data_out = "GET ";
	data_out += server_URI;

	if (simple)
	{
		data_out += HTTP_NEWLINE;
		data_out += HTTP_NEWLINE;
	}
	else
	{
		data_out += ' ';
		data_out += HTTP_VERSION;
		data_out += HTTP_NEWLINE;
		data_out += client_headers;		//must terminate with HTTP_NEWLINE
		data_out += HTTP_NEWLINE;
	}

	int result;
	result = doTransfer(data_out, receive_buffer, keep_log);

	return result;
}
//---------------------------------------------------------------------------

int HTTPComm::doPost(string& receive_buffer, string URL, bool keep_log)
{
	parseURL(URL);

	ostringstream data_to_send;
	data_to_send << "POST " << server_URI << ' ' << HTTP_VERSION << HTTP_NEWLINE;
	data_to_send << client_headers;	//must already terminate with HTTP_NEWLINE
	//always add Content-Length -- don't rely on supplied headers:
	data_to_send << "Content-Length: " << client_body.size() << HTTP_NEWLINE;
	data_to_send << HTTP_NEWLINE;	//separator between headers and body
	data_to_send << client_body;

	int result;
	result = doTransfer(data_to_send.str(), receive_buffer, keep_log);

	return result;
}
//---------------------------------------------------------------------------

void HTTPComm::parseURL(string URL)
{
	//split the URL into server IP/domain and URI

	unsigned int pos;
	if ((pos = URL.find("http://")) == 0)		//remove protocol identifier
		URL.erase(0, 7);
	else if ((pos = URL.find("HTTP://")) == 0)
		URL.erase(0, 7);

	if ((pos = URL.find('/')) != URL.npos)		//locate start of URI
	{
		server_addr = URL.substr(0, pos);
		server_URI = URL;
		server_URI.erase(0, pos);
	}
	else										//only server name/IP was given
	{
		server_addr = URL;
		server_URI = '/';
	}

	 urlEncode(server_URI, true);

}
//---------------------------------------------------------------------------

void HTTPComm::strToVector(string& headers, vector<string>& vheaders)
{
	//converts a string of items separated by eol's into a vector
	//and reformats the string into http-standardized eol's

	//remove any leading whitespace in the string
	//this is mostly to get rid of faux header set accidentally made up of WS 
	string::iterator it;
	while ((it = headers.begin()) != headers.end())
	{
		if (isspace(*it))
			headers.erase(it);
		else
			break;
	}

	//does not overwrite the vector if the string was empty
	//(this allows passing data exclusively through a vector)
	if (!headers.empty())
	{
		vheaders.clear();			//clean out old data from vector
		if (*(headers.end() - 1) != '\n')
			headers += '\n';		//make sure last item has newline
		size_t pos;
		while ((pos = headers.find('\r')) != headers.npos ||
			   (pos = headers.find('\n')) != headers.npos )
		{
			vheaders.push_back(headers.substr(0, pos));
			while (headers[++pos] == '\n' || headers[pos] == '\r');
			headers.erase(0, pos);
		}
	}

	//but overwrites the string with whatever is now in the vector
	vectorToStr(vheaders, headers);
}
//---------------------------------------------------------------------------

void HTTPComm::vectorToStr(vector<string>& vheaders, string& headers)
{
	//converts a vector of items into a string with the items separated by
	//newlines as defined in HTTP_NEWLINE

	headers.clear();

	for (size_t i = 0; i < vheaders.size(); i++)
	{
		headers += vheaders[i];
		headers += HTTP_NEWLINE;
	}

}
//---------------------------------------------------------------------------

void HTTPComm::splitHeaders(string& all_data, string& headers_str,
										vector<string>& headers)
{
	//removes headers from all_data and places them in headers_str and headers

	string divider = HTTP_NEWLINE + HTTP_NEWLINE;
	size_t pos;			//position of divider between headers and data
	pos = all_data.find(divider);

	headers_str = all_data.substr(0, pos);
	headers_str += HTTP_NEWLINE;
	all_data.erase(0, pos + divider.length());

	strToVector(headers_str, headers);	//copy them to the vector too
}
//---------------------------------------------------------------------------

void HTTPComm::urlEncode(string& whatstr, bool url_string)
{
	//for url_string assumes whatstr is a url and encodes accordingly, else
	//performs encoding used by application/x-www-form-urlencoded media type
	//where whatstr must be supplied as name=value's separated by eol's
	//or as a url -- in the latter case, url_string must be set

	size_t pos;
	while ((pos = whatstr.find(' ')) != whatstr.npos)
		whatstr.replace(pos, 1, 1, '+');	//all spaces must be encoded

	string temp_uri;
	if (url_string)
	{
		pos = whatstr.find('?');
		if (pos == string::npos)	//if it's just the uri, we're done here, but
			return;					//may need to encodeStr() -- add later if so

		//otherwise need to deal with search string (form data passed as get)
		temp_uri = whatstr.substr(0, pos + 1);		//the uri portion + '?'
		whatstr.erase(0, pos + 1);					//only the search string
		//convert search string to our same format used as if it were in a post
		bool in_quotes = false;
		for (size_t i = 0; i < whatstr.size(); i++)
		{
			if (whatstr[i] == '\"')
				in_quotes = !in_quotes;
			if (in_quotes)
				continue;
			if (whatstr[i] == '&')
				whatstr[i] = '\n';
		}
	}

	if (whatstr.empty())		//insurance check to avoid needless processing
	{
		whatstr += temp_uri;
		return;
	}

	//at this point all form data is in the same format (i.e., name=value pairs
	//separated by a valid eol) regardless of whether they came from get or post

	vector<string> pairs;
	strToVector(whatstr, pairs);	//separate out each name=value pair

	whatstr.clear();				//now will rebuild whatstr, encoded version
	if (url_string)
		whatstr += temp_uri;

	for (vector<string>::iterator vi = pairs.begin(); vi != pairs.end(); vi++)
	{
		pos = (*vi).find('=');
		string value = (*vi).substr(pos + 1);
		encodeStr(value);
		(*vi).erase(pos + 1);		//erase existing unencoded value
		(*vi) += value;				//and replace it with newly-encoded value
		if (vi != pairs.begin())
			whatstr += '&';
		whatstr += (*vi);			//build up the url-encoded form data
	}

}
//---------------------------------------------------------------------------

void HTTPComm::encodeStr(string& whatstr)
{
	//url-encode all characters except alphanumeric and '+'
	for (size_t i = 0; i < whatstr.size(); i++)
	{
		if(isalnum(whatstr[i]) || whatstr[i] == '+')
			continue;
		else
		{
			ostringstream hexencode;
			hexencode << '%' << hex << int(whatstr[i]);
			whatstr.replace(i, 1, hexencode.str());
		}
	}

}
//---------------------------------------------------------------------------

