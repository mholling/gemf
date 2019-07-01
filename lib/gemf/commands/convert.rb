parser = OptionParser.new(<<~EOF) do |parser|
  gemf convert - convert GEMF file to other formats
    usage: gemf convert [options] <input.gemf> <output.mbtiles>
EOF
  parser.separator "  options:"
  parser.on "-o", "--overwrite",                 "overwrite existing output file"
  parser.on "-n", "--name       <name>", String, "name of map"
  parser.on "-h", "--help",                      "show this help" do
    puts parser
    exit
  end
end

options = OpenStruct.new
begin
  parser.parse! into: options
rescue OptionParser::ParseError
  warn parser if $stderr.tty?
  raise
end

input, output, *extras = ARGV.map do |path|
  Pathname(path)
end

case
when extras.any?
  warn parser if $stderr.tty?
  raise "too many arguments: %s" % extras.first
when !output || !input
  warn parser if $stderr.tty?
  raise "no %s file specified" % (input ? "output" : "input")
when output.exist? && !options.overwrite
  raise "file already exists: #{output}"
when !input.file?
  raise "not a file: %s" % input
when input.realpath == output.expand_path
  raise "output can't be the input: #{output}"
end

Dir.mktmpdir do |temp_dir|
  Gemf::Reader.read(input).extend(Gemf::Mbtiles::Writer).write(output, temp_dir, **options.to_h.slice(:name))
end
