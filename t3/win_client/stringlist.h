//---------------------------------------------------------------------------
#ifndef StringListH
#define StringListH

#include <string>
#include <vector>
#include <fstream>
using namespace std;

// define a namespace
namespace arinbe 
{
	typedef struct KeyType
	{
		string  key_name;
		string  key_value;

	} KeyType;

	class StringList
	{
	public:

		StringList ();
		StringList (const StringList& sl);
		~StringList ();

		string String (int index) const;
		string Name (int index) const;
		string Value (int index) const;
		string Value (const string& name) const;

		StringList GetNames () const;
		StringList GetValues () const;

		void SetString (int index, const string& str);
		void SetName (int index, const string& name);
		void SetValue (int index, const string& value);
		void SetValue (const string& name, const string& value);

		// returns all strings as one large string separated by linefeeds
		string Text () const;
		void Text (const string& str); //, const string& delim = "\r\n");

		// returns all strings as one large string separated by commas
		string  CommaText () const;
		void    CommaText (const string& str);

		int IndexOf (const string& str) const;
		int IndexOfName (const string& name) const;

		int Count() const { return(int) m_list.size(); };

		// adds a string to the list
		int Add (const string& str);

		// Merge a string list
		void Merge (StringList& str_list) const;

		// removes all strings
		void Clear ();

		// delete a string from the list
		void Delete (int index);
		void Delete (const string& str);

		// file functions
		int ReadFromFile (const string& filename);

		int WriteToFile (const string& filename) const;
		int WriteToFile (ofstream& file) const;

	protected:

		// trims both ends of a string
		void TrimString (string& str) const;

		// splits and adds a string to the list
		void SplitAndAdd(const string& split_str, const string& data);

		// returns the list joined by join_str
		string Join (const string& join_str) const;

	private:

		vector<string>   m_list;


		// returns a string split into name=value pair
		KeyType MakeKeyType (const string& str) const;

	};

}; // end namespace arinbe 
#endif
