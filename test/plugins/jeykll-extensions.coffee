assert = require "assert"
sinon  = require "sinon"

{filters, tags, generators} = require "../../src/plugins/jekyll-extensions"

# Mock site data structure
site = null

resetSite = ->
  site =
    posts: []
    pages: []
    static_files: []

# List here: http://jekyllrb.com/docs/templates/
describe "Jekyll liquid filters", ->
  it "should support date_to_xmlschema", ->
    result = filters.date_to_xmlschema "Dec 31 1999"
    # Ignore timezone offset
    assert.equal result.substr(0, 19), "1999-12-31T00:00:00"

  it "should support date_to_rfc822", ->
    result = filters.date_to_rfc822 "Dec 31 1999"
    # Ignore timezone offset
    assert.equal result.substr(0, 25), "Fri, 31 Dec 1999 00:00:00"

  it "should support date_to_string", ->
    result = filters.date_to_string "Dec 31 1999"
    # Ignore timezone offset
    assert.equal result, "31 Dec 1999"

  it "should support date_to_long_string", ->
    result = filters.date_to_long_string "Dec 31 1999"
    # Ignore timezone offset
    assert.equal result, "31 December 1999"

  it "should support xml_escape", ->
    result = filters.xml_escape "1 < 2"
    assert.equal result, "1 &lt; 2"

  it "should support cgi_escape", ->
    result = filters.cgi_escape "foo,bar;baz?"
    assert.equal result, "foo%2Cbar%3Bbaz%3F"

  it "should support uri_escape", ->
    result = filters.uri_escape "foo, bar \\baz?"
    assert.equal result, "foo%2C%20bar%20%5Cbaz%3F"

  it "should support number_of_words", ->
    assert.equal filters.number_of_words("hello there world"), 3

  it "should support array_to_sentence_string", ->
    assert.equal filters.array_to_sentence_string(["a", "b", "c"]),
      "a, b, and c"

  #it "should support textilize", ->
    #assert false, "Not implemented"

  #it "should support markdownify", ->
    #assert false, "Not implemented"

  it "should support jsonify", ->
    assert.equal filters.jsonify([1,2]), JSON.stringify [1,2]

describe "Jekyll liquid tags", ->
  #it "should support highlight", ->
    #assert false, "Not implemented"

  it "should support post_url", ->
    site =
      posts: [
        {
          path: "_posts/2010-01-01-welcome.md"
          url: "/2010/welcome.html"
          date: new Date 2010, 0, 1, 12, 0, 0, 0, 0
          slug: "welcome"
        }
      ]

    assert.equal tags.post_url("2010-01-01-welcome", {}, site),
      "/2010/welcome.html"

    assert.equal tags.post_url("2010-01-01-bogus", {}, site), "#",
      "Hash fallback"

  #it "should support gist", ->
    #assert false, "Not implemented"

describe "Jekyll generators", ->
  site = null

  beforeEach ->
    site =
      config:
        paginate: 5
      posts: [
        # Just need objects
        {}, {}, {}, {}, {},
        {}, {}, {}, {}, {},
        {}, {}, {}, {}, {},
        {}, {}
      ]
      pages: [
        { url: "/index" },
        { url: "/about/index" }
      ]

  it "should support pagination", ->
    generators.pagination site, (err) ->
      assert !err, "No error thrown"
      assert site.pages.length, 5, "New pages generated"
      for page in site.pages
        continue if /about/.test page.url
        assert page.paginator, "Paginator object present in generated pages"

      finalPaginator = site.pages[4]?.paginator
      assert.equal finalPaginator.posts.length, 2,
        "Final paginator only has two posts"
      assert.equal finalPaginator.total_posts, site.posts.length,
        "Total post count"
      assert.equal finalPaginator.previous_page, 3, "Prev page for final"
      assert !finalPaginator.next_page, "No next page after final"
