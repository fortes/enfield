textile = require 'textilejs'
highlight = require 'highlight'

module.exports =
  converters:
    markdown:
      priority: 2
      matches: (ext) ->
        ext is '.textile'
      outputExtension: (ext) ->
        '.html'
      convert: (content, callback) ->
        callback null, textile content, {
          wrapBlocks: true
          highlight: (code) ->
            highlight.Highlight code
        }
