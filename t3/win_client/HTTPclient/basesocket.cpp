//---------------------------------------------------------------------------

#if defined(__WIN32__)
	//include required for Windows Sockets 2
	#include <winsock2.h>
#elif defined(__linux__)
	//includes required for Linux (Berkeley) sockets
	#include <sys/types.h>
	#include <sys/socket.h>
	#include <netinet/in.h>
	#include <netdb.h>
	#include <arpa/inet.h>
	#include <unistd.h>
	#include <sys/time.h>
#endif

namespace private_ftime		//needed because ftime conflicts w/ std::ftime
{
	#include <sys\timeb.h>
}

#include <iostream>
#include <fstream>


#include "basesocket.h"
//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

BaseSocket::BaseSocket()
{
	//set defaults
	server_port = SERVER_PORT;
	server_addr == SERVER_ADDR;
	time_out_secs = TIME_OUT_SECS;
}
//---------------------------------------------------------------------------

int BaseSocket::doTransfer(string data_to_send, string& data_received, bool keep_log) const
{
	//This function opens a socket, communicates w/ server, and closes socket
	//The content of this function is OS-specific so the code is #ifdef'd for
	//	each supported OS.
	//In addition, this code is very specific to the socket implementation
	//	being used.  To use a different socket implementation, write the code
	//  for it and comment out or #ifdef the currently-active full round-trip
	//  code for your OS implementation.

	//March 2001 -- for Win32, the socket version used is WS2_32.DLL which is
	//				Microsoft's latest implement of Berkeley sockets. The full
	//				WinSocket2 differs significantly from Berkeley sockets, but
	//				to preserve as much isomorphism as possible among the various
	//				OSes, this code uses where possible the functions that are
	//				more like Berkeley sockets.
	//			 -- for Linux, this code uses the Berkeley sockets implement
	//				that comes with the Linux kernel.


	if (keep_log)
	{
		string out_data;
		out_data += "---- DATA CLIENT WANTS TO SEND TO SERVER ----\n";
		out_data += data_to_send;
		out_data += "\n------------ END OF DATA TO SEND ------------";
		writeLog(SHOW_DATA_TO_SEND, out_data);
	}

  #if defined(__WIN32__)		//if we are compiling this for Win32 Windows

	//use Windows API calls and WS2_32.DLL to establish a TCP/IP communications

	WSADATA wsaData;
	int result = WSAStartup(MAKEWORD(2,0), &wsaData);	//requires version 2.0

	if (result)		//0 means success
	{
		//could not find a usable WinSock DLL
		if (keep_log) writeLog(ERR_NODLL);
		return EXIT_FAILURE;
	}
	if ( LOBYTE(wsaData.wVersion) != 2 || HIBYTE(wsaData.wVersion) != 0 )
	{
		//could not find version 2.0 or higher of WinSock DLL.
		if (keep_log) writeLog(ERR_NODLL);
		WSACleanup();
		return EXIT_FAILURE;
	}

	//The WinSock DLL is acceptable. Proceed.
	if (keep_log) writeLog(GOOD_DLL);

	SOCKET socket1 = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);

	if (socket1 == INVALID_SOCKET)
	{
		if (keep_log) writeLog(ERR_NOSOCKET);
		WSACleanup();
		return EXIT_FAILURE;
	}

	//The socket is open. Proceed.
	if (keep_log) writeLog(GOOD_SOCKET);

	SOCKADDR_IN sckaddr;
	sckaddr.sin_family = AF_INET;
	sckaddr.sin_port = htons(server_port);
	memset(&(sckaddr.sin_zero), '\0', sizeof(sckaddr.sin_zero));  //just padding

	string remote_host = server_addr;

	if (!atoi(remote_host.c_str()))	//may need better test for server IP vs name
	{
		HOSTENT* host;
		host = gethostbyname(remote_host.c_str());
		if (host == NULL)
		{
			if (keep_log) writeLog(ERR_NOSERVERNAME);
			WSACleanup();
			return EXIT_FAILURE;
		}
		else
			sckaddr.sin_addr.s_addr = *( (u_long*) host->h_addr_list[0] );
	}
	else	//numeric IP
		//returns INADDR_NONE on error; inet_aton() is new way, but not in Win32
		//At any rate, the old inet_addr() is fine for our purpose here
		sckaddr.sin_addr.s_addr = inet_addr(remote_host.c_str());

	if (sckaddr.sin_addr.s_addr == INADDR_NONE)
	{
		if (keep_log) writeLog(ERR_NOSERVERIP);
		WSACleanup();
		return EXIT_FAILURE;
	}

	//Have remote server IP. Proceed.
	if (keep_log) writeLog(GOOD_IP);

	result = connect(socket1, (PSOCKADDR) &sckaddr, sizeof(sckaddr));

	if (result == SOCKET_ERROR)
	{
		if (keep_log) writeLog(ERR_NOCONNECT);
		WSACleanup();
		return EXIT_FAILURE;
	}

	//Socket is connected. Proceed to send data.
	if (keep_log) writeLog(GOOD_CONNECT);

	do
	{
		result = send(socket1, data_to_send.c_str(), data_to_send.size(), 0);
		if (result == SOCKET_ERROR)
		{
			if (keep_log) writeLog(ERR_NOSEND);
			WSACleanup();
			return EXIT_FAILURE;
		}
		data_to_send.erase(0, result);	//remove the portion that was sent
	}
	while (data_to_send.size());		//do again if there's data left unsent

	//Data sent successfully. Proceed.
	if (keep_log) writeLog(GOOD_SEND);

	//if all sending went well, we should now have data to read, but to be
	//cautious and prevent recv() from possibly blocking while waiting for
	//nothing, we'll use select() before recv()
	//(Note: we may also need to manage blocking on previous functions --
	//		connect(), send(), etc. --
	//		in addition to or instead of here (we'll know better after testing)
	struct timeval timeout;
	timeout.tv_sec = time_out_secs;	//timeout in secs if unavailable data
	timeout.tv_usec = 0;
	fd_set readfds;				//the set of file descriptors to read
	FD_ZERO(&readfds);			//start with none
	FD_SET(socket1, &readfds);	//and just add our friendly socket to it

	select(socket1 + 1, &readfds, NULL, NULL, &timeout);

	if (!FD_ISSET(socket1, &readfds))
	{
		if (keep_log) writeLog(ERR_NORESPOND);
		WSACleanup();
		return EXIT_FAILURE;
	}

	//Server responded. Proceed to read data.
	if (keep_log) writeLog(GOOD_RESPOND);

	char recv_buf[RECV_BUF_SIZE];

	do
	{
		result = recv(socket1, recv_buf, sizeof(recv_buf) - 1, 0);
		if (result == SOCKET_ERROR)
		{
			if (keep_log) writeLog(ERR_NORCVDATA);
 			WSACleanup();
			return EXIT_FAILURE;
		}
		else
		{
			recv_buf[result] = '\0';
			data_received += recv_buf;
		}
	}
	while (result > 0);

	//close socket -- it's a wrap!
	if (keep_log) writeLog(GOOD_RCVDATA);
	closesocket(socket1);
	if (keep_log) writeLog(GOOD_CLOSESCKT);
	WSACleanup();

  #elif defined(__linux__)		//if we are compiling this for Linux

	//use Linux kernel socket calls to establish a TCP/IP communications

	int socket1 = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);

	if (socket1 == -1)
	{
		if (keep_log) writeLog(ERR_NOSOCKET);
		return EXIT_FAILURE;
	}

	//The socket is open. Proceed.
	if (keep_log) writeLog(GOOD_SOCKET);

	struct sockaddr_in sckaddr;
	sckaddr.sin_family = AF_INET;
	sckaddr.sin_port = htons(server_port);
	memset(&(sckaddr.sin_zero), '\0', sizeof(sckaddr.sin_zero));  //just padding

	string remote_host = server_addr;

	if (!atoi(remote_host.c_str()))	//may need better test for server IP vs name
	{
		struct hostent* host;
		host = gethostbyname(remote_host.c_str());
		if (host == NULL)
		{
			if (keep_log) writeLog(ERR_NOSERVERNAME);
			return EXIT_FAILURE;
		}
		else
			sckaddr.sin_addr.s_addr = *( (u_long*) host->h_addr_list[0] );
	}
	else	//numeric IP
		//returns INADDR_NONE on error; inet_aton() is new way, but use the old
		//inet_addr() because it matches Win32 and is fine for our purpose here
		sckaddr.sin_addr.s_addr = inet_addr(remote_host.c_str());

	if (sckaddr.sin_addr.s_addr == INADDR_NONE)
	{
		if (keep_log) writeLog(ERR_NOSERVERIP);
		return EXIT_FAILURE;
	}

	//Have remote server IP. Proceed.
	if (keep_log) writeLog(GOOD_IP);

	int result = connect(socket1, (sockaddr*) &sckaddr, sizeof(sckaddr));

	if (result == -1)
	{
		if (keep_log) writeLog(ERR_NOCONNECT);
		return EXIT_FAILURE;
	}

	//Socket is connected. Proceed to send data.
	if (keep_log) writeLog(GOOD_CONNECT);

	do
	{
		result = send(socket1, data_to_send.c_str(), data_to_send.size(), 0);
		if (result == -1)
		{
			if (keep_log) writeLog(ERR_NOSEND);
			return EXIT_FAILURE;
		}
		data_to_send.erase(0, result);	//remove the portion that was sent
	}
	while (data_to_send.size());		//do again if there's data left unsent

	//Data sent successfully. Proceed.
	if (keep_log) writeLog(GOOD_SEND);

	//if all sending went well, we should now have data to read, but to be
	//cautious and prevent recv() from possibly blocking while waiting for
	//nothing, we'll use select() before recv()
	//(Note: we may also need to manage blocking on previous functions --
	//		connect(), send(), etc. --
	//		in addition to or instead of here (we'll know better after testing)
	struct timeval timeout;
	timeout.tv_sec = time_out_secs;	//timeout in secs if unavailable data
	timeout.tv_usec = 0;
	fd_set readfds;				//the set of file descriptors to read
	FD_ZERO(&readfds);			//start with none
	FD_SET(socket1, &readfds);	//and just add our friendly socket to it

	select(socket1 + 1, &readfds, NULL, NULL, &timeout);

	if (!FD_ISSET(socket1, &readfds))
	{
		if (keep_log) writeLog(ERR_NORESPOND);
		return EXIT_FAILURE;
	}

	//Server responded. Proceed to read data.
	if (keep_log) writeLog(GOOD_RESPOND);

	char recv_buf[RECV_BUF_SIZE];

	do
	{
		result = recv(socket1, recv_buf, sizeof(recv_buf) - 1, 0);
		if (result == -1)
		{
			if (keep_log) writeLog(ERR_NORCVDATA);
			return EXIT_FAILURE;
		}
		else
		{
			recv_buf[result] = '\0';
			stuff_received += recv_buf;
		}
	}
	while (result > 0);

	//close socket -- it's a wrap!
	if (keep_log) writeLog(GOOD_RCVDATA);
	close(socket1);
	if (keep_log) writeLog(GOOD_CLOSESCKT);

  #endif


	return EXIT_SUCCESS;
}
//---------------------------------------------------------------------------

void BaseSocket::writeLog(int status, string message) const
{
	string log_message;

	switch (status)
    {
	  case ERR_NODLL :
		log_message = "Error. Could not find Windows Sockets DLL.\n"
					  "Application requires WS2_32.DLL.";
        break;
	  case GOOD_DLL :
		log_message = "Found required Windows Socket DLL (WS2_32.DLL or newer).\n"
					  "Will now attempt to open a socket...";
        break;
	  case ERR_NOSOCKET :
		log_message = "Error. Was not able to open a socket.";
		break;
	  case GOOD_SOCKET :
		log_message = "Opened a socket successfully.\n"
					  "Will now attempt to resolve server IP address...";
		break;
	  case ERR_NOSERVERNAME :
		log_message = "Error. Was not able to obtain server IP from domain name.";
		break;
	  case ERR_NOSERVERIP :
		log_message = "Error. Ended up with an invalid server IP address.";
		break;
	  case GOOD_IP :
		log_message = "Have a valid server IP.\n"
					  "Will now attempt to connect to server...";
		break;
	  case ERR_NOCONNECT :
		log_message = "Error. Was not able to connect to server through socket.";
		break;
	  case GOOD_CONNECT :
		log_message = "Connect succeeded.\n"
					  "Will now proceed to send data to server...";
		break;
	  case ERR_NOSEND :
		log_message = "Error. Was not able to send the data to the server.";
		break;
	  case GOOD_SEND :
		log_message = "Data sent successfully.\n"
					  "Waiting for server to respond...";
		break;
	  case ERR_NORESPOND :
		log_message = "Error. Timed out waiting for server to respond.";
		break;
	  case GOOD_RESPOND :
		log_message = "Server responded.\n"
					  "Will now read the data that server returned...";
		break;
	  case ERR_NORCVDATA :
		log_message = "Error. Was not able to read buffer containing "
					  "data received from server.";
		break;
	  case GOOD_RCVDATA :
		log_message = "Data was read successfully and is now available to "
					  "calling program.\nClosing socket...";
		break;
	  case GOOD_CLOSESCKT :
		log_message = "Socket closed.\nRoundtrip client-server data "
					  "transmission completed with success!!"
					  "\n\n---------------------------------------------\n\n";
		break;
	  case SHOW_DATA_TO_SEND :
		log_message = message;
		break;
	  default:
		log_message = "Unidentified Error. Unable to Continue.\n";
    }


	struct private_ftime::timeb t1;
	private_ftime::ftime(&t1);
	time_t t2 = t1.time;
	struct tm* pt3;
	pt3 = localtime(&t2);

	ofstream tofile("socket.log", ios::app);
	if (!tofile) return;

	tofile << '\n' << pt3->tm_hour << ':' << pt3->tm_min << ':'
				<< pt3->tm_sec << ':' << t1.millitm << '\n';
	tofile << log_message << endl;
	if (status < SUCCESS_LEVEL)
		tofile << "\nBAILING OUT. UNABLE TO COMPLETE DATA EXCHANGE WITH SERVER."
				"\n\n---------------------------------------------\n\n" << endl;

}
//---------------------------------------------------------------------------

