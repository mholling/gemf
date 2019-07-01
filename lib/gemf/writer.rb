module Gemf
  module Writer
    def write(path, temp_dir)
      # 3.1 overall header:
      header = [4, 256,].pack("L>L>")
      # 3.2 sources:
      sources = ranges.map(&:source).uniq.each.with_index.to_h
      header << [sources.length].pack("L>")
      sources.each do |source, index|
        header << [index, source.bytesize, source].pack("L>L>a#{source.bytesize}")
      end
      # 3.3 number of ranges:
      header << [ranges.length].pack("L>")
      offset = header.bytesize + ranges.length * 32

      tiles = ranges.each do |range|
        header << [range.zoom, *range.limits.flatten, sources[range.source], offset].pack("L>L>L>L>L>L>Q>")
        offset += range.size * 12
      end.flat_map do |range|
        lookup = range.tiles.group_by(&:indices).transform_values(&:first)
        range.indices.map do |indices|
          lookup[indices]
        end
      end.each do |tile|
        # 3.4 range details:
        if tile
          header << [offset, tile.length].pack("Q>L>")
          offset += tile.length
        else
          header << [offset, 0].pack("Q>L>")
        end
      end.compact

      temp_path = Pathname(temp_dir) / "output.gemf"
      temp_path.open("wb") do |file|
        file.write header
        # 4 data area:
        tiles.each do |tile|
          file.write tile.data
        end
      end
      FileUtils.mv temp_path, path
    end
  end
end
