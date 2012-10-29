# Enfield

Jekyll-like static site generator for node.js.

## Plugins

Enfield will load any `.coffee` or `.js` file from the `_plugins` directory. The plugin system is modeled after [Jekyll Plugins](https://github.com/mojombo/jekyll/wiki/Plugins). However, only a few plugin types are supported:

* Converters
* Liquid Filters

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

## TODO

* Support some form of post pagination
* Base URL / real permalinks
* Post index page for year directories
* Proper include support (nesting)
* Process coffee / less?

## This Project Has a Stupid Name

Richard Enfield is a minor character in [The Strange Case of Dr. Jekyll and Mr. Hyde](http://en.wikipedia.org/wiki/Strange_Case_of_Dr_Jekyll_and_Mr_Hyde).
