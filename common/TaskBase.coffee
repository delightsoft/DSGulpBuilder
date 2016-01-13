gutil = require 'gulp-util'
rename = require 'gulp-rename'
notify = require 'gulp-notify'

ForkStream = require 'fork-stream'
through = require 'through2'

module.exports =

  handleErrors: (->
    args = Array::slice.call arguments
    notify.onError(
      title: 'Compile Error'
      message: '<%= error %>'
    ).apply this, args
    @emit 'end'
    return)

  tooManyArgs: tooManyArgs = (->
    throw new Error 'Too many arguments'
    return)

  missingArg: missingArg = (->
    throw new Error 'Missing argument'
    return)

  unsupportedOption: unsupportedOption = ((optName) ->
    throw new Error "Unsupported option: #{optName}"
    return)

  invalidOptionType: invalidOptionType = ((optName, type) ->
    throw new Error "Option '#{optName}': must be a #{type}"
    return)

  TaskBase: class TaskBase

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
        console.info '@_deps: ', @_deps
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

    _setWatch: ((callback, initWatch) ->
      if @_watch
        newCallback = callback
      else
        newCallback = ((err) =>
          initWatch()
          @_watch = true
          callback(err)
          return)
      # Zork: In some cases we receive duplicated 'end' event.  This is a protection from such cases
      return do (invoked = false) =>
        ((err) =>
          if invoked
            gutil.log gutil.colors.red "Task '#{@_name}': Duplicated 'end' event had to happen"
          else
            invoked = true
            newCallback err
          return))

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
            resultPipe = src.pipe(through.obj((file, enc, cb) -> # clone file
              cb null, file.clone()
              return))
            .on 'end', (onEnd = (-> # count 'end' events on duplicated pipes
              if --endsExpected == 0 then outStream.emit 'end'
              return))
            .pipe(outStream = GLOBAL.gulp.dest(locations[0]), end: false) # suppress 'end' event
            for location in locations[1..]
              src.pipe(through.obj((file, enc, cb) -> # clone file
                cb null, file.clone()
                return))
              .pipe(GLOBAL.gulp.dest(location)) # save file
              .on 'end', onEnd
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
