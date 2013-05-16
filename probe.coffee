`/**
    @fileOverview Queries objects in memory using a mongo-like notation for reaching into objects and filtering for records

    @module ink/probe
    @author Terry Weiss
    @license MIT
*/`
`/**
These operators manage updates
@namespace updateOperators
@memberof module:ink/probe
**/`
`/**
Query operators
@namespace queryOperators
@memberof module:ink/probe
**/`
sys = require( "lodash" )

`/**
    The list of operators that are nested within the expression object. These take the form <code>{path:{operator:operand}}</code>
    @private
**/`
nestedOps = ["$eq", "$gt", "$gte", "$in", "$lt", "$lte", "$ne", "$nin", "$exists", "$mod", "$size", "$all"]

`/**
    The list of operators that prefix the expression object. These take the form <code>{operator:{operands}}</code> or <code>{operator: [operands]}</code>
    @private
**/`
prefixOps = ["$and", "$or", "$nor", "$not"]

`/**
    Processes a nested operator by picking the operator out of the expression object. Returns a formatted object that can be used for querying
    @private
    @param {string} path The path to element to work with
    @param {object} operand The operands to use for the query
    @return {object} A formatted operation definition
**/`
processNestedOperator = ( path, operand )->
  opKeys = Object.keys( operand )
  return {
  operation: opKeys[ 0 ]
  operands : [operand[ opKeys[ 0 ] ]]
  path     : path
  }

`/**
    Processes a prefixed operator and then passes control to the nested operator method to pick out the contained values
    @private
    @param {string} operation The operation prefix
    @param {object} operand The operands to use for the query
    @return {object} A formatted operation definition
**/`
processPrefixOperator = ( operation, operand )->
  component = {
    operation: operation
    path     : null
    operands : []
  }

  if (sys.isArray( operand ))
    # if it is an array we need to loop through the array and parse each operand
    sys.each( operand, ( obj )->
      sys.each( obj, ( val, key )->
        component.operands.push( processExpressionObject( val, key ) )
      )
    )
  else
    # otherwise it is an object and we can parse it directly
    sys.each( operand, ( val, key )->
      component.operands.push( processExpressionObject( val, key ) )
    )

  return component

`/**
    Interogates a single query expression object and calls the appropriate handler for its contents
    @private
    @param {object} val The expression
    @param {object} key The prefix
    @returns {object} A formatted operation definition
**/`
processExpressionObject = ( val, key )->

  if (sys.isObject( val ))
    opKeys = Object.keys( val )
    op = opKeys[ 0 ]

    if (sys.indexOf( nestedOps, op ) > -1)
      operator = processNestedOperator( key, val )
    else if (sys.indexOf( prefixOps, key ) > -1)
      operator = processPrefixOperator( key, val )
    else if (op == "$regex")
      # special handling for regex options
      operator = processNestedOperator( key, val )
    else if (op == "$elemMatch")
      # elemMatch is just a weird duck
      operator={
        path     : key,
        operation: op,
        operands : []
      }
      sys.each( val[ op ], ( entry )->

        operator.operands = parseQueryExpression( entry )
      )
    else
      throw new Error( "Unrecognized operator" )
  else
    operator =  processNestedOperator( key, { $eq: val } )

  return operator

`/**
    Parses a query request and builds an object that can used to process a query target
    @private
    @param {object} obj The expression object
    @returns {object} All components of the expression in a kind of execution tree
**/`
parseQueryExpression = ( obj )->

  if (sys.size( obj ) > 1)
    # it is really an $and operation in the form `{path:condition, path2:condition2}`
    arr =  sys.map( obj, ( v, k ) ->
      entry={}
      entry[ k ] = v
      return entry
    )
    obj = { $and: arr }

  payload=[]
  sys.each( obj, ( val, key )->

    exprObj = processExpressionObject( val, key )

    if (exprObj.operation == "$regex")
      exprObj.options = val[ "$options" ]

    payload.push( exprObj )
  )

  return payload

`/**
    Does what it says
    @private
**/`
donothing = ()->
  # do nothing
  return

`/**
The delimiter to use when splitting an expression
@type {string}
@default '.'
**/`
exports.delimiter = '.';
`/**
    Splits a path expression into its component parts
    @private
    @param {string} path The path to split
    @returns {array}
**/`
splitPath = ( path )->
  return path.split( exports.delimiter )

`/**
    Reaches into an object and allows you to get at a value deeply nested in an object
    @private
    @param {array} path The split path of the element to work with
    @param {object} record The record to reach into
    @return {*} Whatever was found in the record
**/`
reachin = ( path, record )->
  context = record

  for part in path
    context = context[ part ]

    if (sys.isNull( context ) or sys.isUndefined( context ))
      break

  return context

`/**
  This will write the value into a record at the path, creating intervening objects if they don't exist
  @private
  @param {array} path The split path of the element to work with
  @param {object} record The record to reach into
  @param {object} newValue The value to write to the, or if the operator is $pull, the query of items to look for
*/`
pushin = ( path, record, setter, newValue )->
  context = record
  parent = record
  lastPart = null

  for part in path
    lastPart = part
    parent = context
    context = context[ part ]
    if (sys.isNull( context ) or sys.isUndefined( context ))
      parent[ part ] = {}
      context = parent[ part ]

  if (sys.isEmpty( setter ) or setter == '$set')
    parent[ lastPart ] = newValue
  else
    switch (setter)
      when '$inc'
        ###*
        Increments a field by the amount you specify. It takes the form
            `{ $inc: { field1: amount } }`
        @name $inc
        @memberOf module:ink/probe.updateOperators
        @example
        var probe = require("ink-probe");
        probe.update( obj, {'name.last' : 'Owen', 'name.first' : 'LeRoy'},
          {$inc : {'password.changes' : 2}} );
        ###
        if !sys.isNumber( newValue )
          newValue = 1
        if (sys.isNumber( parent[ lastPart ] ))
          parent[ lastPart ] = parent[ lastPart ] + newValue
      when '$dec'
        ###*
        Decrements a field by the amount you specify. It takes the form
            `{ $dec: { field1: amount }`
        @name $dec
        @memberOf module:ink/probe.updateOperators
        @example
        var probe = require("ink-probe");
        probe.update( obj, {'name.last' : 'Owen', 'name.first' : 'LeRoy'},
          {$dec : {'password.changes' : 2}} );
        ###
        if !sys.isNumber( newValue )
          newValue = 1
        if (sys.isNumber( parent[ lastPart ] ))
          parent[ lastPart ] = parent[ lastPart ] - newValue
      when '$unset'
        ###*
        Removes the field from the object. It takes the form
            `{ $unset: { field1: "" } }`
        @name $unset
        @memberOf module:ink/probe.updateOperators
        @example
        var probe = require("ink-probe");
        probe.update( data, {'name.first' : 'Yogi'}, {$unset : {'name.first' : ''}} );
        ###
        delete parent[ lastPart ]
      when '$pop'
        ###*
        The $pop operator removes the first or last element of an array. Pass $pop a value of 1 to remove the last element
        in an array and a value of -1 to remove the first element of an array. This will only work on arrays. Syntax:
          `{ $pop: { field: 1 } }` or `{ $pop: { field: -1 } }`
        @name $pop
        @memberOf module:ink/probe.updateOperators
        @example
        var probe = require("ink-probe");
        // attr is the name of the array field
        probe.update( data, {_id : '511d18827da2b88b09000133'}, {$pop : {attr : 1}} );
        ###
        if (sys.isArray( parent[ lastPart ] ))
          if !sys.isNumber( newValue )
            newValue = 1
          if (newValue == 1)
            parent[ lastPart ].pop()
          else
            parent[ lastPart ].shift()
      when '$push'
        ###*
        The $push operator appends a specified value to an array. It looks like this:
          `{ $push: { <field>: <value> } }`
        @name $push
        @memberOf module:ink/probe.updateOperators
        @example
        var probe = require("ink-probe");
        // attr is the name of the array field
        probe.update( data, {_id : '511d18827da2b88b09000133'},
            {$push : {attr : {"hand" : "new", "color" : "new"}}} );
        ###
        if (sys.isArray( parent[ lastPart ] ))
          parent[ lastPart ].push( newValue )
      when '$pull'
        ###*
        The $pull operator removes all instances of a value from an existing array. It looks like this:
        `{ $pull: { field: <query> } }`
        @name $pull
        @memberOf module:ink/probe.updateOperators
        @example
        var probe = require("ink-probe");
        // attr is the name of the array field
        probe.update( data, {'email' : 'EWallace.43@fauxprisons.com'},
          {$pull : {attr : {"color" : "green"}}} );
        ###
        if (sys.isArray( parent[ lastPart ] ))
          keys = exports.findKeys( parent[ lastPart ], newValue )
          sys.each( keys, ( val, index )->
            delete parent[ lastPart ][ index ]
          )
          parent[ lastPart ] = sys.compact( parent[ lastPart ] )


`/**
    The query operations that evaluate directly from an operation
    @private
**/`
operations = {
  ###*
  `$eq` performs a `===` comparison by comparing the value directly if it is an atomic value.
  otherwise if it is an array, it checks to see if the value looked for is in the array.
  `{field: value}` or `{field: {$eq : value}}` or `{array: value}` or `{array: {$eq : value}}`
  @name $eq
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {categories : "cat1"} );
  // is the same as
  probe.find( data, {categories : {$eq: "cat1"}} );
  ###
  $eq       : ( qu, value )->
    if (sys.isArray( value ))
      return sys.find( value, ( entry ) ->
        return JSON.stringify( qu.operands[ 0 ] ) == JSON.stringify( entry )
      ) != undefined
    else
      return JSON.stringify( qu.operands[ 0 ] ) == JSON.stringify( value )
  ###*
  `$ne` performs a `!==` comparison by comparing the value directly if it is an atomic value. Otherwise, if it is an array
  this is performs a "not in array".
  '{field: {$ne : value}}` or '{array: {$ne : value}}`
  @name $ne
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"name.first" : {$ne : "Sheryl"}} );
  ###
  $ne       : ( qu, value )->
    if (sys.isArray( value ))
      return sys.find( value, ( entry ) ->
        return JSON.stringify( qu.operands[ 0 ] ) != JSON.stringify( entry )
      ) != undefined
    else
      return JSON.stringify( qu.operands[ 0 ] ) != JSON.stringify( value )

  ###*
  `$all` checks to see if all of the members of the query are included in an array
  `{array: {$all: [val1, val2, val3]}}`
  @name $all
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"categories" : {$all : ["cat4", "cat2", "cat1"]}} );
  ###
  $all      : ( qu, value ) ->
    result = false
    if (sys.isArray( value ))
      operands = sys.flatten( qu.operands )
      result = sys.intersection( operands, value ).length == operands.length

    return result
  ###*
  `$gt` Sees if a field is greater than the value
  `{field: {$gt: value}}`
  @name $gt
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"age" : {$gt : 24}} );
  ###
  $gt       : ( qu, value ) ->
    return qu.operands[ 0 ] < value
  ###*
  `$gte` Sees if a field is greater than or equal to the value
  `{field: {$gte: value}}`
  @name $gte
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"age" : {$gte : 50}} );
  ###
  $gte      : ( qu, value ) ->
    return qu.operands[ 0 ] <= value
  ###*
  `$lt` Sees if a field is less than the value
  `{field: {$lt: value}}`
  @name $lt
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"age" : {$lt : 24}} );
  ###
  $lt       : ( qu, value ) ->
    return qu.operands[ 0 ] > value
  ###*
  `$lte` Sees if a field is less than or equal to the value
  `{field: {$lte: value}}`
  @name $lte
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"age" : {$lte : 50}} );
  ###
  $lte      : ( qu, value ) ->
    return qu.operands[ 0 ] >= value
  ###*
  `$in` Sees if a field has one of the values in the query
  `{field: {$in: [test1, test2, test3,...]}}`
  @name $in
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"age" : {$in : [24, 28, 60]}} );
  ###
  $in       : ( qu, value )->
    operands = sys.flatten( qu.operands )
    return sys.indexOf( operands, value ) > -1
  ###*
  `$nin` Sees if a field has none of the values in the query
  `{field: {$nin: [test1, test2, test3,...]}}`
  @name $nin
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"age" : {$nin : [24, 28, 60]}} );
  ###
  $nin      : ( qu, value )->
    operands = sys.flatten( qu.operands )
    return sys.indexOf( operands, value ) == -1
  ###*
  `$exists` Sees if a field exists.
  `{field: {$exists: true|false}}`
  @name $exists
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"name.middle" : {$exists : true}} );
  ###
  $exists   : ( qu, value )->
    return not ((sys.isNull( value ) || sys.isUndefined( value )) == qu.operands[ 0 ]  )
  ###*
  Checks equality to a modulus operation on a field
  `{field: {$mod: [divisor, remainder]}}`
  @name $mod
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"age" : {$mod : [2, 0]}} );
  ###
  $mod      : ( qu, value )->
    operands = sys.flatten( qu.operands )
    if (operands.length != 2 )
      throw new Error( "$mod requires two operands" )
    mod = operands[ 0 ]
    rem = operands[ 1 ]
    return value % mod == rem
  ###*
  Compares the size of the field/array to the query. This can be used on arrays, strings and objects (where it will count keys)
  `{'field|array`: {$size: value}}`
  @name $size
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {attr : {$size : 3}} );
  ###
  $size     : ( qu, value )->
    return sys.size( value ) == qu.operands[ 0 ]
  ###*
  Performs a regular expression test againts the field
  `{field: {$regex: re, $options: reOptions}}`
  @name $regex
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {"name.first" : {$regex : "m*", $options : "i"}} );
  ###
  $regex    : ( qu, value )->
    r = new RegExp( qu.operands[ 0 ], qu.options );
    r.test( value )
  ###*
  This is like $all except that it works with an array of objects or value. It checks to see the array matches all
  of the conditions of the query
  `{array: {$elemMatch: {path: value, path: {$operation: value2}}}`
  @name $elemMatch
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {attr : {$elemMatch : [
		{color : "red", "hand" : "left"}
	]}} );
  ###
  $elemMatch: ( qu, value )->
    if (sys.isArray( value ))
      for expression in qu.operands
        expression.splitPath = splitPath( expression.path ) if expression.path

      test = execQuery( value, qu.operands, null, true ).arrayResults
    return test.length > 0
  ###*
  Returns true if all of the conditions of the query are met
  `{$and: [query1, query2, query3]}`
  @name $and
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {$and : [
		{"name.first" : "Mildred"},
		{"name.last" : "Graves"}
	]} );
  ###
  $and      : ( qu, value, record )->
    isAnd = false
    for expr in qu.operands
      expr.splitPath ?= splitPath( expr.path ) if expr.path

      test = reachin( expr.splitPath, record, expr.operation )
      isAnd = operations[ expr.operation ]( expr, test, record )
      if (!isAnd)
        break

    return isAnd
  ###*
  Returns true if any of the conditions of the query are met
  `{$or: [query1, query2, query3]}`
  @name $or
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {$or : [
		{"age" : {$in : [24, 28, 60]}},
		{categories : "cat1"}
	]} );
  ###
  $or       : ( qu, value, record )->
    isOr = false
    for expr in qu.operands
      expr.splitPath ?= splitPath( expr.path ) if expr.path

      test = reachin( expr.splitPath, record, expr.operation )

      isOr = operations[ expr.operation ]( expr, test, record )
      if (isOr)
        break

    return isOr
  ###*
  Returns true if none of the conditions of the query are met
  `{$nor: [query1, query2, query3]}`
  @name $nor
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {$nor : [
		{"age" : {$in : [24, 28, 60]}},
		{categories : "cat1"}
	]} );
  ###
  $nor      : ( qu, value, record )->
    isOr = false
    for expr in qu.operands
      expr.splitPath ?= splitPath( expr.path ) if expr.path

      test = reachin( expr.splitPath, record, expr.operation )

      isOr = operations[ expr.operation ]( expr, test, record )

      if (isOr)
        break

    return !isOr
  ###*
  Logical NOT on the conditions of the query
  `{$not: [query1, query2, query3]}`
  @name $not
  @memberOf module:ink/probe.queryOperators
  @example
  var probe = require("ink-probe");
  probe.find( data, {$not : {"age" : {$lt : 24}}} );
  ###
  $not      : ( qu, value, record )->
    result = false

    for expr in qu.operands
      expr.splitPath ?= splitPath( expr.path ) if expr.path

      test = reachin( expr.splitPath, record, expr.operation )

      result = operations[ expr.operation ]( expr, test, record )

      if (result)
        break
    return !result

}
`/**
    Executes a query by traversing a document and evaluating each record
    @private
    @param {array|object} obj The object to query
    @param {object} qu The query to execute
    @param {boolean} shortCircuit When true, the condition that matches the query stops evaluation for that record, otherwise all conditions have to be met
    @param {boolean} stopOnFirst When true all evaluation stops after the first record is found to match the conditons
**/`
execQuery = ( obj, qu, shortCircuit, stopOnFirst )->
  arrayResults = []
  keyResults = []
  sys.each( obj, ( record, key )->
    for expr in qu
      test = reachin( expr.splitPath, record, expr.operation ) if expr.splitPath
      result = operations[ expr.operation ]( expr, test, record )
      if (result)
        arrayResults.push( record )
        keyResults.push( key )

      if (!result and shortCircuit)
        break

    if (arrayResults.length > 0 and stopOnFirst)
      return false;
  )
  return { arrayResults, keyResults }

`/**
Updates all records in obj that match the query. See {@link module:ink/probe.updateOperators} for the operators that are supported.
@param {object|array} obj The object to update
@param {object} qu The query which will be used to identify the records to updated
@param {object} setDocument The update operator. See {@link module:ink/probe.updateOperators}
 */`
exports.update = ( obj, qu, setDocument )->
  records = exports.find( obj, qu )

  sys.each( records, ( record )->
    sys.each( setDocument, ( fields, operator )->

      sys.each( fields, ( newValue, path )->
        pushin( splitPath( path ), record, operator, newValue )
      )
    )
  )

`/**
    Find all records that match a query
    @param {array|object} obj The object to query
    @param {object} qu The query to execute. See {@link module:ink/probe.queryOperators} for the operators you can use.
    @returns {array} The results
**/`
exports.find = ( obj, qu ) ->
  query = parseQueryExpression( qu )

  for expression in query
    expression.splitPath = splitPath( expression.path ) if expression.path

  execQuery( obj, query ).arrayResults

###*
    Find all records that match a query and returns the keys for those items. This is similar to {@link module:ink/probe.find} but instead of returning
    records, returns the keys. If `obj` is an object it will return the hash key. If 'obj' is an array, it will return the index
    @param {array|object} obj The object to query
    @param {object} qu The query to execute. See {@link module:ink/probe.queryOperators} for the operators you can use.
    @returns {array}
###
exports.findKeys = ( obj, qu ) ->
  query = parseQueryExpression( qu )

  for expression in query
    expression.splitPath = splitPath( expression.path ) if expression.path

  execQuery( obj, query ).keyResults

###*
    Returns the first record that matches the query. Aliased as `seek`.
    @param {array|object} obj The object to query
    @param {object} qu The query to execute. See {@link module:ink/probe.queryOperators} for the operators you can use.
    @returns {object}
###
exports.findOne = ( obj, qu )->
  query = parseQueryExpression( qu )

  for expression in query
    expression.splitPath = splitPath( expression.path ) if expression.path

  results = execQuery( obj, query, false, true ).arrayResults
  if (results.length > 0)
    return results[ 0 ]
  else
    return null


###*
    Returns the first record that matches the query and returns its key or index depending on whether `obj` is an object or array respectively.
    Aliased as `seekKey`.
    @param {array|object} obj The object to query
    @param {object} qu The query to execute. See {@link module:ink/probe.queryOperators} for the operators you can use.
    @returns {object}
###
exports.findOneKey = ( obj, qu )->
  query = parseQueryExpression( qu )

  for expression in query
    expression.splitPath = splitPath( expression.path ) if expression.path

  results = execQuery( obj, query, false, true ).keyResults
  if (results.length > 0)
    return results[ 0 ]
  else
    return null


`/**
    Remove all items in the object/array that match the query
    @param {array|object} obj The object to query
    @param {object} qu The query to execute. See {@link module:ink/probe.queryOperators} for the operators you can use.
    @return {object|array} The array or object as appropriate without the records.
**/`
exports.remove = ( obj, qu )->
  query = parseQueryExpression( qu )

  for expression in query
    expression.splitPath = splitPath( expression.path ) if expression.path

  results = execQuery( obj, query, false, false ).keyResults

  if (sys.isArray( obj ))

    newArr= []
    sys.each( obj, ( item, index )->
      if (sys.indexOf( results, index ) == -1)
        newArr.push( item )
    )
    return newArr
  else
    sys.each( results, ( key )->
      delete obj[ key ]
    )
    return obj


`/**
    Returns true if all items match the query

    @param {array|object} obj The object to query
    @param {object} qu The query to execute. See {@link module:ink/probe.queryOperators} for the operators you can use.
    @returns {boolean}
**/`
exports.all = ( obj, qu ) ->
  return exports.find( obj, qu ).length == sys.size( obj )

`/**
    Returns true if any of the items match the query

    @param {array|object} obj The object to query
    @param {object} qu The query to execute. See {@link module:ink/probe.queryOperators} for the operators you can use.
    @returns {boolean}
**/`
exports.any = ( obj, qu )->
  query = parseQueryExpression( qu )

  for expression in query
    expression.splitPath = splitPath( expression.path ) if expression.path

  results = execQuery( obj, query, true, true ).keyResults

  return results.length > 0

`/**
Returns the set of unique records that match a query
@param {array|object} obj The object to query
@param {object} qu The query to execute. See {@link module:ink/probe.queryOperators} for the operators you can use.
@return {array}
**/`
exports.unique = ( obj, qu )->
  test = exports.find( obj, qu );
  return sys.unique( test, ( item )->
    return JSON.stringify( item )
  )

`/**
  This will write the value into a record at the path, creating intervening objects if they don't exist. This does not work as filtered
  update and is meant to be used on a single record. It is a nice way of setting a property at an arbitrary depth at will.

  @param {array} path The split path of the element to work with
  @param {object} record The record to reach into
  @param {string} setter The set operation.  See {@link module:ink/probe.updateOperators} for the operators you can use.
  @param {object} newValue The value to write to the, or if the operator is $pull, the query of items to look for
*/`
exports.set = ( record, path, setter, newValue ) -> pushin( path, record, setter, newValue )

`/**
    Reaches into an object and allows you to get at a value deeply nested in an object. This is not a query, but a
    straight reach in, useful for event bindings

    @param {array} path The split path of the element to work with
    @param {object} record The record to reach into
    @return {*} Whatever was found in the record
**/`
exports.get = ( record, path ) -> reachin( path, record )

###*
    Returns true if any of the items match the query. Aliases as `any`
     @function
    @param {array|object} obj The object to query
    @param {object} qu The query to execute
    @returns {boolean}
###
exports.some = exports.any

###*
    Returns true if all items match the query. Aliases as `all`
    @function
    @param {array|object} obj The object to query
    @param {object} qu The query to execute
    @returns {boolean}
###
exports.every = exports.all


exports.seek = exports.findOne;
exports.seekKey = exports.findOneKey;

# when bound, these are the methods that will be exposed and their names
bindables =
  any       : exports.any
  all       : exports.all
  remove    : exports.remove
  seekKey   : exports.seekKey
  seek      : exports.seek
  findOneKey: exports.findOneKey
  findOne   : exports.findOne
  findKeys  : exports.findKeys
  find      : exports.find
  update    : exports.update
  remove    : exports.remove
  some      : exports.some
  every     : exports.every

`/**
   Binds the query and update methods to a specific object. When called these
   methods can skip the first parameter so that find(object, query) can just be called as find(query)
   @param {object|array} obj The object or array to bind to
   @return {object} An object with method bindings in place
**/`
exports.bindTo = ( obj )->
  retVal = {}
  sys.each( bindables, ( val, key )->
    retVal[ key ] = sys.bind( val, obj, obj )
  )
  return retVal

`/**
   Binds the query and update methods to a specific object and adds the methods to that object. When called these
   methods can skip the first parameter so that find(object, query) can just be called as object.find(query)
   @param {object|array} obj The object or array to bind to
   @param {object|array=} collection If the collection is not the same as <code>this</code> but is a property, or even
   a whole other object, you specify that here. Otherwise the <code>obj</code> is assumed to be the same as the collecion
**/`
exports.mixTo = ( obj, collection )->
  collection = collection || obj
  sys.each( bindables, ( val, key )->
    obj[ key ] = sys.bind( val, obj, collection )
  )





