path = require 'path'
fs = require 'fs'
gutil = require 'gulp-util'
through = require 'through2'
changed = require 'gulp-changed'
minimatch = require 'minimatch'
Module = require 'module'

JasmineRunner = require 'jasmine'
JasmineReporter = require 'jasmine-terminal-reporter'

{getDataURI, fixSourceMapContent, addSourceComments} = require './coverage'

deleteRequireCache = (id) ->

  if !id or id.indexOf('node_modules') != -1
    return

  files = require.cache[id]

  if files != undefined
    Object.keys(files.children).forEach (file) ->
      deleteRequireCache files.children[file].id
      return

    delete require.cache[id]

  return
  
optionalRequired = (npmNames) ->
  missing = []
  res = (for npm in npmNames
    try
      require(npm)
    catch err
      if err.message.indexOf('Cannot find module') >= 0
        missing.push npm
        null
      else
        throw err)
  res.push missing if missing.length > 0
  res # optionalRequired =

parsePath = (val) ->
  extname = path.extname(val)
  return {
    dirname: path.dirname(val)
    basename: path.basename(val, extname)
    extname: extname}

replaceExtension = (path) ->
  path = path.replace(/\\.coffee\\.md$/, '.litcoffee')
  gutil.replaceExtension(path, '.js')

module.exports = (DSGulpBuilder) ->

  {invalidArg, tooManyArgs, missingArg, unsupportedOption, invalidOptionType, preprocessPath} = TaskBase = DSGulpBuilder.TaskBase

  class Jasmine extends TaskBase

    constructor: (task, @_src, opts) ->
      missingArg() if arguments.length < 2
      tooManyArgs() if arguments.length > 3
      super task
      throw new Error 'Invalid source file or directory name (1st argument)' unless typeof @_src == 'string' && @_src != ''
      @_filter = null
      @_coverage = true
      @_debug = false
      for k, v of opts
        switch k
          when 'filter'
            invalidOptionType('filter', 'regexp') unless typeof v == 'object' && v != null && 'test' of v
            @_filter = v
            delete opts.filter
          when 'coverage'
            invalidOptionType('coverage', 'boolean') unless typeof v == 'boolean'
            @_coverage = v
            delete opts.coverage
          when 'debug'
            invalidOptionType('debug', 'boolean') unless typeof v == 'boolean'
            @_debug = v
            delete opts.debug
      @_name += '-and-coverage' if @_coverage
      @_name += '-with-filter' if @_filter
      @_opts = opts
      @_prevExt = {}

      @_coverageCach = {}
      @_taskVer = 0
      {path: @_fixedSrc, single: @_singleFile} = preprocessPath @_src, '/**/*.+(coffee|litcoffee|coffee.md|js)'

    # If you want tests run be theirself (not as dependency), use this method to specify sources that are tested
    watch: ((path) ->
      invalidOptionType('dest', 'string or list of strings') unless Array.isArray(path) || (typeof path == 'string' && path.trim() != '')
      if typeof path == 'string'
        path = path.substr 2 if path.startsWith './' # ensure, what gulp.watch will see new added files
      else
        for p, i in path when p.startsWith './' # ensure, what gulp.watch will see new added files
          path[i] = p.substr 2
      @_watchSrc = path

      return @)

    _build: ->
      return @_name if @_built

      throw new Error "Task '#{@_name}': .watch() is not specified" unless @_watchSrc
      @_mixinAssert?()

      TaskBase.addToWatch =>
        GLOBAL.gulp.watch [@_fixedSrc, @_watchSrc], (ev) =>
          @_taskVer++
          delete @_coverageCach[ev.path]
          GLOBAL.gulp.start [@_name]
#          switch ev.type
#            when 'added', 'changed'
#              if @_modified == null
#                @_modified = undefined
#                console.info 'ev:', ev
#                stat = fs.lstat ev.path, (err, stats) =>
#                  console.info 'stats: ', stats
#                  @_modified = stats.mtime
#                  console.info 'here'
#                  GLOBAL.gulp.start [@_name]
#                  return
#            when 'deleted'
#              @_deleted[ev.path] = true
#              GLOBAL.gulp.start [@_name] # TODO: ???
          return
        return # _build:

      GLOBAL.gulp.task @_name, @_deps, task = (cb) =>
        currTaskVer = @_taskVer
        if @_coverage
          [@istanbul, missing] = optionalRequired ['istanbul']
          @sourceMap = require 'source-map' # it's installed with istanbul
          if missing
            console.error gutil.colors.red "Task '#{@_name}': Either set opt.coverage to 'false' or install following module:"
            console.error gutil.colors.yellow "npm install #{missing.join ' '} --save-dev"
          else
            console.time (timerName = "Task '#{@_name}': Run specs and coverage") if @_debug
            @_coveredSources = path.join (cwd = process.cwd()), "./generated/#{@_name}" # TODO: make path optional
            [oldCb, cb] = [cb, => @_coverCleanUp(oldCb); return]
            @_setUpCoverage (err) =>
              (cb err; return) if err
              @_runSpecs (err) =>
                (cb err; return) if err
                console.timeEnd timerName if @_debug
                console.time (timerName = "Task '#{@_name}': Write coverage report") if @_debug
                @_generateCoverageReport (err) =>
                  (cb err; return) if err
                  if @_debug
                    console.timeEnd timerName
                    console.info "Task '#{@_name}': Processed #{@_filesCnt} files"
                  if currTaskVer is not @_taskver then setTimeout (-> task cb), 0 # do it again
                  else cb()
          return

        console.time (timerName = "Task '#{@_name}': Run specs") if @_debug
        @_runSpecs (err) =>
          (cb err; return) if err
          if @_debug
            console.timeEnd timerName
            console.info "Task '#{@_name}': Processed #{@_filesCnt} files"
          if currTaskVer is not @_taskver then setTimeout (-> task cb), 0 # do it again
          else cb()

      @_built = true
      return @_name # _build:

    _setExtention: (ext, process) ->
      @_prevExt[ext] = prevProcessing = Module._extensions[ext]
      Module._extensions[ext] = (module, filename) =>
        unless process(module, filename)
          prevProcessing(module, filename)
      return

    _coverCleanUp: (cb) ->
      delete GLOBAL.__COVERAGE__
      for ext, process of @_prevExt
        if process
          Module._extensions[ext] = process
        else
          delete Module._extensions[ext]
        delete @_prevExt[ext]
      @resolve()
      cb()

    _setUpCoverage: (cb) ->

      @resolve = TaskBase.onCoverageDone =>

        unless @instrumenter
          @sourceStore = @istanbul.Store.create('memory')
          @sourceStore.dispose()
          @instrumenter = new (@istanbul.Instrumenter) preserveComments: true, coverageVariable: '__COVERAGE__'

        cwd = process.cwd()

        coveredSrc = (for src in (if Array.isArray @_watchSrc then @_watchSrc else [@_watchSrc])
          new (minimatch.Minimatch) path.join cwd, src)

        instrumentJS = (src, srcMap, filename) =>
          @sourceStore.set filename, s = addSourceComments(src, srcMap, filename, @sourceMap)
          @instrumenter.instrumentSync(src, filename)

        processCoffee = (module, filename) =>

          found = false
          (found = true; break) for matcher in coveredSrc when matcher.match filename
          return false unless found

          if @_coverageCach.hasOwnProperty filename
            module._compile @_coverageCach[filename], filename
            return true

          src = fs.readFileSync(filename, encoding: 'utf8')

          isLiterateCoffee = /\\.(litcoffee|coffee\\.md)$/.test filename
          try
            tmp = require('coffee-script').compile src,
              bare: false
              header: false
              sourceMap: true
              sourceRoot: false
              literate: isLiterateCoffee
              filename: filename
              sourceFiles: [filename]
              generatedFile: replaceExtension(filename)
            srcMap = if tmp.v3SourceMap then fixSourceMapContent(tmp.v3SourceMap, src) else 1
            src = tmp.js + '\n//# sourceMappingURL=' + getDataURI(JSON.stringify(srcMap))
            src = @_coverageCach[filename] = instrumentJS.call @, src, srcMap, filename
            module._compile src, filename
          catch err
            throw new Error "Error when transform coffee #{filename}: #{err.toString()}"
          return true

        @_setExtention '.coffee', processCoffee
        @_setExtention '.litcoffee', processCoffee
        @_setExtention '.coffee.md', processCoffee

        processJS = (module, filename) =>

          found = false
          (found = true; break) for matcher in coveredSrc when matcher.match filename
          return false unless found

          if @_coverageCach.hasOwnProperty filename
            module._compile @_coverageCach[filename], filename
            return true

          src = fs.readFileSync(filename, encoding: 'utf8')

          try
            src = @_coverageCach[filename] = instrumentJS.call @, src, srcMap, filename
            module._compile src, filename
          catch err
            throw new Error "Error when transform coffee #{filename}: #{err.toString()}"
          return true

        @_setExtention '.js', processJS

        cb()

        return # @resolve = TaskBase.onCoverageDone =>

    _generateCoverageReport: (cb) ->

      collector = new (@istanbul.Collector)
      collector.add GLOBAL.__COVERAGE__
      finalSummary = @istanbul.utils.mergeSummaryObjects.apply(null, collector.files().map((F) =>
        @istanbul.utils.summarizeFileCoverage collector.fileCoverageFor(F)
      ))
      ['text-summary', 'json', 'lcov'].forEach (R) =>
        @istanbul.Report.create(R,
          sourceStore: @sourceStore
          dir: (path.join process.cwd(), './coverage')).writeReport collector, true # TODO: Hardcoded folder
        return
      cb()
      return # _generateCoverageReport:

    _runSpecs: (taskCallback) ->

      src = path.join process.cwd(), @_fixedSrc

      p = GLOBAL.gulp.src src, read: false
      
      if @_filter
        p = p.pipe through.obj (file, enc, cb) =>
          if /_globals[_\.]/g.test(file.path) || @_filter.test(file.path.replace /\\/g, '/')
            console.info 'file.path:', file.path
            cb null, file
          else
            cb()
          return

      p = @_countFiles p

#      if @_modified
#        p = p.pipe through.obj do (modified = @_modified) -> (file, enc, cb) ->
#          if file.stat.mtime >= modified
#            cb null, file
#          else
#            cb()
#          return
#        @_modified = null

      jasmine = new JasmineRunner

      if @_opts

        if @_opts.hasOwnProperty('timeout')
          jasmine.jasmine.DEFAULT_TIMEOUT_INTERVAL = @_opts.timeout

        if @_opts.hasOwnProperty('config')
          jasmine.loadConfig @_opts.config

      jasmine.addReporter new JasmineReporter

        isVerbose: if @_opts then @_opts.verbose else false

        showColors: if @_opts then @_opts.showColors else true

        stackFilter: if @_opts then @_opts.stackFilter else true

        includeStackTrace: if @_opts then @_opts.includeStackTrace else false

      p = p.pipe through.obj ((file, enc, cb) =>

        # get the cache object of the specs.js file,
        # delete it and its children recursively from cache
        deleteRequireCache require.resolve file.path
        jasmine.addSpecFile file.path
        cb()
        return),

        (cb) => # flash
          try

            jasmine.onComplete =>
              @_firstRun = false
              cb()
              taskCallback()
              return

            if jasmine.helperFiles
              jasmine.helperFiles.forEach (helper) ->
                deleteRequireCache require.resolve helper
                return

            jasmine.execute()
          catch err
            cb new (gutil.PluginError)('DSGulpBuilder.jasmine', err, showStack: true)
          return

      return # _runSpecs:

# ----------------------------

  DSGulpBuilder.Task::jasmine = ->
    newInstance = Object.create(Jasmine::)
    args = [@]
    args.push arg for arg in arguments
    Jasmine.apply newInstance, args
    return newInstance

  return