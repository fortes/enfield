# Command-line parser / interface
fs          = require "fs-extra"
log         = require "./log"
node_static = require "node-static"
nopt        = require "nopt"
path        = require "path"
Q           = require "q"

conf = require "./config"
generate = require "./generate"

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
  s: "--source"
  d: "--destination"
  w: "--watch"
  h: "--help"
  v: "--version"

VERSION = require('../package.json').version

module.exports = exports =
  main: (argv) ->
    parsed = nopt knownOptions, shortHands, argv, 2

    if parsed.log
      log.setLevel parsed.log
      log.verbose "enfield", "Set log level: %s", parsed.log
      if parsed.log in ["verbose", "silly"]
        log.showTimestamp true
        Q.longStackSupport = true
    else if process.env.NODE_ENV is "test"
      log.setLevel "silent"
      log.verbose "enfield", "Supressing logs while running tests"
      Q.longStackSupport = true
    else
      log.setLevel "info"

    log.silly "enfield", "Parsed options: %j", parsed

    command = parsed.argv.remain[0]
    log.verbose "enfield", "Received command %s", command
    switch command
      when "new"
        exports.new parsed.argv.remain[1]
      when "build", "serve", "server"
        # Clean options
        options = []
        for name, value of parsed
          continue unless name of knownOptions
          options[name] = value

        conf.get(options)
          .then (config) ->
            printConfiguration config
            log.silly "enfield", "Full configuration: %j", config

            if command is "build"
              exports.build(config)
                .fail (err) ->
                  log.error "enfield", "Generation error: #{err.message}"
                  if err.stack
                    log.verbose "enfield", "Stack trace: %s", err.stack
                  process.exit -1
            else
              exports.serve(config)
                .fail (err) ->
                  log.error "enfield", "Couldn't start server: #{err.message}"
                  if err.stack
                    log.verbose "enfield", "Stack trace: %s", err.stack
                  process.exit -1
          .fail (err) ->
            log.error "enfield", "Couldn't load configuration: #{err.message}"
            if err.stack
              log.verbose "enfield", "Stack trace: %s", err.stack
            process.exit -1
      else
        if parsed.version
          exports.version()
        else if command is "help" or parsed.help or not command
          exports.help()
        else
          log.error "enfield", "Invalid command. Use --help for more information"
          if err.stack
            log.verbose "enfield", "Stack trace: %s", err.stack
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
    Q.nfcall(fs.copy, path.join(__dirname, "../site_template"), resolved)
      .then ->
        log.info "enfield", "New site installed in #{resolved}"
      .fail (err) ->
        log.error "enfield", "Couldn't create new site: #{err.message}"
        process.exit -1

  build: (config) ->
    generate(config)
      .then ->
        log.info "enfield", "Generation done"
      .fail (err) ->
        log.error "enfield", "Build failed: %s", err.message
        if err.stack
          log.verbose "enfield", "Stack trace: %s", err.stack
        process.exit -1

  serve: (config) ->
    # Watching happens within the build command
    exports.build(config)
      .then ->
        fileServer = new(node_static.Server) config.destination
        server = require("http").createServer (request, response) ->
          log.http "server", "#{request.method} #{request.url}"
          fileServer.serve request, response

        log.info "enfield", "Running server at http://#{config.host}:#{config.port}"
        server.listen config.port, config.host
      .fail (err) ->
        log.error "enfield", "Couldn't generate site: #{err.message}"
        if err.stack
          log.verbose "enfield", "Stack trace: %s", err.stack
        process.exit -1

  version: ->
    console.log "enfield #{VERSION}"

  help: ->
    console.log """Enfield is a blog-aware static-site generator modeled after Jekyll

  Commands:
    build                Build your site
    help                 Display global or [command] help documentation.
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
  if config.config
    log.info "enfield", "Configuration File: %s", config.config
  else
    log.warn "enfield", "No configuration file"
  log.info "enfield", "Source: %s", config.source
  log.info "enfield", "Destination: %s", config.destination
