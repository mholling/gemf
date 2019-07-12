module Gemf
  class TileRange
    def initialize(tiles:, zoom:, source: "")
      @tiles, @zoom, @source = tiles.reject(&:empty?), zoom, source
    end
    attr_reader :tiles, :zoom, :source

    def limits
      tiles.map(&:indices).transpose.map(&:minmax)
    end

    def indices
      limits.map do |min, max|
        min.upto max
      end.map(&:entries).inject(&:product)
    end

    def size
      limits.map do |min, max|
        min.upto max
      end.map(&:size).inject(&:*)
    end

    def bounds
      (x_min, x_max), (y_min, y_max) = limits
      longitudes = [x_min, x_max + 1].map do |x|
        x * 360.0 / 2**zoom - 180.0
      end
      latitudes = [y_min, y_max + 1].map do |y|
        Math::atan(Math::sinh(Math::PI * (1.0 - 2.0 * y / 2**zoom))) * 180.0 / Math::PI
      end
      [longitudes, latitudes]
    end

    def <=>(other)
      self.bounds <=> other.bounds
    end

    def flatten(temp_dir)
      singles, merges = tiles.group_by(&:indices).partition do |indices, tiles|
        tiles.one?
      end
      merges.map do |indices, tiles|
        path = Pathname(temp_dir).join("tile.%i.%i.%i.png" % [hash, *indices])
        args = tiles.map.with_index do |tile, index|
          tile_path = Pathname(temp_dir).join("tile.%i.%i.%i.%i.png" % [hash, *indices, index])
          tile_path.binwrite tile.data
          tile_path
        end.inject do |args, tile_path|
          [*args, tile_path, "-composite"]
        end.push(path).map(&:to_s)
        next indices, path, args
      end.each.concurrently do |indices, path, args|
        string, status = Open3.capture2e "convert", *args
        raise "couldn't composite tiles" unless status.success?
        string, status = Open3.capture2e *%W[pngquant --force --ext .png --speed 1 --nofs #{path}]
        raise "couldn't optimise tiles" unless status.success?
      rescue Errno::ENOENT => error
        raise error.message
      end.map do |indices, path, args|
        Tile.new indices: indices, path: path, offset: 0, length: path.size
      end.yield_self do |tiles|
        tiles += singles.flat_map(&:last)
        TileRange.new tiles: tiles, zoom: zoom, source: source
      end
    end

    def partition
      Enumerator.new do |yielder|
        remaining = tiles.sort_by(&:indices)
        while remaining.any?
          remaining.chunk_while do |tile1, tile2|
            tile2.x == tile1.x && tile2.y == tile1.y + 1
          end.inject do |partition, strip|
            break partition if strip.first.x > partition.last.x + 1
            y_min, y_max = partition.first.y, partition.last.y
            next partition if strip.first.y > y_min
            next partition if strip.last.y < y_max
            strip.inject(partition) do |partition, tile|
              tile.y < y_min || tile.y > y_max ? partition : partition << tile
            end
          end.tap do |partition|
            remaining -= partition
            yielder << TileRange.new(tiles: partition, zoom: zoom, source: source)
          end
        end
      end.entries
    end

    def summarise(temp_dir)
      tiles.group_by do |tile|
        [tile.x / 2, tile.y / 2]
      end.map do |indices, tiles|
        path = Pathname(temp_dir).join("composite.%i.png" % tiles.hash)
        args = tiles.inject(%w[-size 512x512 canvas:none]) do |args, tile|
          tile_path = Pathname(temp_dir).join("tile.%i.png" % tile.hash)
          tile_path.binwrite tile.data
          geometry = "256x256+%i+%i" % [tile.x % 2 * 256, tile.y % 2 * 256]
          args.push tile_path, "-geometry", geometry, "-composite"
        end.concat(%W[-filter Lanczos -resize 256x256 #{path}]).map(&:to_s)
        next indices, path, args
      end.each.concurrently do |indices, path, args|
        string, status = Open3.capture2e "convert", *args
        raise "couldn't composite tiles" unless status.success?
        string, status = Open3.capture2e *%W[pngquant --force --ext .png --speed 1 --nofs #{path}]
        raise "couldn't optimise tiles" unless status.success?
      rescue Errno::ENOENT => error
        raise error.message
      end.map do |indices, path, args|
        Tile.new indices: indices, path: path, offset: 0, length: path.size
      end.yield_self do |tiles|
        TileRange.new tiles: tiles, zoom: zoom - 1, source: source
      end
    end
  end
end
