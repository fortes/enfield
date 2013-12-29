assert = require "assert"
sinon  = require "sinon"

config = require "../src/config"

describe "mergeConfig", ->
  it "Exposes the mergeConfig function", ->
    assert config.mergeConfig, "mergeConfig function exposed"

  it "Properly merges configuration options", ->
    merged = config.mergeConfig {
      one: "one-left", two: "two-left"
    }, { two: "two-right", three: "three-right" }

    assert.deepEqual merged, {
      one: "one-left"
      two: "two-right"
      three: "three-right"
    }

describe "resolveOptions", ->
  values = {}
  sandbox = null

  beforeEach ->
    sandbox = sinon.sandbox.create()
    values = config.mergeConfig {}, config.DEFAULTS

  afterEach ->
    sandbox.restore()

  it "Exposes the resolveOptions function", ->
    assert config.resolveOptions, "resolveOptions function exposed"

  # Permalink styles documented here: http://jekyllrb.com/docs/permalinks/
  it "Supports Jekyll's 'date' permalink style", ->
    values.permalink = "date"
    config.resolveOptions values
    assert.equal values.permalink, "/:categories/:year/:month/:day/:title.html"

  it "Supports Jekyll's 'pretty' permalink style", ->
    values.permalink = "pretty"
    config.resolveOptions values
    assert.equal values.permalink, "/:categories/:year/:month/:day/:title/"

  it "Supports Jekyll's 'none' permalink style", ->
    values.permalink = "none"
    config.resolveOptions values
    assert.equal values.permalink, "/:categories/:title.html"

  it "Converts plugins value to array", ->
    values.plugins = "/foo"
    config.resolveOptions values
    assert.deepEqual values.plugins, ["/foo"]

  it "Uses relative paths for source, destination, and config paths", ->
    sandbox.stub(process, "cwd").returns "/the/root/"
    values.source = "/the/source"
    values.destination = "/the/output"
    values.config = "/the/source/config2.yml"
    config.resolveOptions values
    assert.equal values.source, "../source"
    assert.equal values.destination, "../output"
    assert.equal values.config, "../source/config2.yml"

  it "Plugin and layout directories are relative to source directory", ->
    values.source = "/source"
    values.plugins = ["_plugins", "plug2", "/var/plugins"]
    values.layouts = "_layouts"
    config.resolveOptions values
    assert.deepEqual values.plugins, ["/source/_plugins", "/source/plug2", "/var/plugins"]
    assert.equal values.layouts, "/source/_layouts"
