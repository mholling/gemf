module Gemf
  module Mbtiles
    module Reader
      # not presently used
      def self.read(path, temp_dir)
        string, status = Open3.capture2e "sqlite3", path.to_s, %Q[SELECT writefile('#{temp_dir}/mbtiles.' || rowid || '.png', tile_data) FROM tiles]
        raise "couldn't read mbtiles file: %s" % path unless status.success?
        string, status = Open3.capture2e "sqlite3", path.to_s, %Q[SELECT rowid, zoom_level, tile_column, tile_row FROM tiles]
        raise "couldn't read mbtiles file: %s" % path unless status.success?
        string.each_line.map do |line|
          line.split(?|).map(&:to_i)
        end.map do |rowid, zoom, x, y|
          tile_path = temp_dir / "mbtiles.#{rowid}.png", 
          tile = Tile.new(indices: [x, y], path: tile_path, offset: 0, length: tile_path.size)
          TileRange.new tiles: [tile], zoom: zoom
        end.yield_self do |ranges|
          TileSet.new(ranges).flatten(temp_dir)
        end
      end
    end
  end
end
