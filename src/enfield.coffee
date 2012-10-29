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

config = require './config'

CONFIG_FILENAME = '_config.yml'

module.exports =
  version: '0.0.1'
  main: (argv) ->
    optimist = require('optimist')
      .usage("""Enfield is a static-site generator modeled after Jekyll

Usage:
  $0                          # Generate . -> ./_site
  $0 [destination]            # Generate . -> <path>
  $0 [source] [destination]   # Generate <path> -> <path>

  $0 init [directory]         # Build default directory structure
  $0 page [title]             # Create a new post with today's date
  $0 post [title]             # Create a new page
""")
      .describe('auto', 'Auto-regenerate')
      .describe('server [PORT]', 'Start a web server (default port 4000)')
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
        options = config.getConfig(path.join source, CONFIG_FILENAME)
        # Override config with passed variables
        if destination
          options.destination = destination
        if args.server
          options.server = true
        if args.server and args.server isnt true
          options.server_port = args.server
        # Server activates auto
        if args.auto or options.server
          options.auto = true
        # TODO: args.url

        begin options

# Workhorse function
begin = (options) ->
  # Copy default filters
  options.filters = {}
  options.filters[key] = tinyliquid.filters[key] for key of tinyliquid.filters

  options.converters = []

  # Load bundled plugins
  loadPlugins options, path.join __dirname, 'plugins'
  checkDirectories options
  # Load directory plugins
  loadPlugins options

  # Sort converters based on priority
  options.converters.sort (a, b) ->
    b.priority - a.priority

  generate options

  if options.auto
    console.log "Auto-regenerating enabled".green +
      " #{options.source} -> #{options.destination}".green
    # Avoid infinite refreshing from watching the output directory
    fileFilter = (f) ->
      f isnt options.destination
    watch.watchTree options.source, { filter: fileFilter }, (f, curr, prev) ->
      if typeof f is 'object' and curr is null and prev is null
        # Finished walking tree, ignore
      else if prev is null
        # New file
        generateDebounced options, ->
          console.log 'Updated due to new file'
      else if curr.nlink is 0
        # Removed file
        generateDebounced options, ->
          console.log 'Updated due to removed file'
      else
        # File was changed
        generateDebounced options, ->
          console.log 'Updated due to changed file'

    # TODO: Run server
    if options.server
      fileServer = new(node_static.Server)(options.destination)
      server = http.createServer (request, response) ->
        request.addListener 'end', ->
          fileServer.serve request, response
      server.listen options.server_port
      console.log "Running server at http://localhost:#{options.server_port}"

lastGenerated = 0
generateTimeoutId = 0
wait = (timeout, f) ->
  setTimeout f, timeout
generateDebounced = (options, callback) ->
  now = Date.now()
  clearTimeout generateTimeoutId
  generateTimeoutId = wait 100, ->
    generate options, ->
      lastGenerated = Date.now()
      callback()
  return

generate = (options, callback) ->
  { layouts, includes } = getLayoutsAndIncludes options

  console.log "Building site: #{options.source} -> #{options.destination}"

  posts = getPosts options
  # Sort on date
  posts.sort (a, b) ->
    b.date - a.date
  # Create data
  siteData = {}
  # Add in variables from config
  siteData[key] = options[key] for key of options
  # Post collection
  siteData.posts = posts
  siteData.time = Date.now()
  for type in ['tags', 'categories']
    siteData[type] = {}
    for post in posts
      if post[type]
        for val in post[type]
          siteData[type][val] or= { name: val, posts: [] }
          siteData[type][val].posts.push post

    for key, val of siteData[type]
      val.posts.sort (a,b) ->
        b.date - a.date

  liquidOptions =
    files: includes
    original: true

  # Write out posts
  for post in posts
    # Respect published flag
    continue unless post.published

    # Template
    content = tinyliquid.compile(post.raw_content, liquidOptions) {
      site: siteData
      page: post
    }, options.filters

    # Run conversion
    { ext, content } = convertContent post.ext, content, options.converters
    post.content = content

    if post.layout
      template = layouts[post.layout]
      rendered = template {
        content: post.content
        page: post
        site: siteData
      }, options.filters
    else
      rendered = post.content

    if ext is '.html'
      outputPath = path.join options.destination, post.url, 'index.html'
    else
      post.url += ext
      outputPath = path.join options.destination, post.url

    fs.mkdirsSync path.dirname outputPath
    fs.writeFileSync outputPath, rendered

  # Walk through other directories in the root
  files = [options.source]
  isHidden = (filepath) ->
    basename = path.basename filepath
    filepath isnt options.source and
      (basename[0] is '_' or basename[0] is '.')

  while filepath = files.pop()
    # Folder
    if fs.statSync(filepath).isDirectory()
      # Skip special folders
      continue if isHidden filepath

      # Create directory in destination
      fs.mkdirsSync path.join options.destination, filepath

      for filename in fs.readdirSync filepath
        # Skip hidden files
        childPath = path.join filepath, filename
        continue if isHidden childPath
        files.push childPath
    else
      { data, content, ext } = getDataAndContent filepath

      if data
        # Process
        page = {}
        page[key] = data[key] for key of data

        basename = path.basename filepath, ext
        if basename is 'index' and (ext is '.md' or ext is '.html')
          basename = ''
        page.url = "/#{path.join path.dirname(filepath), basename}"

        # Content can contain liquid directives
        content = tinyliquid.compile(content, liquidOptions) {
          site: siteData
          page: page
        }, options.filters

        # Run conversion
        { ext, content } = convertContent ext, content, options.converters
        page.content = content

        if page.layout and page.layout of layouts
          template = layouts[page.layout]
          rendered = template {
            content: content
            site: siteData
            page: data
          }, options.filters
        else
          rendered = content

        if ext is '.html'
          outputPath = path.join options.destination, page.url, 'index.html'
        else
          page.url += ext
          outputPath = path.join options.destination, page.url

        fs.mkdirsSync path.dirname outputPath
        fs.writeFileSync outputPath, rendered
      else
        # Straight copy
        fs.copy filepath, path.join options.destination, filepath

  console.log "Successfully generated site: ".green +
    "#{path.resolve options.source} -> #{options.destination}".green
  callback() if callback

# Make sure the directories needed are there
checkDirectories = (options) ->
  unless fs.existsSync options.source
    console.error "Source directory does not exist: #{options.source}".red
    process.exit -1

  if fs.existsSync options.destination
    unless fs.lstatSync(options.destination).isDirectory()
      console.error "Destination is not a directory: #{options.destination}".red
      process.exit -1
  else
    fs.mkdirSync options.destination

# Load plugins
loadPlugins = (options, pluginDir) ->
  unless pluginDir
    pluginDir = path.resolve path.join options.source, '_plugins'

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
        options.filters[key] = plugin.filters[key] for key of plugin.filters
      if plugin.converters
        for key of plugin.converters
          options.converters.push(plugin.converters[key])

  return

# Compile all layouts and return
getLayoutsAndIncludes = (options) ->
  layoutDir = path.join options.source, options.layout
  includesDir = path.join options.source, '_includes'

  includes = {}
  if fs.existsSync includesDir
    for file in fs.readdirSync includesDir
      if fs.statSync(file).isDirectory()
        # TODO: Wat?
      else
        includes[file] = fs.readFileSync file

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

# Get all posts
postMask = /^(\d{4})-(\d{2})-(\d{2})-(.+)\.(md|html)$/
getPosts = (options) ->
  posts = []
  postDir = path.join options.source, '_posts'
  for filename in fs.readdirSync postDir
    if match = filename.match postMask
      { data, content, ext } = getDataAndContent path.join postDir, filename

      post = {}
      post[key] = data[key] for key of data

      post.date = new Date match[1], match[2] - 1, match[3]
      post.slug = match[4]
      post.published = if 'published' of data then data.published else true
      post.id = post.url = "/#{post.date.getFullYear()}/#{post.slug}"
      post.raw_content = content
      post.ext = ext
      if post.tags and typeof post.tags is 'string'
        post.tags = post.tags.split ' '
      if post.categories and typeof post.categories is 'string'
        post.categories = post.categories.split ' '

      posts.push post
    else
      # Doesn't match post mask, ignore

  posts

# Get the frontmatter plus content of a file
getDataAndContent = (filepath) ->
  lines = fs.readFileSync(filepath).toString().split("\n")
  if lines[0] is "---"
    lines.shift()
    frontMatter = []
    while (currentLine = lines.shift())
      break if currentLine is '---'
      frontMatter.push currentLine
    data = yaml.load frontMatter.join "\n"

  data: data
  content: lines.join "\n"
  ext: path.extname filepath

convertContent = (ext, content, converters) ->
  for converter in converters
    if converter.matches ext
      return {
        ext: converter.outputExtension ext
        content: converter.convert content
      }

  # None found, leave unmodified
  return { ext, content }

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
