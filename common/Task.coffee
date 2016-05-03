path = require 'path'

TaskBase = require './TaskBase'

module.exports =

    class Task extends TaskBase

      (-> # generate specific task object instantiators listing tasks from ../tasks folder
        for taskName, taskClass of require('require-dir')( '../tasks', { recurse: false })
          do (taskName, taskClass) =>
            @::[taskName[0].toLowerCase() + taskName.substr 1] = (->
              newInstance = Object.create(taskClass::)
              args = [@]
              args.push arg for arg in arguments
              taskClass.apply newInstance, args
              return newInstance)
        return).call @
