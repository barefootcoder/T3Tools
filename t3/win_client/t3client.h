#ifndef __t3client_h__
#define __t3client_h__

#include <iostream>
#include <string>
using namespace std;

// some app specific functions
string T3IniFilename ();
string T3HisFilename ();
string T3Pathname ();

string T3Caption () { return "T3Client"; };

#endif
