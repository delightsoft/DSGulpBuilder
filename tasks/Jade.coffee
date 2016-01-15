path = require 'path'
gutil = require 'gulp-util'
browserify = require 'browserify'
watchify = require 'watchify'
uglify = require 'gulp-uglify'
source = require 'vinyl-source-stream2'
rename = require 'gulp-rename'
jade = require 'gulp-jade'
through = require 'through2'
changed = require 'gulp-changed'

minimatch = require 'minimatch'
ternaryStream = require 'ternary-stream'

preprocessPath = require '../common/preprocessPath'

{TaskBase, tooManyArgs, missingArg, unsupportedOption, invalidOptionType} = require '../common/TaskBase'

module.exports =

  class Jade extends TaskBase

    constructor: ((task, @_src) ->
      missingArg() if arguments.length == 1
      tooManyArgs() if arguments.length > 2
      TaskBase.call @, task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, "**/*.+(jade|html)"
      return)

    @destMixin()

    _build: (->
      return @_name if @_built

      @_mixinAssert?()

      TaskBase.addToWatch (=>
        GLOBAL.gulp.watch @_fixedSrc, [@_name]
        return)

      GLOBAL.gulp.task @_name, @_deps, ((cb) =>

        p = GLOBAL.gulp.src @_fixedSrc
        p = @_countFiles p
        p = p.pipe(ternaryStream(((file) ->
              minimatch(file.relative, '**/*.+(jade|html)')),
            jade({locals: {dev: gutil.env.dev, min: if gutil.env.dev then '' else '.min'}})))
        p = @_onError p, 'finish'
        p = p.pipe(changed(@_destFirstLocation))
        p = @_endPipe p, 'finish', cb

        return false)

      @_built = true
      return @_name)