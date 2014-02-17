fs   = require "fs"
log  = require "./log"
path = require "path"
time = require "time"
Q    = require "q"
yaml = require "js-yaml"

module.exports = exports =
  get: (options) ->
    log.silly "config", "config.get(%j)", options
    deferred = Q.defer()

    # Start with defaults
    config = {}
    config[key] = value for key, value of exports.DEFAULTS

    # Config filepath may come in from command line
    if options.config
      config.config = options.config
    # Otherwise, relative to source directory
    else if options.source
      config.config = path.join options.source, config.config

    log.verbose "config", "Trying to read config from file %s", config.config

    # Read file if it exists, use default if not
    Q.nfcall(fs.readFile, config.config)
      .then (contents) ->
        log.verbose "config", "Loading config from file %s", config.config
        values = yaml.load contents.toString()
        # Use options from config file
        config = mergeConfig config, values
        # ... and command line
        config = mergeConfig config, options

        deferred.resolve resolveOptions config
      .fail (err) ->
        log.verbose "config", "Can't read %s. Using defaults", config.config
        log.silly "config", "File error: %s", err.message

        # Mark config file as not found
        config.config = null

        # No config, use defaults with overrides from command line
        config = mergeConfig config, options

        deferred.resolve resolveOptions config

    deferred.promise

  # Use same defaults as Jekyll, per: http://jekyllrb.com/docs/configuration/
  DEFAULTS:
    source: "./"
    destination: "./_site"
    plugins: "_plugins"
    layouts: "_layouts"
    include: [".htaccess"]
    exclude: []
    keep_files: [".git", ".svn"]
    timezone: null

    future: true
    show_drafts: null
    limit_posts: 0
    pygments: true

    relative_permalinks: true

    permalink: "date"
    paginate_path: "page:num"

    #markdown: "maruku"
    markdown_ext: ["markdown", "mkdown", "mkdn", "mkd", "md"]
    #textile_ext: ["textile"]

    excerpt_separator: "\n\n"

    safe: false
    host: "0.0.0.0"
    port: 4000
    baseurl: "/"
    url: "http://localhost:4000"
    #lsi: false

    # Enfield-specific
    pretty_urls: false
    config: "_config.yml"

# Override options from one object to another
mergeConfig = (config, override) ->
  config[key] = value for key, value of override
  config

# Resolve shortcut values
resolveOptions = (config) ->
  log.silly "config", "resolveOptions(%j)", config

  # Convert permalink style shortcuts to full style
  if config.permalink is "date" or not config.permalink
    config.permalink = "/:categories/:year/:month/:day/:title.html"
  else if config.permalink is "pretty"
    config.permalink = "/:categories/:year/:month/:day/:title/"
  else if config.permalink is "none"
    config.permalink = "/:categories/:title.html"

  # Make sure plugins is an array
  if typeof config.plugins is "string"
    config.plugins = [config.plugins]

  unless config.timezone
    # Use system default
    config.timezone = time.currentTimezone

  # Make source, config, and destination paths relative to current directory
  config.source = path.relative process.cwd(), config.source
  # Config path null if no file
  if config.config
    config.config = path.relative process.cwd(), config.config
  config.destination = path.relative process.cwd(), config.destination

  # Make sure plugins and layout directories are relative to source
  config.layouts = path.resolve config.source, config.layouts
  config.plugins = config.plugins.map (d) -> path.resolve config.source, d

  # Nicer formatting for current directory as source
  config.source or= "./"

  log.silly "config", "Resolved config %j", config
  config

# Export internal functions when testing
if process.env.NODE_ENV is "test"
  exports.mergeConfig = mergeConfig
  exports.resolveOptions = resolveOptions
