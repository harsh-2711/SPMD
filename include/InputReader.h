#include <string>
#include <vector>
#include "InputTools.h"

struct Reader {
  std::string folder_name;

  /**
   * @brief Sets the folder name parameter and check the folder exists.
   */
  Reader(const std::string& folder_name);
};

struct GeometryReader : public Reader {
  GeometryReader(const std::string& folder_name) : Reader(folder_name) {}

  /**
   * @brief Reads a geometry file from the specified folder.
   */
  std::vector<char> read_geometry(const std::string& filename) const;
};
