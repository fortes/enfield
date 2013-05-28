# Command-line parser / interface
fs = require 'fs-extra'
nopt = require 'nopt'
path = require 'path'
node_static = require 'node-static'
log = require 'npmlog'

conf = require './config'
generate = require './generate'

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
  log: String

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

    if parsed.log
      log.level = parsed.log
      log.verbose "Set log level: #{parsed.log}"


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
            log.error "enfield", "Could not get configuration: #{err.message}"
            process.exit -1

          printConfiguration config

          if command is 'build'
            exports.build config
          else
            exports.serve config
      when 'help'
        exports.help()
      else
        log.error "enfield", "Invalid command. Use --help for more information"
        process.exit -1

  new: (dir) ->
    unless dir
      log.error "enfield", "Must specify a path"
      process.exit -1

    resolved = path.resolve dir

    # Throw error if exists and not empty
    if fs.existsSync(resolved)
      if fs.readdirSync(resolved).length
        log.error "enfield", "Confict: #{resolved} exists and is not empty"
        process.exit -1
      else
        # Remove it so we can bulk copy
        fs.removeSync resolved

    # TODO: Copy site_template over
    fs.copy path.join(__dirname, '../site_template'), resolved, (err) ->
      if err
        log.error "enfield", "Could not create new site: #{err.message}"
      else
        log.info "enfield", "New site installed in #{resolved}"

  build: (config, callback = ->) ->
    generate config, callback

  serve: (config, callback = ->) ->
    # Watching happens within the build command
    exports.build config, (err) ->
      if err
        log.error "enfield", Could not generate site: #{err.message}"
        process.exit -1

      fileServer = new(node_static.Server) config.destination
      server = require('http').createServer (request, response) ->
        log.http "server", "[#{timestamp()}] #{request.method} #{request.url}"
        fileServer.serve request, response

      log.info "enfield", "Running server at http://#{config.host}:#{config.port}"
      server.listen config.port, config.host

  version: ->
    console.log "enfield #{VERSION}"

  help: ->
    console.log """Enfield is a blog-aware static-site generator modeled after Jekyll

  Commands:
    build                Build your site
    doctor               Search site and print specific deprecation warnings
    help                 Display global or [command] help documentation.
    import               Import your old blog to Jekyll
    new                  Creates a new Jekyll site scaffold in PATH
    serve                Serve your site locally

  Global Options:
    -s, --source [DIR]
        Source directory (defaults to ./)

    -d, --destination [DIR]
        Destination directory (defaults to ./_site)

    --safe
        Safe mode (defaults to false)

    --plugins PLUGINS_DIR1[,PLUGINS_DIR2[,...]]
        Plugins directory (defaults to ./_plugins)

    --layouts
        Layouts directory (defaults to ./_layouts)

    -h, --help
        Display help documentation

    -v, --version
        Display version information
"""

  DEFAULT_CONFIGURATION: conf.DEFAULTS

printConfiguration = (config) ->
  console.log "Configuration File: #{config.config or 'none'}"
  console.log "            Source: #{config.source}"
  console.log "       Destination: #{config.destination}"

timestamp = -> (new Date).toLocaleTimeString()
