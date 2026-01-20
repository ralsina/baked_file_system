require "./loader/*"

{% if flag?(:objcopy) %}
  path = ARGV[0]
  BakedFileSystem::LoaderObjcopy.load(STDOUT, path)
{% else %}
  path = File.expand_path(ARGV[0], ARGV[1])
  BakedFileSystem::Loader.load(STDOUT, path)
{% end %}
