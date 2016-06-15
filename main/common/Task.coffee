TaskBase = require './TaskBase'

{StubTask, modules: externalTasks} = require '../externalTasks'

newTask = (taskClass) ->
  ->
    newInstance = Object.create(taskClass::)
    args = [@]
    args.push arg for arg in arguments
    taskClass.apply newInstance, args
    return newInstance # newTask =

module.exports =

  class Task extends TaskBase
    
    clazz = @
    
    @missingModules = []

    for taskName, taskNPM of externalTasks
      do (taskName, taskNPM) ->
        clazz::[taskName] = ->
          try
            require(taskNPM)(clazz::_DSGulpBuilder)
            (clazz::[taskName]).apply @, arguments # clazz::[taskName] = ->
          catch err
            if err.message.indexOf('Cannot find module') >= 0
              clazz.missingModules.push taskNPM
              # Note: StubTask is from first approach.  Now 'go' simply stops processing
              # TODO: Remove later
              new StubTask taskName # clazz::[taskName] = ->
            else
              throw err

    # generate specific task object instantiators listing tasks from ../tasks folder
    for taskName, taskClass of require('require-dir')( '../tasks', { recurse: false })
      clazz::[taskName[0].toLowerCase() + taskName.substr 1] = newTask.call clazz, taskClass
