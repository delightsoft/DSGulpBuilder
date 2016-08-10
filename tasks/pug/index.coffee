path = require 'path'
gutil = require 'gulp-util'
pug = require 'pug'
through = require 'through2'
changed = require 'gulp-changed'
minimatch = require 'minimatch'
ternaryStream = require 'ternary-stream'
ext = require('gulp-util').replaceExtension

module.exports = (DSGulpBuilder) ->

  {invalidArg, tooManyArgs, missingArg, unsupportedOption, invalidOptionType, preprocessPath} = TaskBase = DSGulpBuilder.TaskBase

  class Pug extends TaskBase

    constructor: (task, @_src, opts) ->

      console.error gutil.colors.red 'DO NOT use Pug at the moment.  It\'s in process of active renovation.  And does not backward compatibility with Jade.  See https://github.com/pugjs/pug/issues/2302'

      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 3
      super task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, "**/*.+(pug|jade|html)"
      if arguments.length > 2
        if (ok = typeof opts == 'object')
          for k, v of opts
            switch k
              when 'locals'
                invalidOptionType k, 'object' unless typeof v == 'object' && v != null
                @_locals = v
              else unsupportedOption k
        throw new Error 'Invalid options (2nd argument)' unless ok
      return

    @destMixin()

    duplicate: (dupMap) ->
      missingArg() if arguments.length < 1
      tooManyArgs() if arguments.length > 1
      throw new Error 'duplicate() 1: Invalid argument dupMap' unless typeof dupMap == 'object' && dupMap != null
      for origFilename, toFilename of dupMap
        if typeof toFilename == 'string'
          dupMap[origFilename] = [toFilename]
        else
          throw new Error 'duplicate() 2: Invalid argument dupMap' unless Array.isArray toFilename
          for v in toFilename when not typeof v == 'string'
            throw new Error 'duplicate() 3: Invalid argument dupMap'
      @_dupMap = dupMap
      @

    _build: ->
      return @_name if @_built

      @_mixinAssert?()

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch @_fixedSrc, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, ((cb) =>

        locals =
          dev: !!gutil.env.dev
          min: if gutil.env.dev then '' else '.min'

        if @_locals then locals[k] = v for k, v in @_locals

        pugStep = through.obj (file, enc, cb) =>
          locals.filename = file.path
          file.contents = new Buffer out = pug.render String(file.contents), locals
          file.path = ext file.path, '.html'
          cb null, file
          return # pugStep =

        p = GLOBAL.gulp.src @_fixedSrc
        p = @_countFiles p
        p = p.pipe(ternaryStream(((file) ->
              minimatch(file.relative, '**/*.+(pug|jade)')),
              pugStep))
        p = @_onError p, 'finish'

        if (dupMap = @_dupMap)
          p = p.pipe through.obj (file, enc, cb) ->
            if dupMap.hasOwnProperty file.relative
              for toFile in dupMap[file.relative]
                clone = file.clone()
                clone.path = path.join file.base, toFile
                @push clone
            cb null, file
            return

        p = p.pipe changed @_destFirstLocation, hasChanged: changed.compareSha1Digest
        p = @_dest(p)
        p = @_endPipe p, 'finish', cb

        return false)

      @_built = true
      return @_name # _build:

# ----------------------------

  DSGulpBuilder.Task::pug = ->
    newInstance = Object.create(Pug::)
    args = [@]
    args.push arg for arg in arguments
    Pug.apply newInstance, args
    return newInstance

  return    