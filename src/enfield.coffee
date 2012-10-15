program = require 'commander'
path = require 'path'
fs = require 'fs'
uslug = require 'uslug'
tinyliquid = require 'tinyliquid'
colors = require 'colors'
yaml = require 'js-yaml'
marked = require 'marked'
highlight = require 'highlight'
mkdirp = require 'mkdirp'

config = require './config'

program
  .version('0.0.1')
  .usage('[options]')

program
  .command('build [source] [destination]')
  .description('Build site')
  .option('--server <port>', 'Start a webserver (default 3000)', Number, 3000)
  .option('--base-url <url>', 'Set the base URL (default "/")', String, '/')
  .option('--auto', 'Auto-regenerate')
  .action (source, destination) ->
    unless source and destination
      destination = if source then source else '_site'
      source = '.'

    sourcePath = path.resolve source
    destinationPath = path.resolve destination

    # Make sure source directory exists
    unless fs.existsSync(sourcePath) and fs.lstatSync(sourcePath).isDirectory()
      console.error "Error: Source directory does not exist: #{sourcePath}"
      return -1

    # Load config from source
    configPath = path.join sourcePath, '_config.yml'
    unless fs.existsSync configPath
      console.error "Warning: Could not read configuration. Using defaults"
        .yellow
      console.error "No such file or directory: #{configPath}".yellow
    options = config.getConfig configPath

    # TODO: Merge command-line options

    unless fs.existsSync(options.destination)
      fs.mkdirSync options.destination
    else unless fs.lstatSync(options.destination).isDirectory()
      console.error "Error: Destination is not a directory:
        #{options.destination}".yellow
      return -1

    # Setup markdown
    marked.setOptions
      gfm: true
      sanitize: true
      highlight: (code, lang) ->
        highlight.Highlight code

    # Get all the posts
    postsPath = path.join options.source, '_posts'
    posts = []
    for filename in fs.readdirSync postsPath
      match = filename.match /^(\d{4})-(\d{2})-(\d{2})-(.+)\.md$/
      if match
        post =
          date: new Date match[1], match[2] - 1, match[3]
          slug: match[4]

        { data, content } = getMarkdownContent path.join postsPath, filename
        post.content = content
        post[key] = value for key, value of data
        post.url = "/#{post.date.getFullYear()}/#{post.slug}"
        template = getLayout(post.layout or 'default')

        # Do layout
        if template
          post.rendered = template { post: post }, tinyliquid.filters

          # Output
          outputPath = path.join(options.destination, post.url)
          mkdirp.sync outputPath
          fs.writeFileSync "#{outputPath}/index.html", post.rendered, 'utf-8'
        else
          # Raw HTML
          console.warn "No layout #{post.layout} for #{post.url}".red
          post.rendered = post.content

        posts.push post
      else
        # Filename doesn't match post mask, just copy to output
        sourceFile = fs.createReadStream path.join postsPath, filename
        outPath = path.join options.destination, filename
        # Create directory
        mkdirp path.dirname outPath
        outFile = fs.createWriteStream outPath
        sourceFile.pipe outFile

    # Copy over the other files
    walker = (dir) ->
      for filename in fs.readdirSync(dir)
        continue if filename[0] is '_'

        filepath = path.join dir, filename

        # Recurse on directories
        if fs.statSync(filepath).isDirectory()
          walker filepath
        else
          # Process markdown files
          if /\.md$/.test filename
            { data, content } = getMarkdownContent filepath
            template = getLayout data.layout or 'default'
            if template
              rendered = template { page: data }, tinyliquid.filters
            else
              rendered = content

            outDir = path.join options.destination, path.dirname filepath,
              path.basename filepath

            # Write out
            mkdirp outDir
            fs.writeFileSync path.join(outDir, 'index.html'), rendered, 'utf-8'
          else
            # Straight copy
            sourceFile = fs.createReadStream filepath
            outPath = path.join options.destination, filepath
            mkdirp path.dirname outPath
            outFile = fs.createWriteStream outPath
            sourceFile.pipe outFile

      return

    walker options.source

    return

program
  .command('init [dir]')
  .description('Create directory structure')
  .action (dir='.', options) ->
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
    configpath = path.join rootdir, '_config.yml'
    unless fs.existsSync configpath
      fs.writeFileSync configpath, """source: .
      destination: ./_site
      """
      console.log "Created #{path.join dir, '_config.yml'}"

# Create a new post
# TODO: Support adding custom date?
program
  .command('post [title]')
  .description('Create a new post')
  .action (title) ->
    pad = (num) ->
      unless num > 9
        num = "0" + num
      num

    createPost = (postTitle) ->
      now = new Date()
      year = now.getFullYear()
      month = now.getMonth() + 1
      day = now.getDate()
      slug = uslug postTitle
      postPath = "_posts/#{year}-#{pad(month)}-#{pad(day)}-#{slug}.md"
      createAndEditEntry postTitle, postPath, ->
        console.log "Created post at #{postPath}"

    if title
      createPost title
    else
      program.prompt 'Title: ', (input) ->
        title = input
        createPost title

    return

program
  .command('page [title]')
  .description('Create a new page')
  .action (title) ->
    createPage = (title) ->
      # Create necessary directories
      postPath = uslug title
      createAndEditEntry title, postPath
      return

    if title
      createPage title
    else
      program.prompt 'Title: ', (input) ->
        title = input
        createPage title

    return

module.exports =
  main: (argv) ->
    program.parse argv

    # Check if any command ran. Unfortunately, commander doesn't make this very
    # easy, so we have to look into the results of the argument parsing and
    # check if a command is the last item of the argument array.
    args = program.args
    if args.length is 0 or typeof args[args.length - 1] is 'string'
      # Print usage info
      console.log "No action"
    else
      # Already ran, do nothing

    return

createAndEditEntry = (title, filepath, callback) ->
  # Don't overwrite if already there
  unless fs.existsSync path
    file = fs.writeFileSync filepath, """---
    title: #{title}
    ---
    """

  callback()

  return

# Compile and store all layouts
layoutCache = null
getLayout = (name) ->
  unless layoutCache
    fileContents = {}
    for file in fs.readdirSync "_layouts"
      extension = path.extname file
      name = path.basename file, extension
      fileContents[name] =
        fs.readFileSync(path.join "_layouts", file).toString()

    layoutCache = tinyliquid.compileAll fileContents, original: true

  layoutCache[name]

# Get the frontmatter plus content of a markdown file
getMarkdownContent = (filepath) ->
  lines = fs.readFileSync(filepath).toString().split("\n")
  if lines[0] is "---"
    lines.shift()
    frontMatter = []
    while (currentLine = lines.shift())
      break if currentLine is '---'
      frontMatter.push currentLine
    data = yaml.load frontMatter.join "\n"

  data: data or {}
  content: marked lines.join "\n"
