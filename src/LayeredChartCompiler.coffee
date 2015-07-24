ExpressionCompiler = require './ExpressionCompiler'
ExpressionBuilder = require './ExpressionBuilder'

# Compiles various parts of a layered chart (line, bar, scatter, spline, area) to C3.js format
module.exports = class LayeredChartCompiler
  # Pass in schema
  constructor: (options) ->
    @schema = options.schema
    @exprBuilder = new ExpressionBuilder(@schema)

  # Get layer type, defaulting to overall type
  getLayerType: (design, layerIndex) ->
    return design.layers[layerIndex].type or design.type

  # Determine if layer required grouping by x (and color)
  doesLayerNeedGrouping: (design, layerIndex) ->
    return @getLayerType(design, layerIndex) != "scatter"

  # Determines if expr is categorical
  isExprCategorical: (expr) ->
    return @exprBuilder.getExprType(expr) in ['text', 'enum', 'boolean']

  compileExpr: (expr) ->
    exprCompiler = new ExpressionCompiler(@schema)
    return exprCompiler.compileExpr(expr: expr, tableAlias: "main")

  getQueries: (design, extraFilters) ->
    queries = {}

    # For each layer
    for layerIndex in [0...design.layers.length]
      layer = design.layers[layerIndex]

      # Create shell of query
      query = {
        type: "query"
        selects: []
        from: { type: "table", table: layer.table, alias: "main" }
        limit: 1000
        groupBy: []
        orderBy: []
      }

      xExpr = @compileExpr(layer.xExpr)
      colorExpr = @compileExpr(layer.colorExpr)
      yExpr = @compileExpr(layer.yExpr)

      if xExpr
        query.selects.push({ type: "select", expr: xExpr, alias: "x" })
      if colorExpr
        query.selects.push({ type: "select", expr: colorExpr, alias: "color" })

      # Sort by x and color
      if xExpr or colorExpr
        query.orderBy.push({ ordinal: 1 })
      if xExpr and colorExpr
        query.orderBy.push({ ordinal: 2 })

      # If grouping type
      if @doesLayerNeedGrouping(design, layerIndex)
        if xExpr or colorExpr
          query.groupBy.push(1)

        if xExpr and colorExpr
          query.groupBy.push(2)

        if yExpr
          query.selects.push({ type: "select", expr: { type: "op", op: layer.yAggr, exprs: [yExpr] }, alias: "y" })
        else
          query.selects.push({ type: "select", expr: { type: "op", op: layer.yAggr, exprs: [] }, alias: "y" })
      else
        query.selects.push({ type: "select", expr: yExpr, alias: "y" })

      # Add where
      if layer.filter
        query.where = @compileExpr(layer.filter)

      # Add filters
      if extraFilters and extraFilters.length > 0
        # Get relevant filters
        relevantFilters = _.where(extraFilters, table: layer.table)

        # If any, create and
        if relevantFilters.length > 0
          whereClauses = []

          # Keep existing where
          if query.where
            whereClauses.push(query.where)

          # Add others
          for filter in relevantFilters
            whereClauses.push(@compileExpr(filter))

          # Wrap if multiple
          if whereClauses.length > 1
            query.where = { type: "op", op: "and", exprs: whereClauses }
          else
            query.where = whereClauses[0]

      queries["layer#{layerIndex}"] = query

    return queries

  # Translates enums to label, leaves all else alone
  mapValue: (expr, value) ->
    if value and @exprBuilder.getExprType(expr) == "enum"
      items = @exprBuilder.getExprValues(expr)
      item = _.findWhere(items, { id: value })
      if item
        return item.name
    return value

  # Gets the columns for C3. Also updates dataMap to be a mapping
  # of "series-" + index to { layerIndex:, row: }
  # for lookup purposes
  getColumns: (design, data, dataMap={}) ->
    columns = []

    # Determine if x is categorical
    xCategorical = @isExprCategorical(design.layers[0].xExpr)
    xPresent = design.layers[0].xExpr?

    # Get all values
    xValues = []
    for layerIndex in [0...design.layers.length]
      layer = design.layers[layerIndex]
      xValues = _.union(xValues, _.pluck(data["layer#{layerIndex}"], "x"))

    # For each layer
    for layerIndex in [0...design.layers.length]
      layer = design.layers[layerIndex]

      # If color expr
      if layer.colorExpr
        # Determine all color values
        colorValues = _.uniq(_.pluck(data["layer#{layerIndex}"], "color"))

        if xCategorical
          # Create a series for each color value
          for colorVal in colorValues
            # Use x axis for each and lookup y
            xcolumn = ["layer#{layerIndex}:#{colorVal}:x"]
            ycolumn = ["layer#{layerIndex}:#{colorVal}:y"]

            for val in xValues
              xcolumn.push(@mapValue(layer.xExpr, val))
              row = _.findWhere(data["layer#{layerIndex}"], { x: val, color: colorVal })
              if row
                ycolumn.push(row.y)
                dataMap["#{ycolumn[0]}-#{ycolumn.length-2}"] = { layerIndex: layerIndex, row: row }
              else
                ycolumn.push(null)
            columns.push(xcolumn)
            columns.push(ycolumn)
        else
          # Create a series for each color value
          for colorVal in colorValues
            # Use x axis for each and lookup y
            if xPresent
              xcolumn = ["layer#{layerIndex}:#{colorVal}:x"]
            ycolumn = ["layer#{layerIndex}:#{colorVal}:y"]

            for row in data["layer#{layerIndex}"]
              if row.color == colorVal
                if xPresent
                  xcolumn.push(@mapValue(layer.xExpr, row.x))
                ycolumn.push(row.y)
                dataMap["#{ycolumn[0]}-#{ycolumn.length-2}"] = { layerIndex: layerIndex, row: row }

            if xPresent
              columns.push(xcolumn)
            columns.push(ycolumn)
      else
        if xCategorical
          # Use x axis for each and lookup y
          xcolumn = ["layer#{layerIndex}:x"]
          ycolumn = ["layer#{layerIndex}:y"]

          for val in xValues
            xcolumn.push(@mapValue(layer.xExpr, val))
            row = _.findWhere(data["layer#{layerIndex}"], { x: val })
            if row
              ycolumn.push(row.y)
              dataMap["#{ycolumn[0]}-#{ycolumn.length-2}"] = { layerIndex: layerIndex, row: row }
            else
              ycolumn.push(null)

          columns.push(xcolumn)
          columns.push(ycolumn)
        else
          # Simple expression
          if xPresent
            xcolumn = ["layer#{layerIndex}:x"]
          ycolumn = ["layer#{layerIndex}:y"]

          for row in data["layer#{layerIndex}"]
            if xPresent
              xcolumn.push(@mapValue(layer.xExpr, row.x))
            ycolumn.push(row.y)
            dataMap["#{ycolumn[0]}-#{ycolumn.length-2}"] = { layerIndex: layerIndex, row: row }

          if xPresent
            columns.push(xcolumn)
          columns.push(ycolumn)

    return columns

  getXs: (columns) ->
    xs = {}
    for col in columns
      if col[0].match(/:y$/)
        xcol = col[0].replace(/:y$/, ":x")
        if _.any(columns, (c) -> c[0] == xcol)
          xs[col[0]] = xcol

    return xs

  getNames: (design, data) ->
    names = {}
    # For each layer
    for layerIndex in [0...design.layers.length]
      layer = design.layers[layerIndex]

      # If color expr
      if layer.colorExpr
        # Determine all color values
        colorValues = _.uniq(_.pluck(data["layer#{layerIndex}"], "color"))

        for colorVal in colorValues
          names["layer#{layerIndex}:#{colorVal}:y"] = @mapValue(layer.colorExpr, colorVal)
      else
        names["layer#{layerIndex}:y"] = layer.name or "Series #{layerIndex+1}"

    return names

  # Gets the type of each y column
  getTypes: (design, columns) ->
    types = {}
    for column in columns
      if column[0].match(/:y$/)
        layerIndex = parseInt(column[0].match(/^layer(\d+)/)[1])
        types[column[0]] = design.layers[layerIndex].type or design.type

    return types

  getGroups: (design, columns) ->
    groups = []
    # For each layer
    for layerIndex in [0...design.layers.length]
      layer = design.layers[layerIndex]

      if layer.stacked
        group = []
        for column in columns
          if column[0].match("^layer#{layerIndex}:.*:y$")
            group.push(column[0])
        groups.push(group)

    return groups

  getXAxisType: (design) ->
    switch @exprBuilder.getExprType(design.layers[0].xExpr)
      when "text", "enum", "boolean" then "category"
      when "date" then "timeseries"
      else "indexed"

  # Given series id and index, find layerIndex and dataIndex
  lookupDataPoint: (data, columns, seriesId, index) ->
    # Get layer # from series. 
    # Then search in columns to get x value (if there is one) and y value
    # If extra colon, get color string
    # Get data to search for index of row by x and color

    layerIndex = parseInt(seriesId.match(/^layer(\d+)/)[1])

    # Find x value
    xColumnId = seriesId.replace(/:y$/, ":x")
    xColumn = _.find(columns, (c) -> c[0] == xColumnId)
    if xColumn
      # Find x value
      x = xColumn[index + 1]

    # Find y value
    y = _.find(columns, (c) -> c[0] == seriesId)[index + 1]

    # Find color string
    match = seriesId.match(/^layer\d+:(.*):y$/)
    if match
      colorStr = match[1]

    # Find data point index
    dataIndex = _.findIndex(data["layer#{layerIndex}"], (row) =>
      if xColumn and row.x != x
        return false
      if colorStr? and "#{row.color}" != colorStr
        return false
      if row.y != y
        return false

      return true
      )

    if dataIndex >= 0
      return { layerIndex: layerIndex, dataIndex: dataIndex }

    return null

  # Create a filter expression based on a row of a layer
  createScopeFilter: (design, layerIndex, row) ->
    expressionBuilder = new ExpressionBuilder(@schema)

    # Get layer
    layer = design.layers[layerIndex]

    filters = []
    
    # If x
    if layer.xExpr
      filters.push({ 
        type: "comparison"
        table: layer.table
        lhs: layer.xExpr
        op: "="
        rhs: { type: "literal", valueType: expressionBuilder.getExprType(layer.xExpr), value: row.x } 
      })

    if layer.colorExpr
      filters.push({ 
        type: "comparison"
        table: layer.table
        lhs: layer.colorExpr
        op: "="
        rhs: { type: "literal", valueType: expressionBuilder.getExprType(layer.colorExpr), value: row.color } 
      })

    if filters.length > 1
      return {
        type: "logical"
        table: layer.table
        op: "and"
        exprs: filters
      }
    else
      return filters[0]
