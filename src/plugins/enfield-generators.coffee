# Built-in generators
coffee = require 'coffee-script'
uglify = require 'uglify-js'
fs = require 'fs-extra'

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
    alias: (site) ->
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

    # Compile CoffeeScript files to minified JS
    coffeeScript: (site) ->
      for filepath in site.static_files
        if /\.coffee$/.test filepath
          # Compile and minify
          fileContents = fs.readFileSync(filepath).toString()
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
