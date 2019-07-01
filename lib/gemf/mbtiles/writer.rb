module Gemf
  module Mbtiles
    module Writer
      def write(path, temp_dir, name: path.basename(path.extname).to_s)
        name = name.to_s.gsub /[^\w -.]+/, ""
        minzoom, maxzoom = ranges.map(&:zoom).minmax
        bounds = self.bounds.transpose.flatten.join(?,)
        center = [*centre, minzoom].join(?,)

        sql = StringIO.new
        sql.puts <<~SQL % [name, bounds, center, minzoom, maxzoom]
          CREATE TABLE metadata (name TEXT, value TEXT);
          INSERT INTO metadata VALUES ("name", "%s");
          INSERT INTO metadata VALUES ("format", "png");
          INSERT INTO metadata VALUES ("bounds", "%s");
          INSERT INTO metadata VALUES ("center", "%s");
          INSERT INTO metadata VALUES ("minzoom", "%s");
          INSERT INTO metadata VALUES ("maxzoom", "%s");
          CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB);
        SQL

        ranges.each.with_index do |range, range_index|
          range.tiles.each.with_index do |tile, tile_index|
            tile_path = Pathname(temp_dir) / "tile.#{range_index}.#{tile_index}.png"
            tile_path.binwrite tile.data
            values = [range.zoom, tile.x, tile.y ^ (2**range.zoom - 1), tile_path]
            sql.puts %Q[INSERT INTO tiles VALUES (%i, %i, %i, readfile("%s"));] % values
          end
        end

        db_path = Pathname(temp_dir) / "mbtiles.db"
        sql_path = Pathname(temp_dir) / "script.sql"
        sql_path.write sql.string
        string, status = Open3.capture2e "sqlite3", db_path.to_s, %Q[.read "#{sql_path}"]
        raise "couldn't create mbtiles file" unless status.success?
        FileUtils.mv db_path, path
      end
    end
  end
end
