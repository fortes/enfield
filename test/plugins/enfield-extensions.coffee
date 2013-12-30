assert = require "assert"
coffee = require "coffee-script"
fs     = require "fs-extra"
less   = require "less"
log    = require "npmlog"
sinon  = require "sinon"
uglify = require "uglify-js"

{tags, generators} = require "../../src/plugins/enfield-extensions"

# Mock site data structure
site = null

# Silence logs
log.level = "silent"

resetSite = ->
  site =
    posts: [
      {
        path: "_posts/2010-01-01-welcome.md"
        url: "/2010/welcome.html"
        alias: "/welcome"
      }
    ]
    pages: [
      { path: "index.html", url: "/", ext: ".html" }
      { path: "about.md", url: "/about.html", alias: "about-me", ext: ".html" }
      { path: "project/foo.md", url: "/project/foo.html", alias: ["foo", "project-foo"], ext: ".html" }
    ]
    static_files: [
      "css/style.less"
      "script/script.coffee"
      "script/script2.coffee"
      "me.jpg"
    ]

describe "page_url tag", ->
  beforeEach resetSite

  it "Outputs the final URL based on path", ->
    assert.equal tags.page_url("about", {}, site), "/about.html"

  it "Uses # as a fallback when not found", ->
    assert.equal tags.page_url("bogus", {}, site), "#"

describe "Page alias generator", ->
  beforeEach ->
    resetSite()

  it "Page alias", (done) ->
    generators.alias site, (err) ->
      assert !err, "No error thrown"
      aliases = site.pages.filter (page) -> page.url is "about-me"

      assert.equal aliases.length, 1, "Alias found"
      done()

  it "Post alias", (done) ->
    generators.alias site, (err) ->
      assert !err, "No error thrown"
      aliases = site.pages.filter (page) -> page.url in ["/welcome"]
      assert.equal aliases.length, 1, "Alias found"
      done()

  it "Supports array of aliases", (done) ->
    generators.alias site, (err) ->
      assert !err, "No error thrown"
      aliases = site.pages.filter (page) -> page.url in ["foo", "project-foo"]
      assert.equal aliases.length, 2, "Aliases found"
      done()

describe "CoffeeScript compiler", ->
  sandbox = null

  beforeEach ->
    resetSite()
    sandbox = sinon.sandbox.create()
    # Stub out CoffeeScript & file read
    sandbox.stub(fs, "readFileSync").returns("cs")
    sandbox.stub(coffee, "compile").returns("window.alert( 'Hi' )")

  afterEach ->
    sandbox.restore()

  it "Converts .coffee files to .js", (done) ->
    generators.coffeeScript site, (err) ->
      assert !err, "No error thrown"
      # Make sure .coffee is gone from output
      coffeeFiles = site.static_files.filter (file) -> /coffee/.test file
      assert.equal coffeeFiles.length, 0, "Coffee removed from static list"

      # Make sure JS is output as page
      jsPage = site.pages.filter (page) -> page.ext is ".js"
      assert.equal jsPage.length, 2, "JS pages generated"
      assert.equal jsPage[0].url, "script/script", "URL"
      assert.equal jsPage[0].content, 'window.alert("Hi");', "Content"
      done()

describe "LESS compiler", ->
  sandbox = null

  beforeEach ->
    resetSite()
    sandbox = sinon.sandbox.create()
    # Stub out CoffeeScript & file read
    sandbox.stub(fs, "readFile").callsArgWithAsync(1, null, "less")
    sandbox.stub(less, "render").callsArgWithAsync(2, null, "css")

  afterEach ->
    sandbox.restore()

  it "Converts LESS files to CSS", (done) ->
    generators.lessCSS site, (err) ->
      assert !err, "No error thrown"
      # Make sure .less is gone from output
      lessFiles = site.static_files.filter (file) -> /less/.test file
      assert.equal lessFiles.length, 0, ".less removed from static list"

      cssPage = site.pages.filter (page) -> page.ext is ".css"
      assert.equal cssPage.length, 1, "CSS page generated"
      assert.equal cssPage[0].url, "css/style", "URL"
      assert.equal cssPage[0].content, "css", "Content"
      done()
