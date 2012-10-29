yaml = require 'js-yaml'
fs = require 'fs'

DEFAULTS =
  safe: false
  auto: false
  server: false
  server_port: 4000

  source: '.'
  destination: './_site'
  plugins: '_plugins'
  layout: '_layouts'

  future: true
  #lsi: false
  #pygments: false
  #markdown: 'maruku'
  #permalink: ':year/:title'
  include: ['.htaccess']
  exclude: ['README.md']
  #paginate_path: 'page:num'

  # markdown_ext: 'markdown,mkd,mkdn,md'
  # textile_ext: 'textile'

  # maruku options
  # rdiscount options
  # redcarpet options
  # kramdown options
  # redcloth options

module.exports.getConfig = (configPath) ->
  # Read in config file
  config = {}
  config[key] = value for key, value of DEFAULTS
  if configPath and fs.existsSync configPath
    console.log "Configuration from #{configPath}"
    str = fs.readFileSync(configPath).toString()
    config[key] = value for key, value of yaml.load str

  config
