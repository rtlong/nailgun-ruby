require_relative 'client/chunk'
require_relative 'client/chunk_header'
require 'socket'
require 'io/wait'
require 'logger'
require 'timeout'

module Nailgun
  class Client
    LOGGER = Logger.new('log')

    attr_reader :opts, :socket

    # Public: Convinience method to instantiate and run the command
    #
    # command - see #run
    # args - see #run
    # opts = {} -  see #initialize
    #
    # Returns the duplicated String.
    def self.run(command, args, opts = {})
      self.new(opts).run(command, args)
    end

    # Public: Initialize a Client.
    #
    # opts = {} - a Hash of options to override the defaults in Nailgun::DEFAULTS
    def initialize(opts = {})
      @opts = Nailgun::DEFAULTS.merge(opts)
      @socket = TCPSocket.new(*@opts.values_at(:hostname, :port))
      debug "Opened new #{@socket.inspect}"
    end

    # Public: Run a command on the Client instance
    #
    # command - the command string
    # *args - any arguments to send
    def run(command, *args)
      receive_loop # start the loop

      send_args     args.flatten
      send_env      opts[:env]
      send_dir      opts[:dir]
      send_command  command
      send_stdin    opts[:stdin]

      receive_loop.join
      return nil
    end

    # Public: Start the receiver loop Thread, memoize it, and return the Thread
    #
    # Returns the Thread object, whose value will eventually be the exit status from the Nailgun
    # server
    def receive_loop
      @loop ||= Thread.new {
        catch(:exit) do
          loop { receive_chunk }
        end
      }
    end

    private

    # Private: Send the argument chunks
    #
    # *args - an Array of the arguments to send
    def send_args(*args)
      args.flatten.each do |arg|
        send_chunk :arg, arg
      end
    end

    # Private: Send the environment vars.
    #
    # env - a Hash in the format of Ruby's ENV constant
    def send_env(env)
      env.each do |var|
        send_chunk :env, var.join(?=)
      end
    end

    # Private: Send the working directory
    #
    # dir - the working directory
    def send_dir(dir)
      send_chunk :dir, dir.to_s
    end

    # Private: Send the command to be run
    #
    # command - the Nail command (usually a Java class name)
    def send_command(command)
      send_chunk :cmd, command
    end

    # Private: Send the STDIN stream for the Nail to read from.
    #
    # io = nil - an IO of the stdin stream to send.
    def send_stdin(io = nil)
      unless io.nil?
        begin
          send_chunk :stdin, io.read(2048)
        end until io.eof?
        io.close
      end
      send_chunk :stdin_eof
    end

    # Private: Send a chunk. Used by the higher-level methods
    #
    # type - the chunk type
    # content = nil - the actual content
    def send_chunk(type, content = nil)
      chunk = Chunk.new(type, content).to_s
      debug "Sending #{type} chunk: #{content.inspect}"
      socket.write chunk
    end

    # Private: get the next chunk from the socket, and then determine what to do with it.
    def receive_chunk
      Timeout.timeout(Nailgun::TIMEOUT, Nailgun::TimeoutError) do
        length, type = receive_header
        if length == 0
          debug "Received #{type} chunk with no content"
        else
          debug "About to read #{type} chunk (#{length} B). Content follows (until <<<< END CHUNK >>>>) "

          content = socket.read(length)

          LOGGER << (content + "<<<< END CHUNK >>>>\n")
        end

        handle_chunk(type, content)
      end
    end

    # Private: Block while waiting for a header for the next chunk
    #
    # Returns [length, type]
    def receive_header
      socket.read(Nailgun::CHUNK_HEADER_LEN).unpack('NA')
    end

    # Private: Determine what to do with the received chunk
    #
    # type - chunk type
    # content - chunk content
    def handle_chunk(type, content)
      case t = Nailgun::CHUNK_TYPES.key(type)
      when :stdout, :stderr
        opts[t].write content
      when :exit
        socket.close
        handle_exit(content.to_i)
      else
        raise Nailgun::UnexpectedChunktypeError.new([type, content].join(?;))
      end
    end

    def handle_exit(code)
      if code == 0
        throw :exit
      elsif ex = Nailgun::EXIT_CODE_EXCEPTIONS[code]
        raise ex.new
      else
        raise Nailgun::OtherError.new(code.to_s)
      end
    end

    # Private: Debug log message
    def debug(message)
      LOGGER.debug(message)
    end

    # Extend the return value with a success? method akin to Process::Status, which I can't figure
    # out how to instantiate manually
    class ExitStatus
      def initialize(value)
        @val = value
      end
      def success?
        @val == 0
      end
      def method_missing(*args)
        @val.send(*args)
      end
      def inspect
        @val.inspect
      end
    end

  end
end