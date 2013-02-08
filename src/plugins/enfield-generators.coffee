# Built-in generators
async = require 'async'
coffee = require 'coffee-script'
fs = require 'fs-extra'
less = require 'less'
uglify = require 'uglify-js'
path = require 'path'

createRedirectHTML = (page) ->
  url = page.url
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

module.exports =
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
            raw_content: html
            ext: '.html'
          }

      callback()

    # Compile CoffeeScript files to minified JS
    coffeeScript: (site, callback) ->
      for filepath in site.static_files
        if /\.coffee$/.test filepath
          # Compile and minify
          fileContents = fs.readFileSync(filepath).toString()
          try
            compiled = coffee.compile fileContents
            minified = uglify compiled

            # Output
            outPath = filepath.replace /\.coffee$/, ''
            site.pages.push {
              published: true
              url: outPath
              raw_content: minified
              ext: '.js'
            }
          catch err
            console.error "CoffeeScript Compilation Error: #{err.message}".red

      callback()

    # Compile LESS files into minified CSS
    lessCSS: (site, callback) ->
      # Collect files
      lessFiles = site.static_files.filter (f) -> /\.less$/.test f

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
                console.error "LESS Compilation Error: #{err.message}".red
                return cb()

              outPath = filepath.replace /\.less$/, ''
              site.pages.push {
                published: true
                url: outPath
                raw_content: css
                ext: '.css'
              }
              cb()
        callback
      )
