require 'pathname'
require 'tmpdir'
require 'open3'
require 'forwardable'
require 'fileutils'
require 'etc'

require_relative 'gemf/concurrently.rb'
require_relative 'gemf/tile.rb'
require_relative 'gemf/tile_range.rb'
require_relative 'gemf/tile_set.rb'
require_relative 'gemf/reader.rb'
require_relative 'gemf/writer.rb'
require_relative 'gemf/mbtiles.rb'

module Gemf
  VERSION, TILE_SIZE = 4, 256
end
