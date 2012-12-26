optimist = require 'optimist'
path = require 'path'
fs = require 'fs-extra'
uslug = require 'uslug'
tinyliquid = require 'tinyliquid'
colors = require 'colors'
yaml = require 'js-yaml'
node_static = require 'node-static'
watch = require 'watch'
http = require 'http'
async = require 'async'

configReader = require './config'

CONFIG_FILENAME = '_config.yml'

module.exports =
  version: '0.2.1'
  main: (argv) ->
    optimist = require('optimist')
      .usage("""Enfield is a static-site generator modeled after Jekyll

Usage:
  enfield                          # Generate . -> ./_site
  enfield [destination]            # Generate . -> <path>
  enfield [source] [destination]   # Generate <path> -> <path>

  enfield init [directory]         # Build default directory structure
  enfield page [title]             # Create a new post with today's date
  enfield post [title]             # Create a new page
""")
      .describe('auto', 'Auto-regenerate')
      .describe('server [PORT]', 'Start a web server (default port 4000)')
      .describe('base-url [URL]', 'Serve website from a give base URL')
      .describe('url [URL]', 'Set custom site.url')

    args = optimist.parse(argv)

    if args.help
      console.log optimist.help()
      return
    else if args.version
      console.log module.exports.version
      return

    # Depending on setup, sometimes `coffee enfield.coffee` appears in the
    # remainder arguments. Strip them out if they are present
    remainderArgs = Array::slice.call args._, 0
    if remainderArgs[0] is 'coffee'
      # Remove irrelvant arguments
      remainderArgs.shift() # coffee
      remainderArgs.shift() # enfield.coffee

    # Check for commands
    source = '.'
    switch remainderArgs[0]
      when 'init'
        dir = remainderArgs[1] or '.'
        createDirectoryStructure dir
        return
      when 'page'
        title = remainderArgs[1]
        if title
          createPage title
        else
          console.error "Must include title".red
        return
      when 'post'
        title = remainderArgs[1]
        if title
          createPost title
        else
          console.error "Must include title".red
        return
      else # Default is to generate
        # One argument specifies just the destination
        if remainderArgs.length is 1
          destination = remainderArgs[0]
        # Two arguments means source and destination
        else if remainderArgs.length is 2
          source = remainderArgs[0]
          destination = remainderArgs[1]

        # Load configuration
        config = configReader.getConfig(path.join source, CONFIG_FILENAME)
        # Override config with passed variables
        if destination
          config.destination = destination
        if args.server
          config.server = true
        if args.server and args.server isnt true
          config.server_port = args.server
        # Server activates auto
        if args.auto or config.server
          config.auto = true
        # URLs
        if args['base-url']
          config.baseurl = args['base-url']
        if args.url
          config.url = args.url

        begin config

# Workhorse function
begin = (config) ->
  # Copy default filters
  config.filters = {}
  config.filters[key] = tinyliquid.filters[key] for key of tinyliquid.filters

  config.converters = []
  config.generators = []

  # Load bundled plugins
  loadPlugins config, path.join __dirname, 'plugins'
  checkDirectories config
  # Load directory plugins
  loadPlugins config

  # Sort converters based on priority
  config.converters.sort (a, b) ->
    b.priority - a.priority

  generate config, (err) ->
    if err
      console.error err
      process.exit -1

    console.log "Successfully generated site: ".green +
      "#{path.resolve config.source} -> #{config.destination}".green

    if config.auto
      console.log "Auto-regenerating enabled".green +
        " #{config.source} -> #{config.destination}".green
      # Avoid infinite refreshing from watching the output directory
      realDestination = path.resolve config.destination
      fileFilter = (f) ->
        path.resolve(f) is realDestination
      watch.watchTree config.source, { filter: fileFilter }, (f, curr, prev) ->
        if typeof f is 'object' and curr is null and prev is null
          # Finished walking tree, ignore
          return
        else if prev is null
          # New file
          generateDebounced config, ->
            console.log 'Updated due to new file'
        else if curr.nlink is 0
          # Removed file
          generateDebounced config, ->
            console.log 'Updated due to removed file'
        else
          # File was changed
          generateDebounced config, ->
            console.log 'Updated due to changed file'

      if config.server
        fileServer = new(node_static.Server)(config.destination)
        server = http.createServer (request, response) ->
          request.addListener 'end', ->
            fileServer.serve request, response
        server.listen config.server_port
        console.log "Running server at http://localhost:#{config.server_port}"

lastGenerated = 0
generateTimeoutId = 0
wait = (timeout, f) ->
  setTimeout f, timeout
generateDebounced = (config, callback) ->
  now = Date.now()
  clearTimeout generateTimeoutId
  generateTimeoutId = wait 100, ->
    generate config, ->
      lastGenerated = Date.now()
      callback()
  return

generate = (config, callback) ->
  { layouts, includes } = getLayoutsAndIncludes config

  console.log "Building site: #{config.source} -> #{config.destination}"

  posts = getPosts config
  {pages, static_files} = getPagesAndStaticFiles config

  # Create site data structure
  site =
    time: Date.now()
    baseurl: config.baseurl
    url: config.url
    config: config
    posts: posts
    pages: pages
    static_files: static_files

  # Setup tags & categories for posts
  for type in ['tags', 'categories']
    site[type] = {}
    for post in posts
      continue unless config.future or post.published
      if post[type]
        for val in post[type]
          site[type][val] or= { name: val, posts: [] }
          site[type][val].posts.push post

  liquidOptions =
    files: includes
    original: true

  # Run generators
  async.forEachSeries(
    config.generators,
    (generator, cb) -> generator site, cb
    (err) ->
      if err then return callback err
      # Write content to disk
      async.series(
        [
          (cb) -> writePostsAndPages site, layouts, liquidOptions, cb
          (cb) -> writeStaticFiles site, cb
        ]
        callback
      )
  )

writePage = (page, site, layouts, liquidOptions, callback) ->
  # Respect published flag
  return callback() unless site.config.future or page.published

  # Content can contain liquid directives, process now
  content = tinyliquid.compile(page.raw_content, liquidOptions)(
    { site, page }
    site.config.filters
  )

  # Run conversion
  convertContent page.ext, content, site.config.converters, (err, res) ->
    if err then return callback err

    page.content = res.content
    {ext} = res

    # Apply layout, if it exists
    if page.layout and page.layout of layouts
      template = layouts[page.layout]
      rendered = template {
        content: page.content
        site: site
        page: page
      }, site.config.filters
    else
      rendered = page.content

    if ext is '.html'
      outputPath = path.join site.config.destination, page.url, 'index.html'
    else
      page.url += ext
      outputPath = path.join site.config.destination, page.url

    # Write file
    fs.mkdirsSync path.dirname outputPath
    fs.writeFile outputPath, rendered, callback

    return
  return

writePostsAndPages = (site, layouts, liquidOptions, callback) ->
  # Write out pages and posts in parallel
  async.forEachLimit(
    site.posts.concat(site.pages)
    5
    (page, cb) -> writePage page, site, layouts, liquidOptions, cb
    callback
  )
  return

writeStaticFiles = (site, callback) ->
  # Copy static files without overwhelming the file system
  async.forEachLimit(
    site.static_files
    5
    (filepath, cb) ->
      # Make sure directory exists before copying
      outPath = path.join site.config.destination, filepath
      fs.mkdirsSync path.dirname(outPath)
      fs.copy filepath, outPath, cb
    callback
  )
  return

# Make sure the directories needed are there
checkDirectories = (config) ->
  unless fs.existsSync config.source
    console.error "Source directory does not exist: #{config.source}".red
    process.exit -1

  if fs.existsSync config.destination
    unless fs.lstatSync(config.destination).isDirectory()
      console.error "Destination is not a directory: #{config.destination}".red
      process.exit -1
  else
    fs.mkdirSync config.destination

# Load plugins
loadPlugins = (config, pluginDir) ->
  unless pluginDir
    pluginDir = path.resolve path.join config.source, '_plugins'

  return unless fs.existsSync pluginDir

  for file in fs.readdirSync pluginDir
    filepath = path.join pluginDir, file
    if fs.statSync(filepath).isDirectory()
      # Ignore directories for now
      continue

    ext = path.extname file
    if ext is '.js' or ext is '.coffee'
      # Load file
      plugin = require filepath
      if plugin.filters
        for key, filter of plugin.filters
          config.filters[key] = filter
      if plugin.converters
        for key, converter of plugin.converters
          config.converters.push converter
      if plugin.generators
        for key, generator of plugin.generators
          config.generators.push generator

  return

# Compile all layouts and return
getLayoutsAndIncludes = (config) ->
  layoutDir = path.join config.source, config.layout
  includesDir = path.join config.source, '_includes'

  includes = {}
  if fs.existsSync includesDir
    for file in fs.readdirSync includesDir
      filepath = path.join includesDir, file
      if fs.statSync(filepath).isDirectory()
        # TODO: Wat?
      else
        includes[file] = fs.readFileSync(filepath).toString()

  fileData = {}
  fileContents = {}
  for file in fs.readdirSync layoutDir
    name = path.basename file, path.extname file
    { data, content } = getDataAndContent path.join(layoutDir, file)
    fileData[name] = data
    fileContents[name] = content

  liquidOptions =
    files: includes
    original: true

  # Helper for moving up dependency chain of layouts
  layoutContents = {}
  load = (name, content) ->
    unless name of layoutContents
      if layout = fileData[name]?.layout
        layout = load layout, fileContents[layout]
        content = layout.replace /\{\{\s*content\s*\}\}/, content

      layoutContents[name] = content

    layoutContents[name]

  layouts = {}
  for name, content of fileContents
    layouts[name] = tinyliquid.compile load(name, content), liquidOptions

  { layouts, includes }

# Find all directories named _posts for inclusion
getPostDirectories = (config) ->
  dirs = []
  toCheck = [config.source]

  while dirpath = toCheck.pop()
    if fs.statSync(dirpath).isDirectory()
      for filename in fs.readdirSync dirpath
        childPath = path.join dirpath, filename
        unless fs.statSync(childPath).isDirectory()
          continue
        if filename is '_posts'
          dirs.push childPath
        else unless isHidden childPath, config
          toCheck.push childPath

  dirs

# Get all posts
postMask = /^(\d{4})-(\d{2})-(\d{2})-(.+)\.(md|markdown|html)$/
getPosts = (config) ->
  postDirs = getPostDirectories(config)
  posts = []
  permalinks = {}
  for postDir in postDirs
    for filename in fs.readdirSync postDir
      # Doesn't match post mask, ignore
      unless match = filename.match postMask
        continue

      {data, content, ext} = getDataAndContent path.join postDir, filename

      post = { raw_content: content, ext }
      post[key] = data[key] for key of data

      post.date = new Date match[1], match[2] - 1, match[3]
      post.slug = match[4]
      post.published = if 'published' of data then data.published else true
      post.id = post.url = "/#{post.date.getFullYear()}/#{post.slug}"
      if post.url of permalinks
        console.error "Repeated permalink #{post.url}".red
      permalinks[post.url] = true
      post.ext = ext
      if post.tags and typeof post.tags is 'string'
        post.tags = post.tags.split ' '
      # Alias
      if post.category and not post.categories
        post.categories = post.category
      if post.categories and typeof post.categories is 'string'
        post.categories = post.categories.split ' '
      # Add categories from directory
      dirCats = postDir.split('/').filter((t) -> t isnt '_posts')
      if dirCats.length
        post.categories = if post.categories
          post.categories.concat dirCats
        else
          dirCats

      posts.push post

  # Sort on date
  posts.sort (a, b) ->
    b.date - a.date

  # Set next / prev on posts
  prev = null
  for post in posts
    # List is in reverse-chronological order, so the previous post in the loop
    # is actually the next post
    if prev
      post.next = prev
      prev.prev = post
    prev = post

  # Ruby arrays have .first and .last, which some liquid templates depend on
  posts.first = posts[0]
  posts.last = posts[posts.length - 1]

  posts

getPagesAndStaticFiles = (config) ->
  pages = []
  static_files = []

  # Walk through all directories looking for files
  files = [config.source]
  while filepath = files.pop()
    # Folder?
    if fs.statSync(filepath).isDirectory()
      # Skip special folders
      continue if isHidden filepath, config

      for filename in fs.readdirSync filepath
        # Skip hidden files
        childPath = path.join filepath, filename
        continue if isHidden childPath, config
        files.push childPath
    else
      {data, content, ext} = getDataAndContent filepath

      if data
        page = { raw_content: content, ext }
        page[key] = data[key] for key of data
        page.published = if 'published' of data then data.published else true

        basename = path.basename filepath, ext
        if basename is 'index' and (ext is '.md' or ext is '.html')
          basename = ''
        page.url = "/#{path.join path.dirname(filepath), basename}"
        # Special case
        if page.url is '/.'
          page.url = '/'

        # Add to collection
        pages.push page
      else
        static_files.push filepath

  { pages, static_files }

# Get the frontmatter plus content of a file
getDataAndContent = (filepath) ->
  lines = fs.readFileSync(filepath).toString().split(/\r\n|\n|\r/)
  if /^---\s?$/.test lines[0]
    lines.shift()
    frontMatter = []

    while (lines.length)
      currentLine = lines.shift()
      break if /^---\s?$/.test currentLine
      frontMatter.push currentLine

    data = yaml.load frontMatter.join "\n"

  data: data
  content: lines.join "\n"
  ext: path.extname filepath

convertContent = (ext, content, converters, callback) ->
  for converter in converters
    if converter.matches ext
      converter.convert content, (err, converted) ->
        callback null, {
          ext: converter.outputExtension ext
          content: converted
        }
      return

  # None found, leave unmodified
  callback null, { ext, content }
  return

# Whether the file should be ignored by the system
isHidden = (filepath, config) ->
  basename = path.basename filepath
  if basename in config.exclude
    true
  else if basename in config.include
    false
  else
    filepath isnt config.source and
      (basename[0] is '_' or basename[0] is '.')

# Creates all the default directories
createDirectoryStructure = (dir) ->
  rootdir = path.resolve dir

  console.log "Creating directory structure within #{rootdir}"

  unless fs.existsSync rootdir
    fs.mkdirSync rootdir

  # Create directories
  for name in "_includes _layouts _posts _site css js".split(' ')
    dirpath = path.join rootdir, name
    continue if fs.existsSync dirpath
    fs.mkdirSync dirpath
    console.log "Created #{path.join dir, name}"

  # Create config file with a few default values
  configpath = path.join rootdir, CONFIG_FILENAME
  unless fs.existsSync configpath
    fs.writeFileSync configpath, """source: .
    destination: ./_site
    """
    console.log "Created #{path.join dir, CONFIG_FILENAME}"

createPage = (title) ->
  # Create necessary directories
  slug = "#{uslug title}.md"
  createEntry title, slug
  console.log "Created page at #{slug}".green
  return

pad = (num) ->
  unless num > 9
    num = "0" + num
  num

createPost = (postTitle) ->
  now = new Date()
  year = now.getFullYear()
  month = pad now.getMonth() + 1
  day = pad now.getDate()
  # TODO: Check if slug exists for given year already and add -2?
  slug = uslug postTitle
  postPath = "_posts/#{year}-#{month}-#{day}-#{slug}.md"
  createEntry postTitle, postPath
  console.log "Created post at #{postPath}".green
  return

createEntry = (title, filepath) ->
  # Don't overwrite if already there
  unless fs.existsSync path
    file = fs.writeFileSync filepath, """---
    title: #{title}
    ---
    """

  return
