parser = OptionParser.new(<<~EOF) do |parser|
  gemf delete - delete tile ranges from GEMF file
    usage: gemf delete [options] <map.gemf>
EOF
  parser.separator "  options:"
  parser.on "-z", "--zoom    <zoom[,...]>",   Zoom,  "specify zoom levels"
  parser.on "-s", "--source  <source[,...]>", Array, "specify tile sources"
  parser.on "-h", "--help",                          "show this help" do
    puts parser
    exit
  end
end

options = Hash[]
begin
  parser.parse! into: options
rescue OptionParser::ParseError
  warn parser if $stderr.tty?
  raise
end

case
when ARGV.none?
  warn parser if $stderr.tty?
  raise "no input file specified"
when ARGV.one?
  path = Pathname(ARGV.shift)
  raise "not a file: %s" % path unless path.file?
else
  warn parser if $stderr.tty?
  raise "too many arguments: %s" % ARGV.drop(1).join(?\s)
end

Dir.mktmpdir do |temp_dir|
  Gemf::Reader.read(path).reject(**options).tap(&method(:puts)).extend(Gemf::Writer).write(path, temp_dir)
end

