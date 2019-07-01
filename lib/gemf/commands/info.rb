parser = OptionParser.new(<<~EOF) do |parser|
  gemf info - show information for GEMF files
    usage: gemf info [options] <map.gemf> [<map.gemf> ...]
EOF
  parser.separator "  options:"
  parser.on "-h", "--help",      "show this help" do
    puts parser
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::ParseError
  warn parser if $stderr.tty?
  raise
end

inputs = ARGV.map do |path|
  Pathname(path)
end

case
when inputs.none?
  warn parser if $stderr.tty?
  raise "no input file specified" 
when !inputs.all?(&:file?)
  raise "not a file: %s" % inputs.reject(&:file?).first
end

inputs.each do |input|
  puts ["file: %s" % input, Gemf::Reader.read(input)].join(?\n)
end
