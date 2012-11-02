require 'bundler/setup'

Bundler.require

COMMAND = 'org.apache.tika.cli.TikaCLI'
ARGS = ['-t', '/tmp/big.pdf']

Nailgun::Client.run(COMMAND, ARGS)
