# Use pygments to highlight code blocks in HTML
highlight = require('pygments').colorize
async = require 'async'
ent = require 'ent'

CODE_BLOCK_REGEX = /<pre>(.+)<\/pre>/mi

module.exports =
  highlightCodeBlocks: (html, callback) ->
    unless ///<code///.test html
      # No code blocks, return immediately
      callback null, html
      return

    regex = ///<pre><code(?:\s+class="lang-([^"]+)"\s*)?>([\s\S]+?)</code></pre>///img
    matches = []
    while match = regex.exec html
      matches.push match

    # Convert each code block
    async.map(
      matches,
      (item, cb) ->
        [input, lang, code] = item
        # Code is HTML encoded, so we need to unescape
        code = ent.decode code
        highlight code, lang, 'html', (data) ->
          # Strip out the HTML wrapper added around the code, and return the
          # <pre> and <code> around the data
          cb null, data.replace(
            /^<div class="highlight"><pre>([\s\S]+)<\/pre><\/div>$/img,
            (match, p1, offset, str) ->
              """<pre><code class="lang-#{lang or 'unknown'}">#{p1}</code></pre>"""
          )
      (err, results) ->
        if err then return callback err
        # Now replace each instance
        i = -1
        callback null, html.replace regex, (match) ->
          i += 1
          return results[i]
    )
