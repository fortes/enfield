assert = require "assert"

generate = require "../src/generate"

describe "filterFiles", ->
  it "overwrites pre-existing filters and tags", ->
    config =
      include: ['.htaccess']
      exclude: ['README']
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
