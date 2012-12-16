# Enfield

Jekyll-like static site generator for node.js.

## Usage

Generated directly from `enfield --help`

```
Enfield is a static-site generator modeled after Jekyll

Usage:
  enfield                          # Generate . -> ./_site
  enfield [destination]            # Generate . -> <path>
  enfield [source] [destination]   # Generate <path> -> <path>

  enfield init [directory]         # Build default directory structure
  enfield page [title]             # Create a new post with today's date
  enfield post [title]             # Create a new page

Options:
  --auto           Auto-regenerate
  --server [PORT]  Start a web server (default port 4000)
  --url [URL]      Set custom site.url
```

## Plugins

Enfield will load any `.coffee` or `.js` file from the `_plugins` directory. The plugin system is modeled after [Jekyll Plugins](https://github.com/mojombo/jekyll/wiki/Plugins). However, only a few plugin types are supported:

* Converters
* Liquid Filters
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
      "convert": function(content) {
        return content.replace('foo', '');
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

## Generators

Generators are used to create additional content for your site based on custom logic.

```js
module.exports = {
  "generators": {
    "bar": function(site) {
      // Have at it ...
    }
  }
}
```

See `src/plugins/enfield-generators.coffee` for examples.

## TODO

* Check for permalink collisions due to same slug and different dates
* Support some form of post pagination
* site_url option
* Consider configurable permalinks
* Post index page for year directories
* Proper include support (nesting)
* Process LESS

## This Project Has a Stupid Name

Richard Enfield is a minor character in [The Strange Case of Dr. Jekyll and Mr. Hyde](http://en.wikipedia.org/wiki/Strange_Case_of_Dr_Jekyll_and_Mr_Hyde).
