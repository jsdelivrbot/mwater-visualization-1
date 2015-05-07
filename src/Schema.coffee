
# Schema for a database
module.exports = class Schema
  constructor: ->
    @tables = []
    @joins = []

  # Add table with id, name, desc, icon
  addTable: (options) ->
    table = _.pick(options, "id", "name", "desc", "icon", "ordering")
    table.columns = []
    @tables.push(table)

  getTables: -> @tables

  getTable: (tableId) -> _.findWhere(@tables, { id: tableId })

  addColumn: (tableId, options) ->
    table = @getTable(tableId)
    table.columns.push(_.pick(options, "id", "primary", "name", "desc", "type", "values"))

  getColumns: (tableId) ->
    table = @getTable(tableId)
    return table.columns

  getColumn: (tableId, columnId) ->
    table = @getTable(tableId)
    return _.findWhere(table.columns, { id: columnId })

  # id, name, fromTableId, fromColumnId, toTableId, toColumnId, op, multiple
  addJoin: (options) ->
    @joins.push(_.pick(options, "id", "name", "fromTableId", "fromColumnId", "toTableId", "toColumnId", "op", "multiple"))

  getJoins: -> @joins

  # Pass baseTableId and joinIds (optional)
  getJoinExprTree: (options) ->
    # Get base table
    baseTable = @getTable(options.baseTableId)

    tree = []
    joinIds = options.joinIds or []
    
    # Add columns
    for col in baseTable.columns
      # Skip primary key if no joins
      if joinIds.length == 0 and col.primary
        continue 

      # Skip uuid fields unless primary
      if col.type == "uuid" and not col.primary
        continue

      if col.primary
        name = "Number of #{baseTable.name}"
        desc = ""
      else 
        name = col.name
        desc = col.desc

      # Filter by type
      if options.types and col.type not in options.types
        continue

      tree.push({
        id: col.id
        name: name
        desc: col.desc
        type: col.type
        value: {
          joinIds: joinIds
          expr: { type: "field", tableId: baseTable.id, columnId: col.id }
          }
        })

    # Add joins
    for join in @joins
      do (join) =>
        if join.fromTableId == baseTable.id
          tree.push({
            id: join.id
            name: join.name
            desc: join.desc
            value: {
              joinIds: joinIds
              }
            getChildren: =>
              return @getJoinExprTree({ baseTableId: join.toTableId, joinIds: joinIds.concat([join.id]) })
            })
    return tree

  # Gets the type of an expression
  getExprType: (expr) ->
    switch expr.type
      when "field"
        column = @getColumn(expr.tableId, expr.columnId)
        return column.type
      else
        throw new Error("Not implemented")

  # Gets the table of an expression (null if none)
  getExprTable: (expr) ->
    switch expr.type
      when "field"
        return @getTable(expr.tableId)
      else
        throw new Error("Not implemented")

  # Gets available aggregations [{id, name}]
  getAggrs: (expr) ->
    aggrs = []

    type = @getExprType(expr)
    
    table = @getExprTable(expr)
    if table and table.ordering
      aggrs.push({ id: "last", name: "Latest", type: type })

    aggrs.push({ id: "count", name: "Count", type: "integer" })

    switch type
      when "integer", "decimal"
        aggrs.push({ id: "sum", name: "Total", type: type })
        aggrs.push({ id: "avg", name: "Average", type: "decimal" })

    return aggrs