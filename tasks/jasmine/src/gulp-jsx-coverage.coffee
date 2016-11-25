# Note: gulp-jsx-coverage is very good implementation of code preparation before code-coverage run.  But it doesn't fit into continious build DSGulpBuilder does.
# So, I've borred functions and methods to implement three steps process in DSGulpBuilder.jasmine task:
# - copy source code to temporary folder, with code-coverage code insertion
# - running specs on code with code-coverage in it
# - writing report

gulp = require('gulp')
fs = require('fs')
babel = require('babel-core')
SM = require('source-map')
sourceStore = `undefined`
finalSummary = `undefined`
sourceMapCache = {}

getDataURI = (sourceMap) ->
  'data:application/json;base64,' + new Buffer(unescape(encodeURIComponent(sourceMap)), 'binary').toString('base64')

fixSourceMapContent = (sourceMap, source) ->
  map = JSON.parse(sourceMap)
  map.sourcesContent = [ source ]
  map

betterIndent = (string, loc) ->
  size = string.length
  newloc = size - (size % 4) + 8
  if newloc < loc
    newloc = loc
  string + new Array(newloc - size + 1).join(' ')

addSourceComments = (source, sourceMap, filename) ->
  oldlines = undefined
  lines = source.split(/\n/)
  mappings = []
  loc = 0
  line = undefined
  smc = undefined
  outputs = []
  if sourceMap and sourceMap.sourcesContent and sourceMap.sourcesContent[0]
    sourceMap.newLines = lines.slice(0)
    oldlines = sourceMap.sourcesContent[0].split(/\n/)
    smc = new (SM.SourceMapConsumer)(sourceMap)
    lines.forEach (L, I) ->
      XY = smc.originalPositionFor(
        line: I + 1
        column: 1)
      if !XY.line and L
        XY = smc.originalPositionFor(
          line: I + 1
          column: L.length - 1)
      if !XY.line or !L
        loc -= 8
        return
      # Do not comment when transform nothing
      if `oldlines[XY.line - 1] == L`
        return
      line = betterIndent(L, loc)
      loc = line.length
      # Add comment to hint original code
      lines[I] = line + '// ' + (if `XY.line != I + 1` then 'Line ' + XY.line + ': ' else '') + oldlines[XY.line - 1]
      return
    sourceMap.smc = smc
    sourceMap.oldLines = oldlines
    sourceMapCache[filename] = sourceMap
    source = lines.join('\n').replace(/\/\/# sourceMappingURL=.+/, '// SourceMap was distributed to comments by gulp-jsx-coverage')
  source

# Never use node-jsx or other transform in your testing code!

initModuleLoaderHack = (options) ->
  Module = require('module')
  istanbul = require(if options.isparta then 'isparta' else 'istanbul')
  instrumenter = new (istanbul.Instrumenter)(Object.assign((if options.isparta then babelOptions: options.babel else {}), options.istanbul))
  babelFiles = Object.assign({
    include: /\.jsx?$/
    exclude: /node_modules/
    omitExt: false
  }, if options.transpile then options.transpile.babel else `undefined`)
  coffeeFiles = Object.assign({
    include: /\.coffee$/
    exclude: /^$/
    omitExt: false
  }, if options.transpile then options.transpile.coffee else `undefined`)
  cjsxFiles = Object.assign({
    include: /\.cjsx$/
    exclude: /^$/
    omitExt: false
  }, if options.transpile then options.transpile.cjsx else `undefined`)

  moduleLoader = (module, filename) ->
    srcCache = sourceStore.map[filename]
    src = srcCache or fs.readFileSync(filename, encoding: 'utf8')
    tmp = undefined
    if srcCache
      return
    if filename.match(babelFiles.include) and !filename.match(babelFiles.exclude)
      if !options.sparta or !filename.match(options.istanbul.exclude)
        try
          tmp = babel.transform(src, Object.assign({ filename: filename }, options.babel))
          srcCache = tmp.map or 1
          src = tmp.code
        catch e
          throw new Error('Error when transform es2015/jsx ' + filename + ': ' + e.toString())
    if filename.match(cjsxFiles.include) and !filename.match(cjsxFiles.exclude)
      try
        src = require('coffee-react-transform')(src)
      catch e
        throw new Error('Error when transform cjsx ' + filename + ': ' + e.toString())
    if filename.match(coffeeFiles.include) and !filename.match(coffeeFiles.exclude) or filename.match(cjsxFiles.include) and !filename.match(cjsxFiles.exclude)
      try
        tmp = require('coffee-script').compile(src, options.coffee)
        srcCache = if tmp.v3SourceMap then fixSourceMapContent(tmp.v3SourceMap, src) else 1
        src = tmp.js + '\n//# sourceMappingURL=' + getDataURI(JSON.stringify(srcCache))
      catch e
        throw new Error('Error when transform coffee ' + filename + ': ' + e.toString())
    if srcCache
      sourceStore.set filename, addSourceComments(src, srcCache, filename)
    # Don't instrument files that aren't meant to be
    if !filename.match(options.istanbul.exclude)
      try
        src = instrumenter.instrumentSync(src, filename)
      catch e
        throw new Error('Error when instrument ' + filename + ': ' + e.toString())
    module._compile src, filename
    return

  global[options.istanbul.coverageVariable] = {}
  sourceStore = istanbul.Store.create('memory')
  sourceStore.dispose()
  sourceMapCache = {}
  Module._extensions['.js'] = moduleLoader
  if babelFiles.omitExt
    babelFiles.omitExt.forEach (V) ->
      Module._extensions[V] = moduleLoader
      return
  if coffeeFiles.omitExt
    coffeeFiles.omitExt.forEach (V) ->
      Module._extensions[V] = moduleLoader
      return
  if cjsxFiles.omitExt
    cjsxFiles.omitExt.forEach (V) ->
      Module._extensions[V] = moduleLoader
      return
  return

stackDumper = (stack) ->
  stack.replace /\((.+?):(\d+):(\d+)\)/g, (M, F, L, C) ->
    sourcemap = sourceMapCache[F]
    XY = undefined
    if !sourcemap
      return M
    L = L * 1
    C = C * 1
    XY = sourcemap.smc.originalPositionFor(
      line: L
      column: C)
    if !XY.line
      XY = sourcemap.smc.originalPositionFor(
        line: L
        column: C
        bias: SM.SourceMapConsumer.LEAST_UPPER_BOUND)
    if !XY.line
      return M + '\nTRANSPILED: ' + sourcemap.newLines[L - 1] + '\n' + new Array(C * 1 + 13).join('-') + '^'
    '(' + F + ':' + XY.line + ':' + XY.column + ')' + '\nORIGINALSRC: ' + sourcemap.oldLines[XY.line - 1] + '\n' + new Array(XY.column + 13).join('-') + '^\nTRANSPILED : ' + sourcemap.newLines[L - 1] + '\u0009// line ' + L + ',' + C + '\n' + new Array(C + 13).join('-') + '^'

getCustomizedMochaStackTraceFilter = ->
  stackDumper

GJC =
  oldMochaStackTraceFilter: `undefined`
  initModuleLoaderHack: (options) ->
    initModuleLoaderHack options
    return
  collectIstanbulCoverage: (options) ->
    ->
      istanbul = require(if options.isparta then 'isparta' else 'istanbul')
      collector = new (istanbul.Collector)
      collector.add global[options.istanbul.coverageVariable]
      finalSummary = istanbul.utils.mergeSummaryObjects.apply(null, collector.files().map((F) ->
        istanbul.utils.summarizeFileCoverage collector.fileCoverageFor(F)
      ))
      options.coverage.reporters.forEach (R) ->
        istanbul.Report.create(R,
          sourceStore: if options.isparta then `undefined` else sourceStore
          dir: options.coverage.directory).writeReport collector, true
        return
      if `'function' == typeof options.cleanup`
        options.cleanup this
      if options.threshold and `'function' == typeof options.threshold.forEach`
        options.threshold.forEach ((O) ->
          GJC.failWithThreshold(O.min, O.type).apply this
          return
        ).bind(this)
      GJC.disableStackTrace()
      return
  disableStackTrace: ->
    if GJC.oldMochaStackTraceFilter
      require('mocha/lib/utils').stackTraceFilter = GJC.oldMochaStackTraceFilter
    return
  enableStackTrace: ->
    if !GJC.oldMochaStackTraceFilter
      GJC.oldMochaStackTraceFilter = require('mocha/lib/utils').stackTraceFilter
    require('mocha/lib/utils').stackTraceFilter = getCustomizedMochaStackTraceFilter
    return
  failWithThreshold: (threshold, type) ->
    ->
      T = type or 'lines'
      if !finalSummary or !threshold
        return
      if finalSummary[T].pct < threshold
        @emit 'error', new (require('gulp-util').PluginError)(
          plugin: 'gulp-jsx-coverage'
          message: T + ' coverage ' + finalSummary[T].pct + '% is lower than threshold ' + threshold + '%!')
      return
  createTask: (options) ->
    ->
      GJC.initModuleLoaderHack options
      GJC.enableStackTrace()
      gulp.src(options.src).pipe(require('gulp-mocha')(options.mocha)).on 'end', GJC.collectIstanbulCoverage(options)
module.exports = GJC
require('object.assign').shim()

# ---
# generated by js2coffee 2.2.0