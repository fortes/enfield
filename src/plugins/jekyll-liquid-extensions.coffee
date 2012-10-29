# Liquid extensions added by Jekyll
moment = require 'moment'
querystring = require 'querystring'

module.exports =
  filters:
    date_to_xml_schema: (str) ->
      date = moment str
      if date.isValid()
        date.format "ddd MMM DD HH:mm:ss ZZ YYYY"
        # date.format "YYYY-MM-DDTHH:mm:ssZZ"
      else
        str
    date_to_string: (str) ->
      date = moment str
      if date.isValid()
        date.format "DD MMM YYYY"
      else
        str
    date_to_long_string: (str) ->
      date = moment str
      if date.isValid()
        date.format "DD MMMM YYYY"
      else
        str
    xml_escape: (str) ->
      str.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    cgi_escape: (str) ->
      querystring.escape str
    uri_escape: (str) ->
      encodeURIComponent str
    number_of_words: (str) ->
      str?.split(' ').length
    array_to_sentence_string: (array) ->
      len = array.length
      connector = "and"
      switch len
        when 0
          ''
        when 1
          array[0]
        when 2
          "#{array[0]} #{connector} #{array[1]}"
        else
          "#{array.substr(0, len-2).join ', '}, #{connector} #{array[len - 1]}"

    # textilize
    # markdownify
