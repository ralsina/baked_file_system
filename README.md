# Baked File System

Include (bake them) static files into a binary at compile time and access them anytime you need.

## About this fork

This is a maintained fork of [schovi/baked_file_system](https://github.com/schovi/baked_file_system).

It exists because of a disagreement about hidden ("dot") paths: upstream rejects
any path with a hidden component, which silently drops **every** file when the
source folder itself lives under a hidden directory — for example
`src/.static/` or `~/.config/myapp/assets`.

Behavior in this fork:

- Baking from a source folder located under a hidden directory works.
- Dotfiles and dot-directory contents **inside** the baked folder are still
  skipped (`.htaccess`, `.well-known/...`), because `Dir.glob` does not match
  hidden entries by default. This matches upstream behavior.

To use this fork instead of upstream, add this to your application's `shard.yml`:

```yaml
dependencies:
  baked_file_system:
    github: ralsina/baked_file_system
```

Releases are tagged on this fork (starting at `v0.11.0`).

## Installation


Add this to your application's `shard.yml`:

```yaml
dependencies:
  baked_file_system:
    github: schovi/baked_file_system
    version: 0.10.0
```

## Usage

A custom type that extends `BakedFileSystem` is used as a file system. The macro `bake_folder` bakes all files in
a given path into the virtual file system. Both relative and absolute paths are supported, as well as baking multiple
folders.

```crystal
require "baked_file_system"

class FileStorage
  extend BakedFileSystem

  bake_folder "/home/my_name/work/crystal_project/public"
  bake_folder "../public"
end

```

Files can be loaded using `get` and `get?` class methods.

```crystal
file = FileStorage.get("path/to/file.png")

file.gets_to_end  # returns content of file
file.path         # returns path of file
file.size         # returns size of original file
```

When try to get missing file, `get` raises a `BakedFileSystem::NoSuchFileError` exception
while `get?` returns `nil`.

```crystal
begin
  FileStorage.get "missing/file"
rescue BakedFileSystem::NoSuchFileError
  puts "File #{path} is missing"
end

FileStorage.get? "missing/file" # => nil
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it ( https://github.com/schovi/baked_file_system/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [schovi](https://github.com/schovi) David Schovanec
- [straight-shoota](https://github.com/straight-shoota) Johannes Müller
