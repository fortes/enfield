assert = require "assert"
fs     = require "fs-extra"
sinon  = require "sinon"

helpers = require "../src/helpers"

describe "getMetadataAndContent", ->
  sandbox = null
  fileContent = null
  beforeEach ->
    sandbox = sinon.sandbox.create()

  afterEach ->
    sandbox.restore()

  it "handles files with front matter", (done) ->
    fileContent = """---
my: value
---
Hello There"""

    sandbox.stub(fs, "readFile")
      .callsArgWithAsync(1, null, fileContent)

    # Can't do work within promises since thrown assertions get swallowed
    callback = (err, results) ->
      assert !err, "Error thrown: #{err?.message}"
      { data, content } = results
      assert data, "Data present"
      assert.equal data.my, "value", "Value present"
      assert.equal content, "Hello There", "Content unmodified"
      done()

    helpers.getMetadataAndContent("myfile")
      .then (results) ->
        process.nextTick -> callback null, results
      .fail (err) ->
        process.nextTick -> callback err, {}

  it "handles files without front matter", (done) ->
    fileContent = """Hello
There"""

    sandbox.stub(fs, "readFile")
      .callsArgWithAsync(1, null, fileContent)

    # Can't do work within promises since thrown assertions get swallowed
    callback = (err, results) ->
      assert !err, "Error thrown: #{err?.message}"
      { data, content } = results
      assert !data, "No data"
      assert.equal content, fileContent, "Content unmodified"
      done()

    helpers.getMetadataAndContent("myfile")
      .then (results) ->
        process.nextTick -> callback null, results
      .fail (err) ->
        process.nextTick -> callback err, {}

describe "stripExtension", ->
  it "strips extensions correctly", ->
    assert.equal helpers.stripExtension("about.md"), "about"

  it "handles dot files", ->
    assert.equal helpers.stripExtension(".htaccess"), ".htaccess"

  it "handles files without extensions", ->
    assert.equal helpers.stripExtension("README"), "README"

describe "stripDirectoryPrefix", ->
  it "removes the prefix", ->
    assert.equal helpers.stripDirectoryPrefix("/home/my/file", "/home"),
      "my/file"

  it "works even if the file isn't a child of the base directory", ->
    assert.equal helpers.stripDirectoryPrefix("/etc/my/file", "/home"),
      "/etc/my/file"
