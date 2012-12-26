marked = require 'marked'
highlight = require 'highlight'

# Initialize markdown
marked.setOptions
  gfm: true
  highlight: (code, lang) ->
    highlight.Highlight code

module.exports =
  converters:
    markdown:
      priority: 2
      matches: (ext) ->
        ext is '.md' or ext is '.markdown'
      outputExtension: (ext) ->
        '.html'
      convert: (content, callback) ->
        callback null, marked content
