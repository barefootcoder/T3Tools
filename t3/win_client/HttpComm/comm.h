
#ifndef __comm_h__
#define __comm_h__

#include <iostream>
#include <map>
#include <string>
using namespace std;

#include "HttpComponent.h"
using namespace arinbe;

#include "T3Message.h"


bool sendT3Message (const T3Message& IMessage, T3MultiMap& rcvimsgs,
					const string& attr_name,
					const string& server_url, int timeout, bool keep_log);

void buildRecvdIMmap (const string& rcvdstr, T3MultiMap& recvd_messages,
					  const string& attr_name);

void writeLog (const string& post, const HTTPRequest& req,
				const T3MultiMap& recvd);
#endif
