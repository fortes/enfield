marked = require 'marked'
highlight = require '../highlight'

# Initialize markdown
marked.setOptions
  gfm: true

module.exports =
  converters:
    markdown:
      priority: 2
      matches: (ext) ->
        ext is '.md' or ext is '.markdown'
      outputExtension: (ext) ->
        '.html'
      convert: (content, callback) ->
        converted = marked content
        highlight.highlightCodeBlocks converted, callback
