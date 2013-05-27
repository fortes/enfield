yaml = require 'js-yaml'
fs = require 'fs'

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

module.exports.getConfig = (configPath) ->
  # Read in config file
  config = {}
  config[key] = value for key, value of DEFAULTS
  if configPath and fs.existsSync configPath
    console.log "Configuration from #{configPath}"
    str = fs.readFileSync(configPath).toString()
    config[key] = value for key, value of yaml.load str

  config
