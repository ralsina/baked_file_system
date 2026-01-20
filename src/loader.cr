require "./loader/*"

# Check if we should use objcopy mode via command line argument
use_objcopy = ARGV[0]? == "objcopy"

if use_objcopy
  # objcopy mode: ARGV[1] is path, ARGV[2] is optional base dir
  path = ARGV[1]? || ""
  base_dir = ARGV[2]? || Dir.current
  expanded_path = File.expand_path(path, base_dir)
  BakedFileSystem::LoaderObjcopy.load(STDOUT, expanded_path)
else
  # default mode: ARGV[0] is path, ARGV[1] is base dir
  path = ARGV[0]? || ""
  base_dir = ARGV[1]? || Dir.current
  expanded_path = File.expand_path(path, base_dir)
  BakedFileSystem::Loader.load(STDOUT, expanded_path)
end
