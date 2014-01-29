async      = require "async"
fs         = require "fs-extra"
gaze       = require "gaze"
glob       = require "glob"
log        = require "./log"
path       = require "path"
time       = require("time")(Date) # Extend global object
tinyliquid = require "tinyliquid"
toposort   = require "toposort"
util       = require "util"
Q          = require "q"

helpers    = require "./helpers"

# Built-in plugins
bundledPlugins = null
# Regexp for matching post filenames
postMask = null
# Global reference for custom tags
currentState = null

INCLUDE_PATH = "_includes"

module.exports = exports = (config) ->
  log.info "generate", "Begin generation"
  # First-run initialization
  postMask = ///^(\d{4})-(\d{2})-(\d{2})-(.+)\.(#{config.markdown_ext.join "|"}|html)$///
  time.tzset config.timezone
  Q.all([checkDirectories(config), loadBundledPlugins()])
    .then ->
      log.verbose "generate", "Initialization complete"
      refreshContent config
    .then ->
      log.info "generate", "Generated %s -> %s", config.source, config.destination
      if config.watch
        watch config
      return

watch = (config) ->
  destinationPath = path.resolve config.destination
  Q.nfcall(gaze, path.join(config.source, "**/*"), {debounceDelay: 500})
    .then (watcher) ->
      log.info "watch", "Watching %s for changes", config.source
      watcher.on "all", (event, filepath) ->
        # Ignore any path within the destination directory
        return if helpers.isWithinDirectory filepath, destinationPath

        # Ignore any path within hidden/ignored directories

        # TODO: Special case _config.yml
        # TODO: Reload plugins

        log.info "watch", "%s %s", event, filepath
        refreshContent(config).then -> log.info "watch", "Regenerated"

refreshContent = (config) ->
  log.silly "generate", "Refreshing content"

  # Mimic Jekyll behavior by clearing out destination before regeneration
  Q.nfcall(fs.remove, config.destination)
    .then ->
      log.verbose "generate", "Cleared contents from %s", config.destination
    .then ->
      # Get content in parallel:
      Q.all([
        loadSitePlugins config
        loadIncludes config
        loadLayouts config
        loadContents config
      ])
    .then ([plugins, includes, layouts, { posts, pages, files }]) ->
      log.verbose "generate", "Plugin, include, layout, and content load complete"
      processResults {config, plugins, includes, layouts, posts, pages, files}

processResults = ({config, plugins, includes, layouts, posts, pages, files}) ->
  # Create site data structure
  site = {
    time: Date.now()
    config
    posts
    pages
    static_files: files
    tags: {}
    categories: {}
  }

  # Setup current state
  currentState = {
    site
    page: null
    liquidOptions: null
  }

  # Add all values from config, but make sure not to clobber any existing
  for key, value of config
    unless key of site
      site[key] = value

  # Collect tags & categories for posts
  for type in ["tags", "categories"]
    for post in posts
      continue unless (config.future or post.published) and post[type]?.length
      for value in post[type]
        site[type][value] or= { name: value, posts: [] }
        site[type][value].posts.push post

  # Prepare plugins
  mergedPlugins = mergePlugins bundledPlugins, plugins

  liquidOptions = currentState.liquidOptions =
    customTags: mergedPlugins.tags

  # Create base context for tinyliquid
  context = tinyliquid.newContext {
    locals: {
      site
    }
    filters: mergedPlugins.filters
  }

  # Handle {% include %} tags
  context.onInclude (name, cb) ->
    log.silly "generate", "Fetching include for %s", name
    ast = tinyliquid.parse includes[name], liquidOptions
    cb null, ast

  bundle = {
    site
    config
    liquidOptions
    compiledLayouts: null
    mergedPlugins
    context
  }

  convertIncludes(includes, mergedPlugins.converters)
    .then ->
      # Compile layouts
      compiledLayouts = {}
      for name, {data, content} of layouts
        try
          compiledLayouts[name] = tinyliquid.compile content, liquidOptions
        catch err
          throw new Error "Error while compiling layout: #{err.message}"

      bundle.compiledLayouts = compiledLayouts

      log.verbose "generate", "Reading complete. Running generators"

      # Run generators across site
      Q.all(
        mergedPlugins.generators.map (generator) -> Q.nfcall generator, site
      )
    .then ->
      log.verbose "generate", "Generators complete, preparing to write posts"
      # Filter out any files blanked by generators
      site.static_files = site.static_files.filter (f) -> !!f

      # Now write all content to disk
      writePages site.posts, bundle
    .then ->
      log.verbose "generate", "Posts written, writing pages"
      writePages site.pages, bundle
    .then ->
      log.verbose "generate", "Pages written, copying files"
      writeFiles bundle
    .fail (err) ->
      log.error "generate", err.message

writePages = (pages, bundle) ->
  log.verbose "generate", "writePages: %s pages to write", pages.length
  # TODO: Limit concurrency here
  Q.all pages.map (page) -> writePage page, bundle

writePage = (page, bundle) ->
  log.silly "generate", "writePage(%s)", util.inspect page
  { site, config, liquidOptions, compiledLayouts, mergedPlugins, context } = bundle

  currentState.page = page
  outpath = ""

  # Ignore unpublished files
  if config.future or page.published
    ext = path.extname page.path

    # Run conversion
    convertContent(ext, page.content, mergedPlugins.converters, config)
      .then (result) ->
        processConvertedPage(result, page, config)
      .then (outputPath) ->
        outpath = outputPath
        # Content may contain liquid directives (such as a post listing)
        # Process now before layout
        renderLiquidPostContent(page, context, liquidOptions)
      .then (content) ->
        log.silly "generate", "Rendered page content for %s: %s", page.url, content
        page.content = content
        renderPostLayout(page, compiledLayouts, context)
      .then (contents) ->
        # Write file
        log.verbose "generate", "Writing page: %s", outpath
        Q.nfcall(fs.outputFile, outpath, contents)
  else
    # Nothing to do
    deferred = Q.defer()
    deferred.resolve()
    deferred

processConvertedPage = (result, page, config) ->
  log.verbose "generate", "Processing %s (%s)", page.title, page.url

  ext = path.extname page.path
  page.content = result.content
  newExt = result.ext

  # Pretty URLs don't get extensions
  if config.pretty_urls and newExt is ".html"
    page.url = helpers.stripExtension page.url
  else if newExt isnt ext
    # Update page url with new extension
    page.url = (helpers.stripExtension page.url) + newExt

  # Strip out index.html
  if path.basename(page.url, ".html") is "index"
    page.url = path.dirname page.url

  # Set up correct path / URL
  outpath = path.join config.destination, page.url
  unless path.extname page.url
    if newExt is ".html"
      outpath = path.join config.destination, page.url, "index.html"

  outpath

renderLiquidPostContent = (page, context, liquidOptions) ->
  context.setLocals "page", page
  context.setLocals "paginator", page.paginator or {}

  render = tinyliquid.compile page.content, liquidOptions
  Q.nfcall(render, context)
    .then(
      -> return context.clearBuffer().toString()
      (err) ->
        log.warn "generate", "Tinyliquid compile error: %s", err.message
        throw new Error "Liquid error from #{page.url}: #{err.message}"
    )

renderPostLayout = (page, compiledLayouts, context) ->
  # If there's no layout, then we just return the content
  unless page.layout and page.layout of compiledLayouts
    log.verbose "generate", "No layout for: %s", page.path
    return page.content

  log.verbose "generate", "Applying layout %s to %s", page.layout, page.url
  template = compiledLayouts[page.layout]
  context.setLocals "content", page.content
  Q.nfcall(template, context)
    .then(
      -> context.clearBuffer().toString()
      (err) ->
        log.warn "generate", "Tinyliquid template error: %s", err.message
        throw new Error "Liquid error from #{page.url}: #{err.message}"
    )

writeFiles = (bundle) ->
  log.verbose "generate", "Writing static files: %j", bundle.site.static_files
  { site } = bundle
  # TODO: Limit concurrency
  Q.all site.static_files.map (filepath) -> writeFile filepath, bundle

writeFile = (filepath, bundle) ->
  { config } = bundle
  relpath = helpers.stripDirectoryPrefix filepath, config.source
  outpath = path.join config.destination, relpath
  log.verbose "generate", "Copying %s -> %s", filepath, outpath
  Q.nfcall(fs.mkdirs, path.dirname outpath)
    .then ->
      Q.nfcall fs.copy, filepath, outpath

convertContent = (ext, content, converters, config) ->
  log.silly "generate", "convertContent(%s, %s, ...)", ext, content
  for converter in converters
    if converter.matches ext
      return Q.nfcall(converter.convert, content, config)
        .then (converted) ->
          log.silly "generate", "Converted Content: %s", converted
          return {
            ext: converter.outputExtension ext
            content: converted
          }

  # No converter found, leave content unmodified
  log.silly "generate", "convertContent: No converter found for extension %s",
    ext
  deferred = Q.defer()
  deferred.resolve { ext, content }
  deferred.promise

mergePlugins = (a, b) ->
  log.silly "generate", "mergePlugins(%j, %j)", a, b
  merged =
    filters: {}
    tags: {}
    converters: []
    generators: []

  for set in [a, b]
    merged.converters = merged.converters.concat set.converters
    merged.generators = merged.generators.concat set.generators
    for name, filter of set.filters
      merged.filters[name] = filter
    for name, fn of set.tags
      # Wrap custom tags in a simpler API
      log.silly "generate", "Creating wrapper for custom tag %s", name
      do (name, fn) ->
        merged.tags[name] = (context, name, body) ->
          # Call the plugin function using a much simpler API
          # Need to set page and site variables before running liquid conversion
          result = fn body, currentState.page, currentState.site

          # Use tinyliquid helper method to output HTML
          context.astStack.push tinyliquid.parse result, currentState.liquidOptions

  # Converters are sorted by priority
  merged.converters.sort (a, b) -> b.priority - a.priority

  merged

loadIncludes = (config) ->
  includeDir = path.join config.source, INCLUDE_PATH

  log.verbose "generate", "Looking for includes in %s", includeDir
  includes = {}

  getRawIncludes(config)
    .then (files) ->
      log.verbose "generate", "Found includes: %j", Object.keys(files)

      normalized = {}
      # Normalize all paths, stripping out file extension
      for file, {data, content} of files
        normalized[helpers.stripDirectoryPrefix file, includeDir] = content

      log.verbose "generate", "Normalized includes: %j", Object.keys(normalized)
      normalized

convertIncludes = (includes, converters, config) ->
  Q.all Object.keys(includes).map (includeName) ->
    convertInclude includeName, includes, converters, config

convertInclude = (name, includes, converters, config) ->
  log.silly "generate", "Converting include %s", name
  convertContent(path.extname(name), includes[name], converters, config)
    .then (result) ->
      log.silly "generate", "Converted include %s", name
      includes[name] = result.content

loadLayouts = (config) ->
  log.verbose "generate", "Looking for layouts in %s", config.layouts
  layouts = {}

  getRawLayouts(config)
    .then (files) ->
      log.silly "generate", "Found layouts %j in %s",
        Object.keys(files), config.layouts
      normalized = {}
      # Normalize all paths, stripping out file extension
      for file, {data, content} of files
        normalized[normalizeLayoutName file, config.layouts] = { data, content }
        if data?.layout
          data.layout = normalizeLayoutName data.layout, config.layouts

      # Now calculate dependency graph
      dependencyGraph = []
      for file, { data, content } of normalized
        # Skip files that don't have layout, and just use content as-is
        unless data and data.layout
          layouts[file] = { data, content }
          continue

        fullPath = path.resolve file, data.layout
        if data.layout of normalized
          dependencyGraph.push [file, data.layout]
        else
          log.warn "generate", "Can't find parent layout %s for layout %s", data.layout, file

      # Make sure to resolve files in order
      try
        sorted = toposort(dependencyGraph).reverse()
      catch err
        throw new Error "Cyclic dependency within layouts"

      # Now apply layout to the layout. Can't use liquid for this since we are
      # just substituting {{ content }} in the layout
      for file in sorted
        # Skip if already done
        continue if file of layouts

        { data, content } = normalized[file]
        parent = layouts[data.layout]
        # Run replacement
        if parent
          content = parent.content.replace /\{\{\s*content\s*\}\}/, content

        layouts[file] = {data, content}

      log.verbose "generate", "Load layouts complete"
      layouts

getRawIncludes = (config) ->
  deferred = Q.defer()

  includes = path.join config.source, INCLUDE_PATH
  Q.nfcall(fs.stat, includes)
    .then (stat) ->
      log.verbose "generate", "Loading includes from %s", includes
      deferred.resolve helpers.mapFiles(
        path.join(includes, "**/*")
        helpers.getMetadataAndContent
      )
    .fail (err) ->
      log.verbose "generate", "Couldn't load includes from: %s (%s)", includes,
        err.message
      deferred.resolve {}

  deferred.promise

getRawLayouts = (config) ->
  deferred = Q.defer()

  Q.nfcall(fs.stat, config.layouts)
    .then (exists) ->
      log.silly "generate", "Loading layouts from %s", config.layouts
      deferred.resolve(
        helpers.mapFiles(
          path.join(config.layouts, "**/*")
          helpers.getMetadataAndContent
        )
      )
    .fail ->
      log.verbose "generate", "Couldn't load layouts from: %s (%s)",
        config.layouts, err.message
      deferred.resolve {}

  deferred.promise

normalizeLayoutName = (name, layoutDir) ->
  # Remove extension
  name = helpers.stripExtension name
  helpers.stripDirectoryPrefix name, layoutDir

loadContents = (config) ->
  log.verbose "generate", "Loading contents from %s", config.source
  helpers.getFileList(path.join(config.source, "**/*"))
    .then (files) ->
      # Segregate files into posts and non-posts (pages and static files)
      { posts, others } = filterFiles config, files, postMask

      Q.all [
        loadPosts config, posts
        loadOthers config, others
      ]
    .then ([posts, { pages, files }]) ->
      log.verbose "generate", "Content loading complete"
      { posts, pages, files }

loadPosts = (config, files) ->
  posts = []
  log.verbose "generate", "Loading posts %s", files.join ", "
  # TODO: Rate limit
  Q.all(files.map (file) ->
    loadPost(config, file).then (post) -> posts.push post
  )
    .then ->
      # Sort posts by date
      posts = posts.sort (a, b) -> b.date - a.date
      # Setup previous / next on each post
      prev = null
      for post in posts
        # Now that the list is in chronological order, the previous post in the
        # loop is actually the older post, and therefore "next".
        if prev
          post.next = prev
          prev.prev = post
        prev = post

      # Ruby arrays have .first and .last, which some templates depend upon
      posts.first = posts[0]
      posts.last = posts[posts.length - 1]

      posts

loadPost = (config, file) ->
  log.silly "generate", "loadPost(%s)", file
  helpers.getMetadataAndContent(file)
    .then (val) ->
      { data, content } = val
      match = path.basename(file).match postMask

      # Posts always have metadata
      data or= {}
      # Save original filepath
      data.path = file
      # Posts are published by default
      unless "published" of data
        data.published = true
      # Date comes from filename and gets parsed with at noon in timezone
      data.date = new Date match[1], match[2] - 1, match[3], 12, 0, 0, 0, 0
      slug = match[4]
      # Tags
      if data.tags and typeof data.tags is "string"
        data.tags = data.tags.split /\s+/
      # Alias category to categories
      if data.category and not data.categories
        data.categories = data.category
        delete data.category
      # Categories
      if data.categories and typeof data.categories is "string"
        data.categories = data.categories.split /\s+/
      # Add any categories from the directory
      directoryCategories = getCategoriesFromPostPath file, config
      if directoryCategories.length
        data.categories = (data.categories or []).concat directoryCategories
      # Calculate the permalink
      data.url = getPermalink slug, data, config.permalink
      # Use permalink as unique ID
      data.id = data.url

      data.content = content

      log.verbose "generate", "Loaded post: %s", file
      log.silly "generate", "loadPost(%s) -> %j", file, data
      data

getCategoriesFromPostPath = (file, config) ->
  # Remove path source root
  path.dirname(path.relative config.source, file)
    .split("/").filter (f) -> f and f isnt "_posts"

getPermalink = (slug, data, permalinkStyle) ->
  return permalinkStyle
    .replace(":year", data.date.getFullYear())
    .replace(":month", helpers.twoDigitPad data.date.getMonth() + 1)
    .replace(":day", helpers.twoDigitPad data.date.getDate())
    .replace(":title", slug)
    .replace(":categories", if data.categories then data.categories.join "/" else "")
    .replace(":i_month", data.date.getMonth() + 1)
    .replace(":i_day", data.date.getDate())
    .replace("//", "/")

# Generate a list of pages and static files
loadOthers = (config, others) ->
  log.silly "generate", "Loading non-posts %j", others
  pages = []
  files = []
  # TODO: Rate limit
  Q.all(
    others.map (file) ->
      loadPageOrFile(config, file)
        .then ({page, file}) ->
          if page then pages.push page else files.push file
  ).then ->
    log.silly "generate", "Non-post load complete"
    {pages, files}

loadPageOrFile = (config, file) ->
  log.silly "generate", "Loading post or file %s", file
  helpers.getMetadataAndContent(file)
    .then (val) ->
      { data, content } = val

      # Nothing to do for static files
      unless data
        log.silly "generate", "Found file %s", file
        return { file, page: null }

      # Pages are published by default
      unless "published" of data
        data.published = true
      # Save original filepath
      data.path = helpers.stripDirectoryPrefix file, config.source
      # Use path as ID since it should be pretty stable
      data.id = data.path
      # Use filepath as URL at first (gets changed during output)
      data.url = "/" + data.path
      # Use permalink as id
      data.id = data.url

      data.content = content

      log.silly "generate", "Loaded page %s", file

      { page: data, file }

filterFiles = (config, files, mask) ->
  posts = []
  others = []
  # Segregate files into posts and non-posts (pages and static files)
  files.forEach (file) ->
    isPost = false
    for dir in file.split "/"
      continue if dir in [".", ".."]

      # Save out posts
      if dir is "_posts"
        isPost = true
        continue
      # Hidden file?
      else if (dir not in config.include) and
              (dir[0] is "_" or dir[0] is "." or dir in config.exclude)
        return

    if isPost
      posts.push file
    else
      others.push file

  # Filter any posts that don't match the filename pattern
  posts = posts.filter (file) -> mask.test path.basename file

  { posts, others }

checkDirectories = (config) ->
  log.silly "generate", "checkingDirectories(%j)", config
  Q.all [
    checkSourceDirectory config.source
    checkDestinationDirectory config.destination
  ]

# Must exist and be a directory
checkSourceDirectory = (dir) ->
  log.silly "generate", "Checking for source directory %s", dir
  deferred = Q.defer()
  dir or= "."
  helpers.isDirectory(dir)
    .then (result) ->
      if result
        log.silly "generate", "Source directory present %s", dir
        deferred.resolve()
      else
        deferred.reject new Error "Source is not a directory: #{dir}"
    .fail ->
      deferred.reject new Error "Source directory does not exist: #{dir}"
  deferred.promise

# May either not exist (in which case it will be created), or must exist and be
# a directory
checkDestinationDirectory = (dir) ->
  log.silly "generate", "Checking for destination directory %s", dir
  deferred = Q.defer()
  helpers.isDirectory(dir)
    .then (result) ->
      if result
        log.silly "generate", "Destination directory present %s", dir
        deferred.resolve()
      else
        # Exists but isn't directory
        log.error "generate", "Destination is not a directory %s", dir
        deferred.reject new Error "Destination is not a directory: #{dir}"
    .fail ->
      # Create the directory
      log.verbose "generate", "Creating destination directory %s", dir
      deferred.resolve Q.nfcall fs.mkdirs, dir

  deferred.promise

# Built-in enfield plugins
loadBundledPlugins = ->
  loadPlugins([path.join __dirname, "plugins"])
    .then (plugins) ->
      bundledPlugins = plugins
      # Copy default filters, but don't overwrite
      for key, filter of tinyliquid.filters
        unless key of bundledPlugins.filters
          bundledPlugins.filters[key] = filter
      return

loadSitePlugins = (config) ->
  # Resolve directories relative to source
  dirs = config.plugins.map (dir) -> path.resolve config.source, dir
  # Only check directories that actually exist
  Q.allSettled(dirs.map (dir) -> Q.nfcall fs.stat, dir)
    .then (results) ->
      pluginDirs = dirs.filter (dir, i) -> results[i].state is "fulfilled"

      loadPlugins pluginDirs

loadPlugins = (dirs) ->
  log.verbose "generate", "Looking for plugins in: %s", dirs.join ", "
  Q.all(dirs.map (dir) -> Q.nfcall fs.readdir, dir)
    .then (dirListings) ->
      plugins =
        filters: {}
        tags: {}
        converters: []
        generators: []

      # Make a single list of eligible files
      allFiles = dirListings
        # Resolve Paths
        .map (listing, i) ->
          listing.map (f) -> path.join dirs[i], f
        # Merge lists
        .reduceRight(((prev, listing) -> prev.concat listing), [])
        # Remove non-code files
        .filter (f) ->
          ext = path.extname f
          ext in [".js",".coffee"] or fs.statSync(f).isDirectory()

      log.silly "generate", "Found plugins %j in %j",
        allFiles.map(path.basename), dirs

      for file in allFiles
        loadFileIntoPlugins file, plugins

      plugins

loadFileIntoPlugins = (file, plugins) ->
  log.verbose "generate", "Loading plugin: %s", file
  plugin = require file

  if "filters" of plugin
    for key, filter of plugin["filters"]
      log.silly "generate", "Found filter for %s", key
      plugins.filters[key] = filter
  if "tags" of plugin
    for key, tag of plugin["tags"]
      log.silly "generate", "Found tag for %s", key
      plugins.tags[key] = tag
  if "converters" of plugin
    for key, converter of plugin["converters"]
      log.silly "generate", "Found converter for %s", key
      plugins.converters.push converter
  if "generators" of plugin
    for key, generator of plugin["generators"]
      log.silly "generate", "Found generator for %s", key
      plugins.generators.push generator

# Export internal functions when testing
if process.env.NODE_ENV is "test"
  exports.filterFiles = filterFiles
  exports.getPermalink = getPermalink
  exports.convertContent = convertContent
  exports.getCategoriesFromPostPath = getCategoriesFromPostPath
