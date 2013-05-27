# Command-line parser / interface
fs = require 'fs-extra'
nopt = require 'nopt'
path = require 'path'
node_static = require 'node-static'

conf = require './config'

# Copy Jekyll
knownOptions =
  source: path
  destination: path
  config: path
  plugins: [Array, path]
  layouts: path
  safe: Boolean
  watch: Boolean
  drafts: Boolean
  future: Boolean
  limit_posts: Number
  port: Number
  hostname: String
  baseurl: String
  help: Boolean
  version: Boolean

shortHands =
  s: ['--source']
  d: ['--destination']
  w: ['--watch']
  h: ['--help']
  v: ['--version']

VERSION = '0.3.0'

module.exports = exports =
  main: (argv) ->
    parsed = nopt knownOptions, shortHands, argv, 2

    if parsed.version
      return exports.version()
    # No command shows help message
    if parsed.help or parsed.argv.remain.length is 0
      return exports.help()

    command = parsed.argv.remain[0]
    switch command
      when 'new'
        exports.new parsed.argv.remain[1]
      when 'build', 'serve', 'server'
        # Clean options
        options = []
        for name, value of parsed
          continue unless name of knownOptions
          options[name] = value

        conf.get options, (err, config) ->
          if err
            console.error "Could not get configuration: #{err.message}"
            process.exit -1

          printConfiguration config

          if command is 'build'
            exports.build config
          else
            exports.serve config
      when 'help'
        exports.help()
      else
        console.error "Invalid command. Use --help for more information"
        process.exit -1

  new: (dir) ->
    unless dir
      console.error "Must specify a path"
      process.exit -1

    resolved = path.resolve dir

    # Throw error if exists and not empty
    if fs.existsSync(resolved)
      if fs.readdirSync(resolved).length
        console.error "Confict: #{resolved} exists and is not empty"
        process.exit -1
      else
        # Remove it so we can bulk copy
        fs.removeSync resolved

    # TODO: Copy site_template over
    fs.copy path.join(__dirname, '../site_template'), resolved, (err) ->
      if err
        console.error "Could not create new site: #{err.message}"
      else
        console.log "New Enfield site installed in #{resolved}"

  build: (config, callback = ->) ->
    callback()

  serve: (config, callback = ->) ->
    # Watching happens within the build command
    exports.build config, (err) ->
      if err
        console.error "Could not generate site: #{err.message}"
        process.exit -1

      fileServer = new(node_static.Server) config.destination
      server = require('http').createServer (request, response) ->
        console.info "[#{timestamp()}] #{request.method} #{request.url}"
        fileServer.serve request, response

      console.log "Running server at http://#{config.host}:#{config.port}"
      server.listen config.port, config.host

  version: ->
    console.log "enfield #{VERSION}"

  help: ->
    console.log """Enfield is a blog-aware static-site generator modeled after Jekyll """

  DEFAULT_CONFIGURATION: conf.DEFAULTS

printConfiguration = (config) ->
  console.log "Configuration File: #{config.config or 'none'}"
  console.log "            Source: #{config.source}"
  console.log "       Destination: #{config.destination}"

timestamp = -> (new Date).toLocaleTimeString()
