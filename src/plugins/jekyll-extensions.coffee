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

  generators:
    "pagination": (site, callback) ->
      # Ignore if pagination isn't enabled or there are no posts
      unless site.config['paginate'] and site.posts.length
        return callback()

      # As in Jekyll, pagination only works in index.html files
      for page in site.pages
        # Only paginate at root
        unless (page.ext is '.html') and (page.url is '/')
          continue

        page_number = 1
        per_page = site.config['paginate']
        posts = site.posts.slice 0, per_page
        if site.posts.length
          total_posts = site.posts.length
        else
          total_posts = 0
        total_pages = Math.ceil total_posts / per_page
        previous_page = 0
        next_page = if page_number < total_pages then page_number + 1 else 0

        # Special case first page
        page.paginator = {
          page: page_number
          per_page
          posts
          total_posts
          total_pages
          previous_page
          next_page
        }

        remainingPosts = site.posts.slice per_page
        for page_number in [2..total_pages] by 1
          # Clone the base page
          newPage = {}
          site.pages.push newPage

          for key, value of page
            newPage[key] = value
          newPage.url = "/page#{page_number}"

          previous_page = page_number - 1
          posts = remainingPosts.slice 0, per_page
          remainingPosts = remainingPosts.slice per_page
          if page_number < total_pages
            next_page = page_number + 1
          else
            next_page = 0

          newPage.paginator = {
            page: page_number
            per_page
            posts
            total_posts
            total_pages
            previous_page
            next_page
          }

      callback()
