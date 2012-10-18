module Nailgun
  class Client
    class Chunk
      attr_reader :content, :type

      def initialize(type, content)
        @content = content.to_s
        @type = type
      end

      def header
        ChunkHeader.new(type, length)
      end

      def length
        content.length
      end

      def to_s
        header.to_s + content
      end

    end
  end
end
