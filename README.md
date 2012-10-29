# Enfield

## Plugins

Enfield will load any `.coffee` or `.js` file from the `_plugins` directory. The plugin system is modeled after [Jekyll Plugins](https://github.com/mojombo/jekyll/wiki/Plugins). However, only a few plugin types are supported:

* Converters
* Liquid Filters

### Converters

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

* Base URL / real permalinks
* Post index page for year directories
* Plugin support
* Process coffee / less?
* Proper include support (nesting)
* Support Jekyll liquid extensions: https://github.com/mojombo/jekyll/wiki/Liquid-Extensions

## This Project Has a Stupid Name

richard Enfield is a minor character in [The Strange Case of Dr. Jekyll and Mr. Hyde](http://en.wikipedia.org/wiki/Strange_Case_of_Dr_Jekyll_and_Mr_Hyde).
