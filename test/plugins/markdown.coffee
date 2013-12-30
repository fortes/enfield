assert = require "assert"

{converters} = require "../../src/plugins/markdown"

describe "Markdown converter", ->
  it "Matches .md and .markdown extensions", ->
    assert converters.markdown.matches(".md"), ".md"
    assert converters.markdown.matches(".markdown"), ".markdown"
    assert !converters.markdown.matches(".mdown"), ".mdown"

  it "Outputs .html extension", ->
    assert.equal converters.markdown.outputExtension('.md'), '.html'
    assert.equal converters.markdown.outputExtension('.markdown'), '.html'

  it "Converts markdown", (done) ->
    converters.markdown.convert "*Hello* **World**", (err, output) ->
      assert !err, "No error thrown"
      assert.equal output, "<p><em>Hello</em> <strong>World</strong></p>\n"
      done()

  it "Highlights code", (done) ->
    md = """``` js
var foo = "bar";
```"""
    converters.markdown.convert md, (err, output) ->
      assert !err, "No error thrown"
      assert.equal output, '<pre><code class="lang-js">
<span class="kd">var</span> <span class="nx">foo</span> <span class="o">=</span>
 <span class="s2">&quot;bar&quot;</span><span class="p">;</span>\n
</code></pre>\n'
      done()
