# heroku-buildpack-cachesave

Copy files to cache. Paths are read from `.buildcache` file in your project source code.

You should use this, if your project is pulling a lot of dependencies during each build. If you store them into cache and during build you just check if they haven't changed, your build time will reduce dramatically.

## Usage example

`$ heroku config:add BUILDPACK_URL=https://github.com/ddollar/heroku-buildpack-multi.git`

`.buildpacks`:

```
https://github.com/heroku/heroku-buildpack-nodejs
https://github.com/zakjan/heroku-buildpack-cacheload#1.0.1
https://github.com/kr/heroku-buildpack-inline
https://github.com/zakjan/heroku-buildpack-cachesave#1.0.1
```

`.buildcache`:

```
code/server/node_modules
code/client/node_modules
code/client/bower_components
```

## The `.buildcache` file

The `.buildcache` file behaves much like a `.gitignore`: every line is a pattern
describing what to copy into the cache. It supports:

- **Direct file paths** – `config/settings.json` (copied as-is)
- **Folders** – `code/server/node_modules` (the whole folder is copied in one
  operation, without looping over individual files, so caching stays fast even
  for very large trees)
- **Home directory paths** – prefix with `~/` to cache files from the home folder (e.g. `~/.npm`)
- **Comments** – lines starting with `#` are ignored, as are blank lines
- **Exclusions** – prefix a pattern with `!` to remove previously matched
  files or folders from the cache. Only exclusion patterns support globbing:
  `*` matches anything except a slash, `**` matches recursively across
  directories, and `?`/`[]` work as in the shell.

Additive entries (lines without a leading `!`) are always treated as **literal
file or folder paths** – globs in additive entries are *not* expanded. Globbing
is reserved for exclusions, which keeps adding files to the cache fast by
avoiding per-file looping.

Patterns are evaluated top to bottom, so an exclusion only affects the entries
matched by the lines above it.

The cache is rebuilt from scratch on every build: the previous `buildcache`
contents are cleared before the patterns are processed. This prevents files
that are no longer matched (because they were removed from the source or from
the `.buildcache` file) from lingering in the cache and growing the slug over
time.

Example:

```
# cache the node_modules folders...
code/server/node_modules
code/client/node_modules
# ...but not the build cache inside them
!**/node_modules/.cache

logs
!logs/*.debug.log
```

## Troubleshooting

**How to clear the cache?**

Use `heroku-repo` plugin.

```
$ heroku plugins:install https://github.com/heroku/heroku-repo.git
$ heroku repo:purge_cache -a appname
```
