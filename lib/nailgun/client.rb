require_relative 'client/chunk'
require_relative 'client/chunk_header'
require 'socket'
require 'timeout'

module Nailgun
  class Client

    DEFAULTS = {
      hostname:  'localhost',
      port:      2113,
      stdin:     nil,
      stdout:    STDOUT,
      stderr:    STDERR,
      env:       ENV,
      dir:       Dir.pwd
    }.freeze

    CHUNK_HEADER_LEN = 5

    TIMEOUT = 5

    TimeoutError             = Class.new(StandardError)
    SocketFailedError        = Class.new(StandardError)
    ConnectFailedError       = Class.new(StandardError)
    UnexpectedChunktypeError = Class.new(StandardError)
    ServerExceptionError     = Class.new(StandardError)
    ConnectionBrokenError    = Class.new(StandardError)
    BadArgumentsError        = Class.new(StandardError)
    OtherError               = Class.new(StandardError)

    EXIT_CODE_EXCEPTIONS = {
      999 => SocketFailedError,
      998 => ConnectFailedError,
      997 => UnexpectedChunktypeError,
      996 => ServerExceptionError,
      995 => ConnectionBrokenError,
      994 => BadArgumentsError
    }.freeze

    CHUNK_TYPES = {
      stdin:     '0',
      stdout:    '1',
      stderr:    '2',
      stdin_eof: '.',
      arg:       'A',
      env:       'E',
      dir:       'D',
      cmd:       'C',
      exit:      'X'
    }.freeze

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
    # opts = {} - a Hash of options to override the defaults in DEFAULTS
    def initialize(opts = {})
      @opts = DEFAULTS.merge(opts)
      @socket = TCPSocket.new(*@opts.values_at(:hostname, :port))

      if block_given?
        yield self
        @socket.close
        return nil
      end
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

    # Public: Explicitly close the TCPSocket
    def close!
      socket.close
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
      socket.write chunk
    end

    # Private: get the next chunk from the socket, and then determine what to do with it.
    def receive_chunk
      Timeout.timeout(TIMEOUT, TimeoutError) do
        length, type = receive_header
        if length > 0
          content = socket.read(length)
        end

        handle_chunk(type, content)
      end
    end

    # Private: Block while waiting for a header for the next chunk
    #
    # Returns [length, type]
    def receive_header
      socket.read(CHUNK_HEADER_LEN).unpack('NA')
    end

    # Private: Determine what to do with the received chunk
    #
    # type - chunk type
    # content - chunk content
    def handle_chunk(type, content)
      case t = CHUNK_TYPES.key(type)
      when :stdout, :stderr
        opts[t].write content
      when :exit
        socket.close
        handle_exit(content.to_i)
      else
        raise UnexpectedChunktypeError.new([type, content].join(?;))
      end
    end

    def handle_exit(code)
      if code == 0
        throw :exit
      elsif ex = EXIT_CODE_EXCEPTIONS[code]
        raise ex.new
      else
        raise OtherError.new(code.to_s)
      end
    end

  end
end