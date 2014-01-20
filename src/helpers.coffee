# Misc helpers
async = require "async"
fs    = require "fs-extra"
glob  = require "glob"
log   = require "./log"
path  = require "path"
Q     = require "q"
yaml  = require "js-yaml"

FRONT_MATTER_DELIMITER = /^---\s*$/

module.exports = exports =
  # Get a list of filenames that match a given pattern, filtering out
  # directories
  getFileList: (pattern) ->
    Q.nfcall(glob, pattern)
      .then (files) ->
        Q.allSettled(files.map (file) -> Q.nfcall fs.stat, file)
          .then (results) ->
            # Filter out directories
            files.filter (file, i) ->
              result = results[i]
              result.state is "fulfilled" and not result.value.isDirectory()

  # Call a function across all files matching a pattern, and return the result
  # in a map { filename: result }
  mapFiles: (pattern, fun) ->
    results = {}
    exports.getFileList(pattern)
      .then (files) ->
        # TODO: Rate limit
        Q.all(files.map (file) -> fun file)
          .then (results) ->
            output = {}
            for result, i in results
              output[files[i]] = result
            output

  # Get frontmatter plus content for a file
  getMetadataAndContent: (filepath) ->
    log.silly "helpers", "Loading metadata and content for %s", filepath
    content = Q.nfcall(fs.readFile, filepath)
      .then (buffer) ->
        content = buffer.toString()
        lines = content.split(/\r\n|\n|\r/)
        if FRONT_MATTER_DELIMITER.test lines[0]
          log.silly "helpers", "Found frontmatter for %s", filepath
          lines.shift()
          frontMatter = []

          while (lines.length)
            currentLine = lines.shift()
            break if FRONT_MATTER_DELIMITER.test currentLine
            frontMatter.push currentLine

          if frontMatter.length
            data = yaml.load frontMatter.join "\n"
            # Yaml sometimes returns non-objects
            if typeof data isnt "object"
              data = { value: data }
            for name, value of data
              # Convert nil to null, not sure why the library doesn"t do this
              if value is "nil"
                data[name] = null
            # Remaining lines are the content
            content = lines.join "\n"
        else
          log.silly "helpers", "No frontmatter for %s", filepath

        { data, content }

  # Strip file extension from filename, if any
  stripExtension: (name) ->
    basename = path.basename name, path.extname name
    dirname = path.dirname name
    path.join dirname, basename

  stripDirectoryPrefix: (name, base) ->
    if base and exports.isWithinDirectory name, base
      length = base.length + 1
      if base[base.length - 1] is "/"
        length = base.length
      name = name.substr length
    name

  # True if file is directory
  # False if file exists but isn't directory
  # Fails if file does not exist
  isDirectory: (dir) ->
    Q.nfcall(fs.stat, dir).then (stat) -> stat.isDirectory()

  isWithinDirectory: (name, base) ->
    name.substr(0, base.length) is base

  # Pad to two digits
  twoDigitPad: (num) -> if num < 10 then "0#{num}" else num
