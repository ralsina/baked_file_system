require "base64"
require "compress/gzip"
require "./string_encoder"

module BakedFileSystem
  module Loader
    class Error < Exception
    end

    def self.load(io, root_path)
      if !File.exists?(root_path)
        raise Error.new "path does not exist: #{root_path}"
      elsif !File.directory?(root_path)
        raise Error.new "path is not a directory: #{root_path}"
      elsif !File.readable?(root_path)
        raise Error.new "path is not readable: #{root_path}"
      end

      root_path_length = root_path.size

      result = [] of String

      files = Dir.glob(Path[root_path].to_posix.join("**", "*"))
                 # Reject directories
                 .reject { |path| File.directory?(path) }

      files.each do |path|
        io << "bake_file BakedFileSystem::BakedFile.new(\n"
        io << "  path:            " << Path[path[root_path_length..]].to_posix.to_s.dump << ",\n"
        io << "  size:            " << File.info(path).size << ",\n"
        compressed = path.ends_with?("gz")

        io << "  compressed:      " << compressed << ",\n"

        File.open(path, "rb") do |file|
          io << "  slice:         \""

          StringEncoder.open(io) do |encoder|
            if compressed
              IO.copy file, encoder
            else
              Compress::Gzip::Writer.open(encoder) do |writer|
                IO.copy file, writer
              end
            end

            io << "\".to_slice,\n"
          end
        end

        io << ")\n"
        io << "\n"
      end
    end
  end
end

{% if flag?(:objcopy) %}
  require "file_utils"

  module LoaderObjcopy
    class Error < Exception
    end

    def self.load(io, root_path)
      if !File.exists?(root_path)
        raise Error.new "path does not exist: #{root_path}"
      elsif !File.directory?(root_path)
        raise Error.new "path is not a directory: #{root_path}"
      elsif !File.readable?(root_path)
        raise Error.new "path is not readable: #{root_path}"
      end

      root_path_length = root_path.size

      # Create temporary directory for build artifacts
      build_dir = File.join(Dir.current, ".baked")
      FileUtils.mkdir_p(build_dir)

      files = Dir.glob(Path[root_path].to_posix.join("**", "*"))
        # Reject directories
        .reject { |path| File.directory?(path) }

      # Collect file metadata and generate object files
      file_metadata = [] of NamedTuple(path: String, symbol_name: String, size: Int32, compressed: Bool)

      files.each do |file_path|
        relative_path = Path[file_path[root_path_length..]].to_posix.to_s
        symbol_name = path_to_symbol_name(relative_path)
        original_size = File.info(file_path).size
        compressed = file_path.ends_with?("gz")

        # Path for the temporary file (possibly compressed)
        temp_data_path = File.join(build_dir, "#{symbol_name}.data")

        if compressed
          # Already compressed, just copy
          File.copy(file_path, temp_data_path)
        else
          # Compress with gzip
          File.open(temp_data_path, "wb") do |output|
            File.open(file_path, "rb") do |input|
              Compress::Gzip::Writer.open(output) do |gzip|
                IO.copy(input, gzip)
              end
            end
          end
        end

        # Run objcopy to create object file
        obj_path = File.join(build_dir, "#{symbol_name}.o")
        objcopy_success = run_objcopy(temp_data_path, obj_path, symbol_name)

        unless objcopy_success
          raise Error.new "objcopy failed for #{file_path}"
        end

        file_metadata << {
          path:        relative_path,
          symbol_name: symbol_name,
          size:        original_size.to_i32,
          compressed:  compressed,
        }
      end

      # Create static library with ar
      lib_path = File.join(build_dir, "libbaked.a")
      object_files = file_metadata.map { |meta| File.join(build_dir, "#{meta[:symbol_name]}.o") }

      ar_success = run_ar(lib_path, object_files)
      unless ar_success
        raise Error.new "ar failed to create static library"
      end

      # Generate Crystal code
      generate_crystal_code(io, file_metadata, build_dir)
    end

    # Runs ar to create a static library
    private def self.run_ar(lib_path : String, object_files : Array(String)) : Bool
      cmd = "ar rcs #{lib_path} #{object_files.join(' ')}"

      puts "$ #{cmd}" if debug?

      status = Process.run(cmd, shell: true, output: :inherit, error: :inherit)
      status.success?
    end

    # Converts a file path to a valid C symbol name
    private def self.path_to_symbol_name(path : String) : String
      path = path.lstrip('/')
      path.gsub(/[^a-zA-Z0-9]/, '_')
    end

    # Calculates the exact symbol name objcopy creates for a given path
    private def self.objcopy_symbol_name_for_path(input_path : String, suffix : String) : String
      normalized = input_path.gsub(/[\/.]/, '_')
      "_binary_#{normalized}_#{suffix}"
    end

    # Runs objcopy to convert binary to object file
    private def self.run_objcopy(input_path : String, output_path : String, symbol_name : String) : Bool
      obj_format = detect_objcopy_format
      start_addr_sym = objcopy_symbol_name_for_path(input_path, "start")
      end_addr_sym = objcopy_symbol_name_for_path(input_path, "end")

      cmd = ["objcopy",
             "-I", "binary",
             "-O", obj_format,
             "--binary-architecture", detect_architecture,
             "--rename-section", ".data=.rodata,alloc,load,readonly,data,contents",
             "--redefine-sym", "#{start_addr_sym}=baked_#{symbol_name}_start",
             "--redefine-sym", "#{end_addr_sym}=baked_#{symbol_name}_end",
             input_path,
             output_path]

      puts "$ #{cmd.join(' ')}" if debug?

      status = Process.run(cmd[0], args: cmd[1..], output: :inherit, error: :inherit)
      status.success?
    end

    # Detects the objcopy output format for the current platform
    private def self.detect_objcopy_format : String
      {% if flag?(:linux) %}
        {% if flag?(:aarch64) || flag?(:arm) %}
          "elf64-littleaarch64"
        {% elsif flag?(:x86_64) %}
          "elf64-x86-64"
        {% else %}
          "elf64-little"
        {% end %}
      {% elsif flag?(:darwin) %}
        "macho64"
      {% else %}
        `uname -s`.strip == "Darwin" ? "macho64" : "elf64-x86-64"
      {% end %}
    end

    # Detects the architecture for objcopy
    private def self.detect_architecture : String
      {% if flag?(:aarch64) || flag?(:arm) %}
        "aarch64"
      {% elsif flag?(:x86_64) %}
        "i386:x86-64"
      {% else %}
        "i386"
      {% end %}
    end

    private def self.debug? : Bool
      ENV["BAKED_DEBUG"]? == "1"
    end

    # Generates Crystal code with C bindings and BakedFile instances
    private def self.generate_crystal_code(io, file_metadata, build_dir)
      io << "@[Link(ldflags: \"-L#{build_dir} -lbaked\")]\n"
      io << "lib BakedFiles\n"

      file_metadata.each do |meta|
        symbol_name = "baked_#{meta[:symbol_name]}"
        io << "  $#{symbol_name}_start : UInt8\n"
        io << "  $#{symbol_name}_end : UInt8\n"
      end

      io << "end\n\n"

      # Generate bake_file calls
      file_metadata.each do |meta|
        symbol_name = "baked_#{meta[:symbol_name]}"
        io << "bake_file BakedFileSystem::BakedFile.new(\n"
        io << "  path:            " << meta[:path].dump << ",\n"
        io << "  size:            " << meta[:size] << ",\n"
        io << "  compressed:      " << meta[:compressed] << ",\n"
        io << "  start_ptr:       pointerof(BakedFiles.#{symbol_name}_start).as(UInt8*),\n"
        io << "  end_ptr:         pointerof(BakedFiles.#{symbol_name}_end).as(UInt8*),\n"
        io << ")\n\n"
      end
    end
  end
{% end %}
