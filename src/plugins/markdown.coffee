highlight = require('pygments').colorize
marked    = require 'marked'

# Initialize markdown
marked.setOptions
  gfm: true
  smartypants: true
  highlight: (code, lang, callback) ->
    highlight code, lang, 'html', (data) ->
      # Strip out the HTML wrapper added around the code
      data = data.replace(
        # Final \s is for newline
        /^<div class="highlight"><pre>([\s\S]+)\s<\/pre><\/div>$/img,
        (match, p1, offset, str) -> p1
      )
      callback null, data

module.exports =
  converters:
    markdown:
      priority: 2
      matches: (ext) ->
        ext is '.md' or ext is '.markdown'
      outputExtension: (ext) ->
        '.html'
      convert: (content, callback) ->
        converted = marked content, {}, callback
