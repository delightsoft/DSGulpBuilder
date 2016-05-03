path = require 'path'

gutil = require 'gulp-util'
rename = require 'gulp-rename'
(notify = require 'gulp-notify').logger (->)

ForkStream = require 'fork-stream'
through = require 'through2'

class TaskBase

  constructor: ((nameOrTask, @_deps) ->
    if nameOrTask instanceof TaskBase # copy constructor
      @_name = nameOrTask._name
      @_deps = nameOrTask._deps
      @_mixinInit?()
      return
    @_name = nameOrTask
    throw new Error 'Invalid task name (1st argument)' unless typeof @_name == 'string' && @_name != ''
    if (ok = typeof @_deps == 'undefined')
      @_deps = []
    else if (ok = Array.isArray @_deps)
      for dep, i in @_deps
        if !(ok = typeof dep == 'string')
          break unless (ok = dep instanceof TaskBase)
          @_deps[i] = dep._build()
    if !ok
      throw new Error 'Invalid list of dependencies (2nd argument)'
    @_built = false
    @_watch = false
    @_mixinInit?()
    return)

  _mixinInit: null

  _mixinAssert: null

  _isAlreadyBuilt: (->
    throw new Error('Task is already built.  Modification is not allowed') if @_built
    return)

  _build: (-> # it's anstract method with stub code
    throw new Error("Definition of task '#{@_name}' is not completed")
    return)

  _countFiles: ((p, doNotSkipIncludeFiles) ->
    @_filesCnt = 0
    return p.pipe(through.obj((file, enc, cb) =>
      # count found files
      @_filesCnt++
      # skip files with name started with underscore
      cb null, if !doNotSkipIncludeFiles && !@_singleFile && path.basename(file.path).indexOf('_') == 0 then null else file
      return))
    return)

  _onError: ((p, endOrFinish, doNotEmitEvent) ->
    self = @
    delete @_err # clear from previous use
    return p.on 'error', ((err) ->
      args = Array::slice.call arguments
      notify.onError(
        title: "Task '#{self._name}': Error"
        message: '<%= error %>'
      ).apply @, args
      self._err = err
      console.error err.stack
      @emit endOrFinish unless doNotEmitEvent
      return))

  _endPipe: ((p, endOrFinish, cb, ignoreSecondEnd) ->
    endHappend = false
    return p.on endOrFinish, ((err) =>
      if @hasOwnProperty '_filesCnt' && @_filesCnt == 0
        gutil.log gutil.colors.red "Task '#{@_name}': Nothing is found for source '#{@_src}' (#{path.resolve process.cwd(), @_fixedSrc})"
      unless endHappend && ignoreSecondEnd
        cb(if @_err then new gutil.PluginError @_name, @_err else null)
      endHappend = true
      return))

  _setWatch: ((cb, initWatch) ->
    return if @_watch
      cb
    else
      ((err) =>
        initWatch()
        @_watch = true
        cb err
        return))

  # Hack: I collect all watches right on the TaskBase class method
  @addToWatch = ((watch) ->
    [oldWatchTask, @_watchTask] = [@_watchTask, (->
      oldWatchTask?.call @
      watch()
      return)]
    return)

  @destMixin = (->

    [oldMixinInit, @::_mixinInit] = [@::_mixinInit, (->
      oldMixinInit?.call @
      @_dest = null
      return)]

    [oldMixinAssert, @::_mixinAssert] = [@::_mixinAssert, (->
      oldMixinAssert?.call @
      if @_dest == null
        throw new Error "Task '#{@_name}': dest is not specified"
      return)]

    @::dest = ((locations) ->
      @_isAlreadyBuilt()
      throw new Error('Missing argument') if arguments.length == 0
      throw new Error('Too many arguments') if arguments.length > 1
      missingArg() if arguments.length == 0
      tooManyArgs() if arguments.length > 1
      for location in locations
        break unless (ok = typeof location == 'string' && location != '')
      throw new Error 'First argument must be either a string or list of strings' if !ok

      @_dest = if (locations = (if Array.isArray locations then locations else [locations])).length == 1
        ((src) =>
          return src.pipe(GLOBAL.gulp.dest(locations[0])))
      else
        ((src) =>
          endsExpected = locations.length
          resultPipe = src.pipe(GLOBAL.gulp.dest(locations[0]))
          [oldEmit, resultPipe.emit] = [resultPipe.emit,
                                        ((event) ->
                                          if event == 'finish' then onFinish() # intercept 'finish'
                                          else oldEmit.apply resultPipe, arguments
                                          return)]
          onFinish = (-> # consolidates all 'finish' events for all destinations
            oldEmit.call resultPipe, 'finish' if --endsExpected == 0
            return)
          for location in locations[1..]
            src.pipe(through.obj((file, enc, cb) -> # clone file
              cb null, file.clone()
              return))
            .pipe(GLOBAL.gulp.dest(location)) # save file
            .on 'finish', onFinish
          return resultPipe)

      @_destFirstLocation = locations[0]

      return @)

    @::rename = ((opts) ->
      throw new Error('Missing argument') if arguments.length == 0
      throw new Error('Too many arguments') if arguments.length > 1
      @_isAlreadyBuilt()
      makeStep = ((opts) =>
        (@_dest ?= []).push func = ((p) =>
          return p.pipe(rename(opts)))
        [func.type, func.opts] = ['rename', opts]
        return)
      if (ok = typeof opts == 'string')
        makeStep(opts)
      else if (ok = typeof opts == 'object')
        makeStep(res = {})
        for k, v of opts
          switch k
            when 'path' then res.dirname = v
            when 'name' then res.basename = v
            when 'ext' then res.extname = v
            else throw new Error "Unsupported option: #{k}"
          if not typeof v == 'String'
            throw new Error "Option '#{k}': must be a string"
      throw new Error 'Frist argument must be either a string or options (name, ext, path)' if !ok
      return @)

    return)

# ----------------------------

prettyPrint = require './prettyPrint'

_argError = (reason, name, value) ->  new Error "#{reason} '#{name}': #{prettyPrint value}" # _argError =

TaskBase.invalidArg = (name, value) -> throw _argError 'Invalid argument', name, value; return

TaskBase.invalidValue = (name, value) -> throw _argError 'Invalid value of argument', name, value; return

TaskBase.tooManyArgs = tooManyArgs = (->
  throw new Error 'Too many arguments'
  return)

TaskBase.missingArg = missingArg = (->
  throw new Error 'Missing argument'
  return)

TaskBase.unsupportedOption = unsupportedOption = ((optName) ->
  throw new Error "Unsupported option: #{optName}"
  return)

TaskBase.invalidOptionType = invalidOptionType = ((optName, type) ->
  throw new Error "Option '#{optName}': must be a #{type}"
  return)

TaskBase.preprocessPath = require './preprocessPath'

TaskBase.prettyPrint = prettyPrint

# ----------------------------

module.exports = TaskBase
