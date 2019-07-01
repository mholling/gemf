module Gemf
  module Reader
    def self.read(path)
      path.open("rb") do |file|
        file.define_singleton_method :read! do |bytes|
          read(bytes).tap { |result| raise "bad GEMF file: #{path}" unless result&.bytesize == bytes }
        end
        # 3.1 overall header:
        raise "bad GEMF header" unless file.read!(8).unpack("L>L>") == [VERSION, TILE_SIZE]
        # 3.2 sources:
        sources = file.read!(4).unpack1("L>").times.map do |index|
          raise "bad GEMF source list" unless file.read!(4).unpack1("L>") == index
          file.read!(file.read!(4).unpack1("L>")).unpack1("a*")
        end
        # 3.3 number of ranges:
        file.read!(4).unpack1("L>").times.map do
          # 3.3. range data:
          file.read!(32).unpack("L>L>L>L>L>L>Q>")
        end.map do |zoom, x_min, x_max, y_min, y_max, source_index, offset|
          # 3.4 range details:
          file.seek offset
          tiles = [x_min..x_max, y_min..y_max].map(&:entries).inject(&:product).map do |indices|
            offset, length = file.read!(12).unpack("Q>L>")
            Tile.new indices: indices, path: path, offset: offset, length: length
          end
          TileRange.new tiles: tiles, zoom: zoom, source: sources[source_index]
        end
      end.yield_self do |ranges|
        TileSet.new ranges
      end
    end
  end
end
