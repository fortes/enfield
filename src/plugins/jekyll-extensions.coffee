# Liquid extensions added by Jekyll
moment = require 'moment'
querystring = require 'querystring'

module.exports =
  filters:
    date_to_xmlschema: (str) ->
      date = moment str
      if date.isValid()
        date.format()
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
      str.replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
    cgi_escape: (str) ->
      querystring.escape str
    uri_escape: (str) ->
      encodeURIComponent str
    number_of_words: (str) ->
      str?.split(' ').length
    array_to_sentence_string: (array, connector="and") ->
      return '' unless array
      len = array.length
      switch len
        when 0
          ''
        when 1
          array[0]
        when 2
          "#{array[0]} #{connector} #{array[1]}"
        else
          "#{array.slice(0, len-1).join ', '}, #{connector} #{array[len - 1]}"
    # textilize
    # markdownify
  tags:
    post_url: (tokens, site) ->
      # Must have a post name
      if tokens.length > 0
        match = tokens[0].match /^(\d{4})-(\d{2})-(\d{2})-(.+)$/
        if match
          [_, year, month, day, slug] = match
          date = new Date(year, month - 1, day)
          for post in site.posts
            if (slug is post.slug) and (post.date.getTime() is date.getTime())
              return post.url

      console.error "Error: post_url #{tokens[0]} could not be found"
      return '#'
