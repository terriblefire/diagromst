
#include <iostream>
#include <fstream>
#include <cstdlib>

int main(int argc, char** argv)
{
  if (argc !=2)
    {
      std::cerr << "Usage: " << argv[0] << " <filename>" << std::endl;      
      exit(1);
    }

  std::cout << "Splitting file " << argv[1] << std::endl;

  std::string evenFile;
  evenFile = argv[1];
  evenFile += ".lo";

  std::string oddFile;
  oddFile = argv[1];
  oddFile += ".hi";

  std::ifstream is(argv[1]);
  std::ofstream evens(evenFile.c_str());
  std::ofstream odds(oddFile.c_str());

  bool even = true;

  char byte;
  while (is)
    {
      is.read(&byte,1);
      if (even)
	{
	  evens.write(&byte,1);
	}
      else
	{
	  odds.write(&byte,1);
	}
      even = !even;
    }

  return 0;
}
