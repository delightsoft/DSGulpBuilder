path = require 'path'
gutil = require 'gulp-util'
jasmine = require 'gulp-jasmine'
through = require 'through2'
changed = require 'gulp-changed'

preprocessPath = require '../common/preprocessPath'

{TaskBase, tooManyArgs, missingArg, unsupportedOption, invalidOptionType} = require '../common/TaskBase'

module.exports =

  class Jasmine extends TaskBase

    constructor: ((task, @_src, opts) ->
      missingArg() if arguments.length == 1
      tooManyArgs() if arguments.length > 3
      TaskBase.call @, task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      @_opts = opts
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, '/**/*.*'
      return)

    # If you want tests run be theirself (not as dependency), use this method to specify sources that are tested
    watch: ((path) ->
      invalidOptionType('dest', 'string') unless typeof path == 'string' && path.trim() != ''
      @_watchSrc = path
      return @)

    _build: (->
      return @_name if @_built

      @_mixinAssert?()

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch @_fixedSrc, [@_name]
        if @_watchSrc
          GLOBAL.gulp.watch @_watchSrc, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, ((cb) =>

        p = GLOBAL.gulp.src @_fixedSrc # Note: _src is used intentionally
        p = @_countFiles p
        p = p.pipe(jasmine(@_opts))

#        logAllEmitterEvents = ((eventEmitter) ->
#          emitToLog = eventEmitter.emit
#          eventEmitter.emit = (->
#            event = arguments[0];
#            console.log("event emitted: " + event);
#            emitToLog.apply(eventEmitter, arguments)
#            return)
#          return)
#
#        logAllEmitterEvents p

        p = @_onError p, 'end', true
        p = @_endPipe p, 'end', cb, true # TODO: This works only with fixed gulp-jasmine - https://github.com/Zork33/gulp-jasmine.git

        return false)

      @_built = true
      return @_name)