#include "InputReader.h"

Reader::Reader(const std::string& folder_name) : folder_name(folder_name) {
  if (!exists_test(folder_name)) {
    error_cout << "Folder " << folder_name << " does not exist." << std::endl;
  }
}

std::vector<char> GeometryReader::read_geometry(const std::string& filename) const {
  std::vector<char> geometry;
  ::read_geometry(folder_name + "/" + filename, geometry);
  return geometry;
}
