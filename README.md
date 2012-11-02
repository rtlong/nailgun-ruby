# ng - Pure-Ruby Nailgun client port

Eliminates the need to shell-out to the `ng` binary when using Nailgun, by implementing the Nailgun Protocol in pure Ruby code.

This was an experiment, so don't consider it stable.

I've noticed that Nailgun doesn't like when its IO buffer fills up, and it will if you don't empty it fast enough. Ruby may not be fast enough to handle this job, so if you're trying to send/receive lots of data, this may not work for you. If you're just sending some signals and getting small return values, it may yet.

## Installation

    $ gem install ng

## Usage

```Ruby
# instantiate a new client (optional option overrides may be passed in)
client = Nailgun::Client.new(port: 2114)

# send this command to the server
client.run('java.Command', :arg1, 2) # args are splatted on the instance method

# shouldn't be strictly necessary to close the socket manually, but it's there if you want it
client.close!
```

A class method is also available:

```Ruby
Nailgun::Client.run('java.Command', [:arg1, 2], port: 2114) # args must be explicitly an array here
```

Or, if you prefer, there is a block form available, which automatically closes the socket at completion

```Ruby
Nailgun::Client.new do |client|

  client.run('java.Command', [:arg1, 2])

end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
