pygments = require "pygments"
marked   = require "marked"

# Initialize markdown
marked.setOptions
  gfm: true
  smartypants: true

pygmentsHighlight = (code, lang, callback) ->
  pygments.colorize code, lang, "html", (data) ->
    # Strip out the HTML wrapper added around the code
    data = data.replace(
      /^<div class="highlight"><pre>([\s\S]+)<\/pre><\/div>$/img,
      (match, p1, offset, str) -> p1
    ).trim()
    callback null, data

module.exports =
  converters:
    markdown:
      priority: 2
      matches: (ext) ->
        ext is ".md" or ext is ".markdown"
      outputExtension: (ext) ->
        ".html"
      convert: (content, config, callback) ->
        if config.pygments
          marked.setOptions { highlight: pygmentsHighlight }
        else
          marked.setOptions { highlight: null }
        converted = marked content, {}, callback
