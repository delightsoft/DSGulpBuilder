class StubTask extends (require './common/TaskBase')
  dest: -> @
  duplicate: -> @
  watch: -> @

  constructor: -> super
  _build: -> # required by TaskBase
  
modules =   

  'sass': 'ds-gulp-builder-sass'
  'jade': 'ds-gulp-builder-jade'
  'pug': 'ds-gulp-builder-pug'
  'browserify': 'ds-gulp-builder-browserify'
  'browserSync': 'ds-gulp-builder-browser-sync'
  'jasmine': 'ds-gulp-builder-jasmine'
  'ngJade2JS': 'ds-gulp-builder-ng-jade2js'

#  'sass': 'C:\\GIT\\DSGulpBuilder\\tasks\\sass'
#  'jade': 'C:\\GIT\\DSGulpBuilder\\tasks\\jade'
#  'pug': 'C:\\GIT\\DSGulpBuilder\\tasks\\pug'
#  'browserify': 'C:\\GIT\\DSGulpBuilder\\tasks\\browserify'
#  'browserSync': 'C:\\GIT\\DSGulpBuilder\\tasks\\browserSync'
#  'jasmine': 'C:\\GIT\\DSGulpBuilder\\tasks\\jasmine'
#  'ngJade2JS': 'C:\\GIT\\DSGulpBuilder\\tasks\\ngjade2js'

# ----------------------------  
  
module.exports =
  StubTask: StubTask
  modules: modules
  
