betterIndent = (string, loc) ->
  size = string.length
  newloc = size - (size % 4) + 8
  if newloc < loc
    newloc = loc
  string + new Array(newloc - size + 1).join(' ')

module.exports =

  getDataURI: (sourceMap) ->
    'data:application/json;base64,' + new Buffer(unescape(encodeURIComponent(sourceMap)), 'binary').toString('base64')

  fixSourceMapContent: (sourceMap, source) ->
    map = JSON.parse(sourceMap)
    map.sourcesContent = [ source ]
    map

  addSourceComments: (source, sourceMap, filename, SM) ->
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
      source = lines.join('\n').replace(/\/\/# sourceMappingURL=.+/, '// SourceMap was distributed to comments by gulp-jsx-coverage')
    source
