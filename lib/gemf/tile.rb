module Gemf
  class Tile
    def initialize(indices:, path:, offset:, length:)
      @indices, @path, @offset, @length = indices, path, offset, length
    end
    attr_reader :indices, :path, :offset, :length

    extend Forwardable
    def_delegator :@length, :zero?, :empty?

    def data
      path.binread length, offset
    end

    def x
      indices[0]
    end

    def y
      indices[1]
    end
  end
end
