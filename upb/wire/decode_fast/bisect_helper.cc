
#include <iostream>

#include "base/init_google.h"
#include "absl/flags/flag.h"
#include "upb/wire/decode_fast/select.h"

ABSL_FLAG(int, function_idx, -1, "The function index to test.");

int main(int argc, char** argv) {
  InitGoogle(argv[0], &argc, &argv, true);
  if (absl::GetFlag(FLAGS_function_idx) < 0) {
    std::cerr << "Usage: " << argv[0] << " <function_idx>\n";
    return 1;
  }
  std::cout << upb_DecodeFast_GetFunctionName(absl::GetFlag(FLAGS_function_idx))
            << "\n";
  return 0;
}
