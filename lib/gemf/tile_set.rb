module Gemf
  class TileSet
    def initialize(ranges)
      @ranges = ranges
    end
    attr_reader :ranges

    def +(other)
      TileSet.new ranges + other.ranges
    end

    def bounds
      ranges.group_by(&:zoom).map do |zoom, ranges|
        ranges.map(&:bounds).transpose.map(&:flatten).map(&:minmax)
      end.transpose.map(&:transpose).map do |minimums, maximums|
        [minimums.max, maximums.min]
      end
    end

    def centre
      bounds.map do |bound|
        0.5 * bound.inject(&:+)
      end
    end

    def flatten(temp_dir)
      ranges.group_by do |range|
        [range.zoom, range.source]
      end.map.with_index do |((zoom, source), ranges), index|
        tiles = ranges.map(&:tiles).inject(&:+).group_by(&:indices).map do |indices, (*below, above)|
          next above if below.none?
          string, status = Open3.capture2e *%W[identify -format %A -], stdin_data: above.data, binmode: true
          next above if status.success? && string[0].upcase == ?F
          path = Pathname(temp_dir).join("tile.%i.%i.%i.png" % [index, *indices])
          paths = [*below, above].map.with_index do |tile, subindex|
            tile_path = Pathname(temp_dir).join("tile.%i.%i.%i.%i.png" % [index, *indices, subindex])
            tile_path.binwrite tile.data
            tile_path
          end.inject do |args, tile_path|
            [*args, tile_path, "-composite"]
          end.push(path).map(&:to_s).tap do |args|
            string, status = Open3.capture2e "convert", *args
            raise "couldn't composite tiles" unless status.success?
            string, status = Open3.capture2e *%W[pngquant --force --ext .png --speed 1 --nofs #{path}]
            raise "couldn't optimise tiles" unless status.success?
          rescue Errno::ENOENT => error
            raise error.message
          end
          Tile.new indices: indices, path: path, offset: 0, length: path.size
        end
        TileRange.new tiles: tiles, zoom: zoom, source: source
      end.flat_map(&:partition).yield_self do |ranges|
        TileSet.new ranges
      end
    end

    def to_s
      longitudes, latitudes = bounds.zip(%w[E N], %w[W S]).map do |bound, positive_cardinal, negative_cardinal|
        bound.map do |value|
          "%.3f%s" % [value.abs, value < 0 ? negative_cardinal : positive_cardinal]
        end
      end

      group_by = lambda do |collection, category, &block|
        collection.group_by(&category).sort.reverse_each.inject [[], "└─ ", "   "] do |(lines, branch, spacer), (category, collection)|
          parent, children = block.call category, collection
          children.reverse_each do |child|
            lines << [spacer, child].join
          end if children
          lines << [branch, parent].join
          [lines, "├─ ", "│  "]
        end.first.reverse
      end

      lines = []
      lines << "longitude: %s" % longitudes.join(?-)
      lines << "latitude: %s" % latitudes.join(?-)
      lines << "tiles:"
      lines += group_by.call(ranges, :source) do |source, ranges|
        next "source: %s" % source, group_by.call(ranges, :zoom) do |zoom, ranges|
          next "zoom level: %i" % zoom, group_by.call(ranges, :itself) do |range|
            sizes = range.limits.map { |min, max| (min..max).size }
            plural = ?s unless range.tiles.one?
            kilobytes = range.tiles.sum(&:length) / 1024.0
            storage = case kilobytes
            when 0...1000 then "%.1fKB" % kilobytes
            when 0...1000000 then "%.1fMB" % (kilobytes / 1024)
            else "%.1fGB" % (kilobytes / 1024 / 1024)
            end
            next "%i×%i range: %i tile%s, %s" % [*sizes, range.tiles.length, plural, storage]
          end
        end
      end
      lines.join(?\n)
    end
  end
end
