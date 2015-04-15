## Enfield Changelog

### HEAD

- Nothing yet.

### Version 0.4.0

- Use [highlight.js](http://highlightjs.org/) if `pygments` is set to `false`
- New `config` parameter for `converter.convert` API
- Add support for the `date_to_rfc822` filter present in Jekyll
- Created tests and set up automated build testing with Travis: [https://travis-ci.org/fortes/enfield](https://travis-ci.org/fortes/enfield)
- Use promises via the [Q](https://github.com/kriskowal/q) library instead of callbacks
- Various bugfixes

### Version 0.3.1

- New liquid tag `{% page_url %}` for linking to posts (similar to `{% post_url %}` from Jekyll)
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
