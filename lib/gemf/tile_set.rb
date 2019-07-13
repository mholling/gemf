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
      end.map do |(zoom, source), ranges|
        TileRange.new tiles: ranges.flat_map(&:tiles), zoom: zoom, source: source
      end.map do |range|
        range.flatten(temp_dir)
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

    %i[select reject].each do |method|
      define_method method do |zoom: ranges.map(&:zoom), source: ranges.map(&:source)|
        ranges.send(method) do |range|
          zoom.include?(range.zoom) &&
          source.include?(range.source)
        end.yield_self do |filtered|
          # TODO: raise error if no tiles left? (do it in writer, maybe?)
          TileSet.new filtered
        end
      end
    end

    def fill(temp_dir, source: ranges.map(&:source))
      modify = source
      ranges.group_by(&:source).flat_map do |source, ranges|
        next ranges unless modify.include? source
        ranges.group_by(&:zoom).map do |zoom, ranges|
          TileRange.new tiles: ranges.flat_map(&:tiles), zoom: zoom, source: source
        end.sort_by(&:zoom).chunk_while do |range1, range2|
          range1.zoom + 1 == range2.zoom
        end.inject([]) do |memo, ranges|
          memo << [memo.any? ? memo.last.last.last.zoom + 1 : 0, ranges]
        end.flat_map do |min_zoom, ranges|
          (min_zoom...ranges[0].zoom).reverse_each.inject(ranges) do |ranges, zoom|
            break ranges if ranges[0].tiles.one?
            ranges.unshift ranges[0].summarise(temp_dir)
          end
        end.flat_map(&:partition)
      end.yield_self do |filled|
        raise "no tiles to be added" if filled.length == ranges.length
        TileSet.new filled
      end
    end
  end
end
