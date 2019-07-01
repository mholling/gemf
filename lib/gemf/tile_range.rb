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
  end
end
