fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

# Use same defaults as Jekyll, per: http://jekyllrb.com/docs/configuration/
DEFAULTS =
  source: '.'
  destination: './_site'
  plugins: '_plugins'
  layout: '_layouts'
  include: ['.htaccess']
  exclude: []
  keep_files: ['.git', '.svn']
  timezone: null

  future: true
  show_drafts: null
  limit_posts: 0
  pygments: true

  relative_permalinks: true

  permalink: 'date'
  paginate_path: 'page:num'

  #markdown: 'maruku'
  markdown_ext: ['markdown', 'mkd', 'mkdn', 'md']
  #textile_ext: ['textile']

  excerpt_separator: '\n\n'

  safe: false
  host: '0.0.0.0'
  port: 4000
  baseurl: '/'
  url: 'http://localhost:4000'
  #lsi: false

  # Enfield-specific
  pretty_urls: false
  config: '_config.yml'

module.exports = exports =
  get: (options, callback) ->
    # Start with defaults
    config = {}
    config[key] = value for key, value of DEFAULTS

    # May come in from command line
    if options.config
      config.config = options.config
    # Otherwise, relative to source directory
    else if options.source
      config.config = path.join options.source, config.config

    # Read file if it exists
    fs.exists config.config, (exists) ->
      if exists
        str = fs.readFile config.config, (err, contents) ->
          if err then return callback err

          values = yaml.load contents.toString()
          # Use options from config file
          config[key] = value for key, value of values
          # ... and command line
          config[key] = value for key, value of options

          callback null, config
      else
        # No config, use defaults with overrides from command line
        config[key] = value for key, value of options
        # Mark config file as not found
        config.config = null
        callback null, config
