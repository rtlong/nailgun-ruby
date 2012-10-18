require_relative 'nailgun/version'
require_relative 'nailgun/client'

module Nailgun

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
end
