process.env.NODE_ENV = "test"

assert = require "assert"

generate = require "../src/generate"

describe "getCategoriesFromPostPath", ->
  config = { source: "" }

  it "supports category directories within _posts", ->
    config.source = "./"
    file = "_posts/cat1/cat2/2014-01-14-my-post.md"
    cats = generate.getCategoriesFromPostPath file, config
    assert.deepEqual cats, ["cat1", "cat2"]

  it "supports _posts within category directories", ->
    config.source = "./"
    file = "cat1/cat2/_posts/2014-01-14-my-post.md"
    cats = generate.getCategoriesFromPostPath file, config
    assert.deepEqual cats, ["cat1", "cat2"]

  it "ignores directories from root path", ->
    config.source = "/var/source"
    file = "/var/source/cat/_posts/2014-01-14-my-post.md"
    cats = generate.getCategoriesFromPostPath file, config
    assert.deepEqual cats, ["cat"]

describe "getPermalink", ->
  it "works as expected", ->
    slug = "welcome"
    post = {
      date: new Date(2000, 0, 1, 12, 0, 0, 0, 0)
      categories: ["cat1", "cat2"]
    }

    assert.equal generate.getPermalink(slug, post, "/:year/:title"),
      "/2000/welcome"

    assert.equal generate.getPermalink(slug, post, "/blog/:categories/:title"),
      "/blog/cat1/cat2/welcome"

    assert.equal generate.getPermalink(slug, post, "/:year/:month/:day/:title"),
      "/2000/01/01/welcome"

    assert.equal generate.getPermalink(slug, post, "/:year/:i_month/:i_day/:title"),
      "/2000/1/1/welcome"

describe "filterFiles", ->
  it "overwrites pre-existing filters and tags", ->
    config =
      include: [".htaccess"]
      exclude: ["README"]
    files = [
      ".htaccess"                      # Included
      "README"                         # Excluded via config
      ".private"                       # Excluded by file name
      "_stuff/image.jpg"               # Excluded by directory name
      "_posts/2010-01-01-welcome.md"   # Post
      "dogs/_posts/2011-01-01-dogs.md" # Post in subdir
      "_posts/stray.html"              # Non-post in post directory
      "about.md"
      "projects/intro.md"
      "./about.md"                     # Included even though begins with "."
      "../about.md"                    # Included even though begins with "."
      "music/2011-01-01-music-post.md" # Page since not in _posts
    ]
    mask = /^(\d{4})-(\d{2})-(\d{2})-(.+)\.(md|html)$/

    { posts, others } = generate.filterFiles config, files, mask

    assert "_posts/2010-01-01-welcome.md" in posts, "posts included"
    assert "dogs/_posts/2011-01-01-dogs.md" in posts,
    assert !("_posts/stray.html" in posts),
      "files that don't match mask excluded from posts"

    assert ".htaccess" in others, "config.include respected"
    assert !("README" in others), "config.exclude respected"
    assert !(".private" in others), "dotfiles excluded"
    assert !("_stuff/image.jpg" in others), "files in _directories excluded"
    assert "about.md" in others, "pages included"
    assert "projects/intro.md" in others, "pages in subdirectories included"
    assert "music/2011-01-01-music-post.md" in others,
      "pages that matches post mask but outside of _posts"

describe "convertContent", ->
  config = { source: "" }

  converters = [
    {
      matches: (ext) -> ext is ".md"
      outputExtension: (ext) -> ".html"
      convert: (content, config, callback) -> callback null, "Converted"
    }
  ]

  it "calls properly calls converters", (done) ->
    generate.convertContent(".md", "myContent", converters, config)
      .nodeify (err, converted) ->
        assert !err, "No error thrown"
        assert.equal converted.ext, ".html", "Extension modified"
        assert.equal converted.content, "Converted", "Content converted"
        done()

  it "leaves content alone if no converter is found", (done) ->
    generate.convertContent(".bogus", "myContent", converters, config)
      .nodeify (err, converted) ->
        assert !err, "No error thrown"
        assert.equal converted.ext, ".bogus", "Extension unmodified"
        assert.equal converted.content, "myContent", "Content unmodified"
        done()
