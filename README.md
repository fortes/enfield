# Enfield

Jekyll-like static site generator for node.js that aims to be as compatible as possible with [mojombo/jekyll](https://github.com/mojombo/jekyll).

## Features

Core functionality is identical to Jekyll:

* Blog aware static site generator
* Compatible with the Jeykll directory and file structure
* Use Markdown for posts
* Code highlighting via Pygments
* Layouts written using liquid template engine
* Server / Auto-regenerate

There are a few bonus features not present in the default install of Jekyll:

* Jekyll-like plugin model, with CoffeeScript/JS instead of Ruby
* Use markdown within includes
* Compile and minify CoffeeScript & LESS
* Support post and page URL aliases via redirects
* Extension-less page URLs (i.e. `/example/` from `/example.html` via `pretty_urls` configuration variable)

Finally, there are a few missing features:

* Textile support
* Importing tools

## Usage

Generated directly from `enfield --help`

```
Enfield is a blog-aware static-site generator modeled after Jekyll

Commands:
  build                Build your site
  help                 Display global or [command] help documentation.
  new                  Creates a new Jekyll site scaffold in PATH
  serve                Serve your site locally

Global Options:
  -s, --source [DIR]
      Source directory (defaults to ./)

  -d, --destination [DIR]
      Destination directory (defaults to ./_site)

  --safe
      Safe mode (defaults to false)

  --plugins PLUGINS_DIR1[,PLUGINS_DIR2[,...]]
      Plugins directory (defaults to ./_plugins)

  --layouts
      Layouts directory (defaults to ./_layouts)

  -h, --help
      Display help documentation

  -v, --version
      Display version information
```

## Plugins

Enfield will load any `.coffee` or `.js` file from the `_plugins` directory. The plugin system is modeled after [Jekyll Plugins](https://github.com/mojombo/jekyll/wiki/Plugins). The following plugin types are supported:

* Converters
* Liquid Filters
* Custom Tags
* Generators

### Converters

Custom converters can be added. Note that only items with YAML frontmatter will be converted. All others are ignored.

```js
module.exports = {
  "converters": {
    "foo": {
      "priority": 1,
      "matches": function(ext) {
        return ext === '.foo';
      },
      "outputExtension": function(ext) {
        return ".html";
      },
      "convert": function(content, callback) {
        // Return converted value via callback(err, content)
        callback(null, content.replace('foo', ''));
      }
    }
  }
}
```

Valid priority values: 1 (lowest) - 5 (highest)

### Liquid Filters

Custom [Liquid Filters](http://wiki.shopify.com/FilterReference) can be added:

```js
module.exports = {
  "filters": {
    "upcase": function(val) {
      return val.toUpperCase();
    },
    "lowercase": function(val) {
      return val.toLowerCase();
    }
  }
}
```

### Custom Tags

```js
module.exports = {
  "tags": {
    "mytag": function(body, page, site) {
      // Body is the content string within the tag
      // Page is the object of the current page being converted
      // Site is the same data structure passed to liquid templates
      // (see generators below)
      return "Hello World";
    }
  }
}
```

### Generators

Generators are used to create additional content for your site based on custom logic.

```js
module.exports = {
  "generators": {
    "bar": function(site, callback) {
      // Same data structure as passed to Liquid templates. Including:
      // - site.posts
      // - site.pages
      // - site.tags
      // - site.categories
      // - site.static_files

      // Make sure to callback when you're done
      callback(null);
    }
  }
}
```

See `src/plugins/enfield-generators.coffee` for examples.

## Changelog

### HEAD

- Use pygments for code highlighting w/ Marked's async API
- Use new async API from tinyliquid 0.2
- Use `he` instead of `ent` for entity encoding
- Various bugfixes

### Version 0.3.0

- Initial support for custom tag plugins
- Support Jekyll-style pagination
- Add support for `post_url` included in Jekyll
- Make nested includes actually work
- Includes can use markdown
- Removed Textile support (need to find a better library)
- Support the `permalink` config property to match Jekyll's permalink paths
- Add `pretty_urls` config variable for `.html`-less URLs everywhere
- Match Jekyll 1.0 command-line interface
- Support timezone config
- Enable smartypants quote handling thanks to Marked
- Misc Jekyll compatibility fixes

### Version 0.2.1

- Make files with DOS line endings work
- Add support for `site.url` and `site.baseurl` properties from command-line
- Support setting post categories via directory structure like Jekyll

### Version 0.2.0

- Change generator and convert plugin APIs to be async
- Compile and minify LESS.css via bundled plugin

### Version 0.1.1

- Add support for generator plugins.
- Compile and minify CoffeeScript via bundled plugin

### Version 0.1.0

- First Release

## TODO

* Consider configurable permalinks
* Post index page for year directories
* Check for permalink collisions due to same slug and different dates

## License

MIT

## This Project Has a Stupid Name

Richard Enfield is a minor character in [The Strange Case of Dr. Jekyll and Mr. Hyde](http://en.wikipedia.org/wiki/Strange_Case_of_Dr_Jekyll_and_Mr_Hyde).
