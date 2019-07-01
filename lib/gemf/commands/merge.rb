parser = OptionParser.new(<<~EOF) do |parser|
  gemf merge - merge multiple GEMF map files
    usage: gemf merge [options] <input.gemf> [<input.gemf> ...] <output.gemf>
EOF
  parser.separator "  options:"
  parser.on "-o", "--overwrite", "overwrite existing output file"
  parser.on "-v", "--overlaps",  "don't flatten overlapping tiles"
  parser.on "-h", "--help",      "show this help" do
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

*inputs, output = ARGV.map do |path|
  Pathname(path)
end

case
when !output || inputs.none?
  warn parser if $stderr.tty?
  raise "no input files specified" 
when output.exist? && !options.overwrite
  raise "file already exists: #{output}"
when !inputs.all?(&:file?)
  raise "not a file: %s" % inputs.reject(&:file?).first
when inputs.map(&:realpath).include?(output.expand_path)
  raise "output can't be an input: #{output}"
end

Dir.mktmpdir do |temp_dir|
  inputs.map do |path|
    Gemf::Reader.read path
  end.inject(&:+).yield_self do |tile_set|
    options.overlaps ? tile_set : tile_set.flatten(temp_dir)
  end.extend(Gemf::Writer).write(output, temp_dir)
end
