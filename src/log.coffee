# Wrapper around npmlog that adds timestamp
npmlog = require "npmlog"

showTimestamp = false

module.exports =
  getRecord: ->
    npmlog.record
  setLevel: (level) ->
    npmlog.level = level
  showTimestamp: (setting) ->
    showTimestamp = setting

["error", "warn", "http", "info", "verbose", "silly"].forEach (level) ->
  module.exports[level] = ->
    args = Array::slice.apply arguments

    # Make sure there is always a prefix
    if args.length is 1
      args[1] = args[0]
      args[0] = "enfield"

    # Prepend the timestamp to log messages
    if showTimestamp
      args[1] = "[#{timestamp()}] #{args[1]}"

    npmlog[level].apply npmlog, args

timestamp = ->
  (new Date).toLocaleTimeString()
