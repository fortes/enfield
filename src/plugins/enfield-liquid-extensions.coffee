# Liquid extensions added by enfield

module.exports =
  filters:
    json_escape: (str) ->
      JSON.stringify str
