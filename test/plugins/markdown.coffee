assert   = require "assert"
pygments = require "pygments"
sinon    = require "sinon"

{converters} = require "../../src/plugins/markdown"
config = { pygments: true }

describe "Markdown converter", ->
  sandbox = null
  beforeEach ->
    sandbox = sinon.sandbox.create()
  afterEach ->
    sandbox.restore()

  it "Matches .md and .markdown extensions", ->
    assert converters.markdown.matches(".md"), ".md"
    assert converters.markdown.matches(".markdown"), ".markdown"
    assert !converters.markdown.matches(".mdown"), ".mdown"

  it "Outputs .html extension", ->
    assert.equal converters.markdown.outputExtension(".md"), ".html"
    assert.equal converters.markdown.outputExtension(".markdown"), ".html"

  it "Converts markdown", (done) ->
    converters.markdown.convert "*Hello* **World**", config, (err, output) ->
      assert !err, "No error thrown: #{err?.message}"
      assert.equal output, "<p><em>Hello</em> <strong>World</strong></p>\n"
      done()

  it "Highlights code", (done) ->
    pygmentsOutput = '<div class="highlight"><pre>
<span class="kd">var</span> <span class="nx">foo</span> <span class="o">=</span>
 <span class="s2">&quot;bar&quot;</span><span class="p">;</span>\n
</pre></div>\n'
    expected = """<pre><code class="lang-js"><span class="kd">var</span> <span class="nx">foo</span> <span class="o">=</span> <span class="s2">&quot;bar&quot;</span><span class="p">;</span>\n</code></pre>\n"""

    sandbox.stub(pygments, "colorize")
      .callsArgWithAsync(3, pygmentsOutput)

    md = """``` js
         var foo = "bar";
         ```"""

    converters.markdown.convert md, config, (err, output) ->
      assert !err, "No error thrown: #{err?.message}"
      assert.equal output, expected
      done()

  it "uses highlight.js if pygments: false", (done) ->
    md = """``` js
            var foo = "bar";
            ```"""
    expected = """<pre><code class="lang-js">\
                  <span class="hljs-keyword">var</span> foo = \
                  <span class="hljs-string">"bar"</span>;
                  </code></pre>\n"""

    converters.markdown.convert md, { pygments: false }, (err, output) ->
      assert !err, "No error thrown: #{err?.message}"
      assert.equal output, expected
      done()
