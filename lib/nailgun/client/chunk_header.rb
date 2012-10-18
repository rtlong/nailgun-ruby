module Nailgun
  class Client
    class ChunkHeader
      def initialize(type, content_length)
        @type = Nailgun::CHUNK_TYPES[type]
        @content_length = content_length
      end

      def to_a
        [@content_length, @type]
      end

      def to_s
        to_a.pack('NA')
      end
    end
  end
end
