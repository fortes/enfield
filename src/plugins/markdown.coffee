marked = require 'marked'
highlight = require 'highlight'

# Initialize markdown
marked.setOptions
  gfm: true
  sanitize: true
  highlight: (code, lang) ->
    highlight.Highlight code

module.exports =
  converters:
    markdown:
      priority: 2
      matches: (ext) ->
        ext is '.md'
      outputExtension: (ext) ->
        '.html'
      convert: (content) ->
        marked content
