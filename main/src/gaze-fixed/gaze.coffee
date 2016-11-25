###
# gaze
# https://github.com/shama/gaze
#
# Copyright (c) 2013 Kyle Robinson Young
# Licensed under the MIT license.
###

# `Gaze` EventEmitter object to return in the callback

Gaze = (patterns, opts, done) ->
  self = this
  EE.call self
  # If second arg is the callback
  if `typeof opts == 'function'`
    done = opts
    opts = {}
  # Default options
  opts = opts or {}
  opts.mark = true
  opts.interval = opts.interval or 100
  opts.debounceDelay = opts.debounceDelay or 500
  opts.cwd = opts.cwd or process.cwd()
  @options = opts
  # Default done callback
  done = done or ->
# Remember our watched dir:files
  @_watched = Object.create(null)
  # Store watchers
  @_watchers = Object.create(null)
  # Store watchFile listeners
  @_pollers = Object.create(null)
  # Store patterns
  @_patterns = []
  # Cached events for debouncing
  @_cached = Object.create(null)
  # Set maxListeners
  if @options.maxListeners
    @setMaxListeners @options.maxListeners
    Gaze.super_::setMaxListeners @options.maxListeners
    delete @options.maxListeners
  # Initialize the watch on files
  if patterns
    @add patterns, done
  # keep the process alive
  @_keepalive = setInterval((->
  ), 200)
  this

# libs
util = require('util')
EE = require('events').EventEmitter
fs = require('fs')
path = require('path')
globule = require('globule')
helper = require('./helper')
# shim setImmediate for node v0.8
setImmediate = require('timers').setImmediate
if `typeof setImmediate != 'function'`
  setImmediate = process.nextTick
# globals
delay = 10
util.inherits Gaze, EE
# Main entry point. Start watching and call done when setup
module.exports = (`function gaze(patterns, opts, done) {
    return new Gaze(patterns, opts, done);
}`)
module.exports.Gaze = Gaze
# Override the emit function to emit `all` events
# and debounce on duplicate events per file

Gaze::emit = ->
  self = this
  args = arguments
  e = args[0]
  filepath = args[1]
  timeoutId = undefined
  # If not added/deleted/changed/renamed then just emit the event
  if `e.slice(-2) != 'ed'`
    Gaze.super_::emit.apply self, args
    return this
  # Detect rename event, if added and previous deleted is in the cache
  if `e == 'added'`
    Object.keys(@_cached).forEach (oldFile) ->
      if `self._cached[oldFile].indexOf('deleted') != -1`
        args[0] = e = 'renamed'
        [].push.call args, oldFile
        delete self._cached[oldFile]
        return false
      return
  # If cached doesnt exist, create a delay before running the next
  # then emit the event
  cache = @_cached[filepath] or []
  if `cache.indexOf(e) == -1`
    helper.objectPush self._cached, filepath, e
    clearTimeout timeoutId
    timeoutId = setTimeout((->
      delete self._cached[filepath]
      return
    ), @options.debounceDelay)
    # Emit the event and `all` event
    Gaze.super_::emit.apply self, args
    Gaze.super_::emit.apply self, [
      'all'
      e
    ].concat([].slice.call(args, 1))
  # Detect if new folder added to trigger for matching files within folder
  if `e == 'added'`
    if helper.isDir(filepath)
      fs.readdirSync(filepath).map((file) ->
        path.join filepath, file
      ).filter((file) ->
        globule.isMatch self._patterns, file, self.options
      ).forEach (file) ->
        self.emit 'added', file
        return
  this

# Close watchers

Gaze::close = (_reset) ->
  self = this
  _reset = if `_reset == false` then false else true
  Object.keys(self._watchers).forEach (file) ->
    self._watchers[file].close()
    return
  self._watchers = Object.create(null)
  Object.keys(@_watched).forEach (dir) ->
    self._unpollDir dir
    return
  if _reset
    self._watched = Object.create(null)
    setTimeout (->
      self.emit 'end'
      self.removeAllListeners()
      clearInterval self._keepalive
      return
    ), delay + 100
  self

# Add file patterns to be watched

Gaze::add = (files, done) ->
  if `typeof files == 'string'`
    files = [ files ]
  @_patterns = helper.unique.apply(null, [
    @_patterns
    files
  ])
  files = globule.find(@_patterns, @options)
  @_addToWatched files
  @close false
  @_initWatched done
  return

# Dont increment patterns and dont call done if nothing added

Gaze::_internalAdd = (file, done) ->
  files = []
  if helper.isDir(file)
    files = [ helper.markDir(file) ].concat(globule.find(@_patterns, @options))
  else
    console.info 'file:', file
    console.info '@_patterns:', @_patterns
    if globule.isMatch(@_patterns, file, @options)
      console.info 'match'
      files = [ file ]
  if files.length > 0
    @_addToWatched files
    @close false
    @_initWatched done
  return

# Remove file/dir from `watched`

Gaze::remove = (file) ->
  self = this
  if @_watched[file]
# is dir, remove all files
    @_unpollDir file
    delete @_watched[file]
  else
# is a file, find and remove
    Object.keys(@_watched).forEach (dir) ->
      index = self._watched[dir].indexOf(file)
      if `index != -1`
        self._unpollFile file
        self._watched[dir].splice index, 1
        return false
      return
  if @_watchers[file]
    @_watchers[file].close()
  this

# Return watched files

Gaze::watched = ->
  @_watched

# Returns `watched` files with relative paths to process.cwd()

Gaze::relative = (dir, unixify) ->
  self = this
  relative = Object.create(null)
  relDir = undefined
  relFile = undefined
  unixRelDir = undefined
  cwd = @options.cwd or process.cwd()
  if `dir == ''`
    dir = '.'
  dir = helper.markDir(dir)
  unixify = unixify or false
  Object.keys(@_watched).forEach (dir) ->
    relDir = path.relative(cwd, dir) + path.sep
    if `relDir == path.sep`
      relDir = '.'
    unixRelDir = if unixify then helper.unixifyPathSep(relDir) else relDir
    relative[unixRelDir] = self._watched[dir].map((file) ->
      relFile = path.relative(path.join(cwd, relDir) or '', file or '')
      if helper.isDir(file)
        relFile = helper.markDir(relFile)
      if unixify
        relFile = helper.unixifyPathSep(relFile)
      relFile
    )
    return
  if dir and unixify
    dir = helper.unixifyPathSep(dir)
  if dir then relative[dir] or [] else relative

# Adds files and dirs to watched

Gaze::_addToWatched = (files) ->
  i = 0
  while i < files.length
    file = files[i]
    filepath = path.resolve(@options.cwd, file)
    dirname = if helper.isDir(file) then filepath else path.dirname(filepath)
    dirname = helper.markDir(dirname)
    # If a new dir is added
    if helper.isDir(file) and !(filepath of @_watched)
      helper.objectPush @_watched, filepath, []
    if `file.slice(-1) == '/'`
      filepath += path.sep
    helper.objectPush @_watched, path.dirname(filepath) + path.sep, filepath
    # add folders into the mix
    readdir = fs.readdirSync(dirname)
    j = 0
    while j < readdir.length
      dirfile = path.join(dirname, readdir[j])
      if fs.lstatSync(dirfile).isDirectory()
        helper.objectPush @_watched, dirname, dirfile + path.sep
      j++
    i++
  this

Gaze::_watchDir = (dir, done) ->
  self = this
  timeoutId = undefined
  try
    @_watchers[dir] = fs.watch(dir, (event) ->
# race condition. Let's give the fs a little time to settle down. so we
# don't fire events on non existent files.
      clearTimeout timeoutId
      timeoutId = setTimeout((->
# race condition. Ensure that this directory is still being watched
# before continuing.
        if dir of self._watchers and fs.existsSync(dir)
          done null, dir
        return
      ), delay + 100)
      return
    )
  catch err
    return @_handleError(err)
  this

Gaze::_unpollFile = (file) ->
  if @_pollers[file]
    fs.unwatchFile file, @_pollers[file]
    delete @_pollers[file]
  this

Gaze::_unpollDir = (dir) ->
  @_unpollFile dir
  i = 0
  while i < @_watched[dir].length
    @_unpollFile @_watched[dir][i]
    i++
  return

Gaze::_pollFile = (file, done) ->
  opts =
    persistent: true
    interval: @options.interval
  if !@_pollers[file]

    @_pollers[file] = (curr, prev) ->
      done null, file
      return

    try
      fs.watchFile file, opts, @_pollers[file]
    catch err
      return @_handleError(err)
  this

# Initialize the actual watch on `watched` files

Gaze::_initWatched = (done) ->
  self = this
  cwd = @options.cwd or process.cwd()
  curWatched = Object.keys(self._watched)
  # if no matching files
  if curWatched.length < 1
# Defer to emitting to give a chance to attach event handlers.
    setImmediate ->
      self.emit 'ready', self
      if done
        done.call self, null, self
      self.emit 'nomatch'
      return
    return
  helper.forEachSeries curWatched, ((dir, next) ->
    dir = dir or ''
    files = self._watched[dir]
    # Triggered when a watched dir has an event
    self._watchDir dir, (event, dirpath) ->
      relDir = if `cwd == dir` then '.' else path.relative(cwd, dir)
      relDir = relDir or ''
      fs.readdir dirpath, (err, current) ->
        if err
          return self.emit('error', err)
        if !current
          return
        try
# append path.sep to directories so they match previous.
          current = current.map((curPath) ->
            if fs.existsSync(path.join(dir, curPath)) and fs.lstatSync(path.join(dir, curPath)).isDirectory()
              curPath + path.sep
            else
              curPath
          )
        catch err
# race condition-- sometimes the file no longer exists
# Get watched files for this dir
        previous = self.relative(relDir)
        # If file was deleted
        previous.filter((file) ->
          current.indexOf(file) < 0
        ).forEach (file) ->
          if !helper.isDir(file)
            filepath = path.join(dir, file)
            self.remove filepath
            self.emit 'deleted', filepath
          return
        # If file was added
        current.filter((file) ->
          previous.indexOf(file) < 0
        ).forEach (file) ->
          console.info 'file:', file
# Is it a matching pattern?
          relFile = path.join(relDir, file)
          # Add to watch then emit event
          self._internalAdd relFile, ->
            self.emit 'added', path.join(dir, file)
            return
          return
        return
      return
    # Watch for change/rename events on files
    files.forEach (file) ->
      if helper.isDir(file)
        return
      self._pollFile file, (err, filepath) ->
# Only emit changed if the file still exists
# Prevents changed/deleted duplicate events
        if fs.existsSync(filepath)
          self.emit 'changed', filepath
        return
      return
    next()
    return
  ), ->
# Return this instance of Gaze
# delay before ready solves a lot of issues
    setTimeout (->
      self.emit 'ready', self
      if done
        done.call self, null, self
      return
    ), delay + 100
    return
  return

# If an error, handle it here

Gaze::_handleError = (err) ->
  if `err.code == 'EMFILE'`
    return @emit('error', new Error('EMFILE: Too many opened files.'))
  @emit 'error', err
