# nz_covid_pass

Reads NZ COVID Pass passes, validates them, and lets you look at the data inside.

## Usage

`gem install nz_covid_pass` or add `nz_covid_pass` to your Gemfile.

```ruby
  code = 'NZCP:/1/ABCDEFGH...'

  covid_pass = NZCovidPass.new(code)
  puts covid_pass.given_name
  puts covid_pass.family_name # note: can be nil
  puts covid_pass.dob
```

If there's a problem with the pass, you'll get an exception raised:

```ruby
  NZCovidPass.new(code)
  # => NZCovidPass::ParseError if the code is malformed
  # => COSE::Error if the signature is invalid
  # => NZCovidPass::ExpiredError if the pass is expired
  # => NZCovidPass::NotYetValidError if the pass is not yet valid
  # => NZCovidPass::NetworkError if the public key couldn't be retrieved
```

If you want to try out the test COVID Passes, you'll need to enable the test option:

```ruby
  covid_pass = NZCovidPass.new(test_code, allow_test_issuers: true)
```

This gem requires network access to fetch the public key for validation.  If
you don't have network access, or you're going to be validating lots of passes,
you can pass in a cache hash:

```ruby
  # if you're online, it'll populate this hash the first time you run a code
  cache = {}

  # if you're not online, you'll need to preload the cache
  cache = {"nzcp.identity.health.nz" => {"object data" => "goes here"}}

  covid_pass = NZCovidPass.new(test_code, cache: cache)
```

## Implementation

Taken from the [NZ COVID Pass Technical Specification v1](https://nzcp.covid19.health.nz/).

## Copyright

Copyright 2021 Roger Nesbitt, MIT licensed.
