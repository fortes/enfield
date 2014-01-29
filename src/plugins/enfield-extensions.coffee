# Built-in generators
async  = require "async"
coffee = require "coffee-script"
fs     = require "fs-extra"
less   = require "less"
log    = require "../log"
path   = require "path"
uglify = require "uglify-js"

createRedirectHTML = (page) ->
  {url} = page
  return """
<!doctype html>
<html>
  <head>
    <link rel="canonical" href="#{url}">
    <meta http-equiv="refresh" content="0;url=#{url}">
  </head>
  <body><a href="#{url}">This page has moved to a new location.</a></body>
</html>
"""

stripExtension = (name) ->
  basename = path.basename name, path.extname name
  dirname = path.dirname name
  path.join dirname, basename

module.exports =
  tags:
    page_url: (body, page, site) ->
      if body
        for page in site.pages
          if body is page.path or body is stripExtension page.path
            return page.url

      log.warn "page_url", "page_url #{body} could not be found"
      return "#"

  generators:
    # Generates url aliases
    # Inspired by https://github.com/tsmango/jekyll_alias_generator
    alias: (site, callback) ->
      # Look for page aliases and an HTML-based redirect
      for page in site.posts.concat site.pages
        continue unless page.alias

        # Make HTML for client-side redirect
        html = createRedirectHTML page

        # Support string or Array
        unless Array.isArray page.alias
          page.alias = [page.alias]
        for alias in page.alias
          # Add a plain page
          site.pages.push {
            published: page.published
            url: alias
            content: html
            ext: ".html"
          }

      # Do the callback async to avoid crazy stack traces
      process.nextTick callback

    # Compile CoffeeScript files to minified JS
    coffeeScript: (site, callback) ->
      # Collect files and remove original .coffee sources
      coffeeFiles = []
      for filepath, i in site.static_files
        continue unless path.extname(filepath) is ".coffee"
        # Remove from output
        site.static_files[i] = null
        coffeeFiles.push filepath

      # Work in parallel
      async.forEachLimit(
        coffeeFiles
        5
        (filepath, cb) ->
          fs.readFile filepath, (err, contents) ->
            if err then return cb err
            try
              # Compile and minify
              compiled = coffee.compile contents.toString()

              # Uglify2 new API
              ast = uglify.parse compiled
              ast.figure_out_scope()
              compressor = uglify.Compressor()
              ast = ast.transform compressor
              minified = ast.print_to_string()

              # Output
              outPath = filepath.replace /\.coffee$/, ""
              site.pages.push {
                published: true
                url: outPath
                content: minified
                ext: ".js"
              }
            catch err
              # Non-fatal
              log.warn "CoffeeScript Compilation Error: #{err.message}".red
            cb()
        callback
      )

    # Compile LESS files into minified CSS
    lessCSS: (site, callback) ->
      # Collect files and remove original .less source
      lessFiles = []
      for filepath, i in site.static_files
        continue unless path.extname(filepath) is ".less"
        # Remove from output
        site.static_files[i] = null
        lessFiles.push filepath

      # Work in parallel
      async.forEachLimit(
        lessFiles
        5
        (filepath, cb) ->
          fs.readFile filepath, (err, contents) ->
            if err then return cb err

            options =
              compress: true
              # For relative includes
              paths: [path.dirname filepath]

            # Render CSS
            less.render contents.toString(), options, (err, css) ->
              if err
                log.error "LESS Compilation Error: #{err.message}".red
                return cb()

              outPath = filepath.replace /\.less$/, ""
              site.pages.push {
                published: true
                url: outPath
                content: css
                ext: ".css"
              }

              cb()
        callback
      )
