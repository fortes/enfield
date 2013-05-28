# Misc helpers
fs = require 'fs-extra'
log = require 'npmlog'
path = require 'path'
glob = require 'glob'
yaml = require 'js-yaml'
async = require 'async'

FRONT_MATTER_DELIMITER = /^---\s*$/

module.exports = exports =
  # Get a list of filenames that match a given pattern, filtering out
  # directories
  getFileList: (pattern, callback) ->
    glob pattern, (err, files) ->
      # Filter out directories
      async.filter(
        files
        (file, cb) ->
          fs.stat file, (err, stat) ->
            if err then return cb false
            cb not stat.isDirectory()
        (filtered) -> callback null, filtered
      )

  # Call a function across all files matching a pattern, and return the result
  # in a map { filename: result }
  mapFiles: (pattern, fun, callback) ->
    results = {}
    exports.getFileList pattern, (err, files) ->
      if err then return callback err

      # Avoid overwhelming the filesystem
      async.forEachLimit(
        files,
        5,
        (file, cb) ->
          fun file, (err, result) ->
            results[file] = result
            cb err
        (err) ->
          if err then return callback err
          callback null, results
      )

  # Get frontmatter plus content for a file
  getMetadataAndContent: (filepath, callback) ->
    content = fs.readFile filepath, (err, buffer) ->
      content = buffer.toString()
      lines = content.split(/\r\n|\n|\r/)
      if FRONT_MATTER_DELIMITER.test lines[0]
        lines.shift()
        frontMatter = []

        while (lines.length)
          currentLine = lines.shift()
          break if FRONT_MATTER_DELIMITER.test currentLine
          frontMatter.push currentLine

        if frontMatter.length
          data = yaml.load frontMatter.join "\n"
          # Yaml sometimes returns non-objects
          if typeof data isnt 'object'
            data = { value: data }
          for name, value of data
            # Convert nil to null, not sure why the library doesn't do this
            if value is 'nil'
              data[name] = null
          # Remaining lines are the content
          content = lines.join '\n'

      callback null, { data, content }

  # Strip file extension from filename, if any
  stripExtension: (name) ->
    basename = path.basename name, path.extname name
    dirname = path.dirname name
    path.join dirname, basename

  stripDirectoryPrefix: (name, base) ->
    if base and exports.isWithinDirectory name, base
      length = base.length + 1
      if base[base.length - 1] is '/'
        length = base.length
      name = name.substr length
    name

  isWithinDirectory: (name, base) ->
    name.substr(0, base.length) is base

  # Pad to two digits
  twoDigitPad: (num) -> if num < 10 then "0#{num}" else num
