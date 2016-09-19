_ = require 'lodash'
ExprCompiler = require('mwater-expressions').ExprCompiler
ExprUtils = require('mwater-expressions').ExprUtils
AxisBuilder = require '../../axes/AxisBuilder'
injectTableAlias = require('mwater-expressions').injectTableAlias


# Compiles various parts of a layered chart (line, bar, scatter, spline, area) to C3.js format
module.exports = class LayeredChartCompiler
  # Pass in schema
  constructor: (options) ->
    @schema = options.schema
    @exprUtils = new ExprUtils(@schema)
    @axisBuilder = new AxisBuilder(schema: @schema)

  # Create the queries needed for the chart.
  # extraFilters: array of filters to apply. Each is { table: table id, jsonql: jsonql condition with {alias} for tableAlias. }
  createQueries: (design, extraFilters) ->
    exprCompiler = new ExprCompiler(@schema)

    queries = {}

    # For each layer
    for layerIndex in [0...design.layers.length]
      layer = design.layers[layerIndex]

      # Create shell of query
      query = {
        type: "query"
        selects: []
        from: exprCompiler.compileTable(layer.table, "main")
        limit: 1000
        groupBy: []
        orderBy: []
      }

      if layer.axes.x
        query.selects.push({ type: "select", expr: @axisBuilder.compileAxis(axis: layer.axes.x, tableAlias: "main"), alias: "x" })
      if layer.axes.color
        query.selects.push({ type: "select", expr: @axisBuilder.compileAxis(axis: layer.axes.color, tableAlias: "main"), alias: "color" })
      if layer.axes.y
        query.selects.push({ type: "select", expr: @axisBuilder.compileAxis(axis: layer.axes.y, tableAlias: "main"), alias: "y" })

      # Sort by x and color
      if layer.axes.x or layer.axes.color
        query.orderBy.push({ ordinal: 1 })
      if layer.axes.x and layer.axes.color
        query.orderBy.push({ ordinal: 2 })

      # If grouping type
      if @doesLayerNeedGrouping(design, layerIndex)
        if layer.axes.x or layer.axes.color
          query.groupBy.push(1)

        if layer.axes.x and layer.axes.color
          query.groupBy.push(2)

      # Add where
      whereClauses = []
      if layer.filter
        whereClauses.push(@compileExpr(layer.filter))

      # Add filters
      if extraFilters and extraFilters.length > 0
        # Get relevant filters
        relevantFilters = _.where(extraFilters, table: layer.table)

        # If any, create and
        if relevantFilters.length > 0
          # Add others
          for filter in relevantFilters
            whereClauses.push(injectTableAlias(filter.jsonql, "main"))

      # Wrap if multiple
      whereClauses = _.compact(whereClauses)
      
      if whereClauses.length > 1
        query.where = { type: "op", op: "and", exprs: whereClauses }
      else
        query.where = whereClauses[0]

      queries["layer#{layerIndex}"] = query

    return queries

  # Create data map of "{layer name}" or "{layer name}:{index}" to { layerIndex, row }
  createDataMap: (design, data) ->
    return @compileData(design, data).dataMap

  # Create the chartOptions to pass to c3.generate
  # options is
  #   design: chart design element
  #   data: chart data
  #   width: chart width
  #   height: chart height
  createChartOptions: (options) ->
    titlePadding = { top: 0, right: 0, bottom: 15, left: 0 } # TODO move to CSS or make it configurable

    c3Data = @compileData(options.design, options.data)

    # Create chart
    chartDesign = {
      data: {
        types: c3Data.types
        columns: c3Data.columns
        names: c3Data.names
        types: c3Data.types
        groups: c3Data.groups
        xs: c3Data.xs
        colors: c3Data.colors
      }
      # Hide if one layer with no color axis
      legend: { hide: (options.design.layers.length == 1 and not options.design.layers[0].axes.color) }
      grid: { focus: { show: false } }  # Don't display hover grid
      axis: {
        x: {
          type: c3Data.xAxisType
          label: { text: c3Data.xAxisLabelText, position: if options.design.transpose then 'outer-middle' else 'outer-center' }
          tick: { fit: c3Data.xAxisTickFit }
        }
        y: {
          label: { text: c3Data.yAxisLabelText, position: if options.design.transpose then 'outer-center' else 'outer-middle' }
          # Set max to 100 if proportional (with no padding)
          max: if options.design.type == "bar" and options.design.proportional then 100
          padding: if options.design.type == "bar" and options.design.proportional then { top: 0, bottom: 0 }
          tick: {
            format: d3.format(",")
          }
        }
        rotated: options.design.transpose
      }
      size: { width: options.width, height: options.height }
      pie: {  expand: false } # Don't expand/contract
      title: { text: c3Data.titleText, padding: titlePadding }
      transition: { duration: 0 } # Transitions interfere with scoping
    }

    return chartDesign

  isCategoricalX: (design) ->
    # Check if categorical x axis (bar charts always are)
    categoricalX = design.type == "bar" or _.any(design.layers, (l) -> l.type == "bar")

    # Check if x axis is categorical type
    xType = @axisBuilder.getAxisType(design.layers[0].axes.x)
    if xType in ["enum", "text", "boolean"]
      categoricalX = true

    return categoricalX

  # Compiles data part of C3 chart, including data map back to original data
  # Outputs: columns, types, names, colors. Also dataMap which is a map of "layername:index" to { layerIndex, row }
  compileData: (design, data, locale) ->
    # If polar chart (no x axis)
    if design.type in ['pie', 'donut'] or _.any(design.layers, (l) -> l.type in ['pie', 'donut'])
      return @compileDataPolar(design, data, locale)

    if @isCategoricalX(design)
      return @compileDataCategorical(design, data, locale)
    else
      return @compileDataNonCategorical(design, data, locale)

  # Compiles data for a polar chart (pie/donut) with no x axis
  compileDataPolar: (design, data, locale) ->
    columns = []
    types = {}
    names = {}
    dataMap = {}
    colors = {}

    # For each layer
    _.each design.layers, (layer, layerIndex) =>
      # If has color axis
      if layer.axes.color
        # Create a series for each row
        _.each data["layer#{layerIndex}"], (row, rowIndex) =>
          series = "#{layerIndex}:#{rowIndex}"
          # Pie series contain a single value
          columns.push([series, row.y])
          types[series] = @getLayerType(design, layerIndex)
          names[series] = @axisBuilder.formatValue(layer.axes.color, row.color, locale)
          dataMap[series] = { layerIndex: layerIndex, row: row }

          # Get specific color if present
          color = @axisBuilder.getValueColor(layer.axes.color, row.color)
          #color = color or layer.color
          if color
            colors[series] = color
      else
        # Create a single series
        row = data["layer#{layerIndex}"][0]
        if row
          series = "#{layerIndex}"
          columns.push([series, row.y])
          types[series] = @getLayerType(design, layerIndex)

          # Name is name of entire layer
          names[series] = layer.name or "Series #{layerIndex+1}"
          dataMap[series] = { layerIndex: layerIndex, row: row }

          # Set color if present
          if layer.color
            colors[series] = layer.color

    return {
      columns: columns
      types: types
      names: names
      dataMap: dataMap
      colors: colors
      xAxisType: "category" # Polar charts are always category x-axis
      titleText: @compileTitleText(design, locale)
    }

  # Compiles data for a chart like line or scatter that does not have a categorical x axis
  compileDataNonCategorical: (design, data, locale) ->
    columns = []
    types = {}
    names = {}
    dataMap = {}
    colors = {}
    xs = {}

    xType = @axisBuilder.getAxisType(design.layers[0].axes.x)

    # For each layer
    _.each design.layers, (layer, layerIndex) =>
      # Get data of layer
      layerData = data["layer#{layerIndex}"]

      # If has color axis
      if layer.axes.color
        # Create a series for each color value
        colorValues = _.uniq(_.pluck(layerData, "color"))

        _.each colorValues, (colorValue) =>
          # One series for x values, one for y
          seriesX = "#{layerIndex}:#{colorValue}:x"
          seriesY = "#{layerIndex}:#{colorValue}:y"

          # Get specific color if present
          color = @axisBuilder.getValueColor(layer.axes.color, colorValue)
          color = color or layer.color
          if color
            colors[seriesY] = color

          # Get rows for this series
          rows = _.where(layerData, color: colorValue)

          yValues = _.map(_.pluck(rows, "y"), (v) -> parseFloat(v))
          if layer.cumulative
            @makeCumulative(yValues)

          columns.push([seriesY].concat(yValues))
          columns.push([seriesX].concat(_.pluck(rows, "x")))

          types[seriesY] = @getLayerType(design, layerIndex)
          names[seriesY] = @axisBuilder.formatValue(layer.axes.color, colorValue, locale)
          xs[seriesY] = seriesX

          _.each rows, (row, rowIndex) =>
            dataMap["#{seriesY}:#{rowIndex}"] = { layerIndex: layerIndex, row: row }
      else
        # One series for x values, one for y
        seriesX = "#{layerIndex}:x"
        seriesY = "#{layerIndex}:y"

        yValues = _.map(_.pluck(layerData, "y"), (v) -> parseFloat(v))
        if layer.cumulative
          @makeCumulative(yValues)

        columns.push([seriesY].concat(yValues))
        columns.push([seriesX].concat(_.pluck(layerData, "x")))

        types[seriesY] = @getLayerType(design, layerIndex)
        names[seriesY] = layer.name or "Series #{layerIndex+1}"
        xs[seriesY] = seriesX
        colors[seriesY] = layer.color

        # Add data map for each row
        _.each layerData, (row, rowIndex) =>
          dataMap["#{seriesY}:#{rowIndex}"] = { layerIndex: layerIndex, row: row }

    return {
      columns: columns
      types: types
      names: names
      dataMap: dataMap
      colors: colors
      xs: xs
      xAxisType: if (xType in ["date"]) then "timeseries" else "indexed" 
      xAxisTickFit: false   # Don't put a tick for each point
      xAxisLabelText: @compileXAxisLabelText(design, locale)
      yAxisLabelText: @compileYAxisLabelText(design, locale)
      titleText: @compileTitleText(design, locale)
    }


  # Numbers sometimes arrive as strings from database. Fix by parsing
  fixStringYValues: (rows) ->
    for row in rows
      if _.isString(row.y)
        row.y = parseFloat(row.y)
    return rows

  # Flatten if x-type is enumset. e.g. if one row has x = ["a", "b"], make into two rows with x="a" and x="b", summing if already exists
  flattenRowData: (rows) ->
    flatRows = []
    for row in rows
      # Handle null
      if not row.x 
        flatRows.push(row)
        continue

      if _.isString(row.x)
        # Handle failed parsings graciously in case question used to be a non-array
        try
          xs = JSON.parse(row.x)
        catch
          xs = row.x
      else
        xs = row.x

      for x in xs
        # Find existing row
        existingRow = _.find(flatRows, (r) -> r.x == x and r.color == row.color)
        if existingRow
          existingRow.y += row.y
        else
          flatRows.push(_.extend({}, row, x: x))

    return flatRows

  compileDataCategorical: (design, data, locale) ->
    columns = []
    types = {}
    names = {}
    dataMap = {}
    colors = {}
    xs = {}
    groups = []

    # Get all values of the x-axis, taking into account values that might be missing
    xAxis = design.layers[0].axes.x

    xType = @axisBuilder.getAxisType(xAxis)

    # Get all known values from all layers
    xValues = []
    _.each design.layers, (layer, layerIndex) =>
      # Get data of layer
      layerData = data["layer#{layerIndex}"]
      xValues = _.union(xValues, _.uniq(_.pluck(layerData, "x")))

    # Categories will be in form [{ value, label }]
    categories = @axisBuilder.getCategories(xAxis, xValues, locale)

    # Limit categories to prevent crashes in C3 (https://github.com/mWater/mwater-visualization/issues/272)
    if xType != "enumset"
      # Take last ones to make dates prettier
      categories = _.takeRight(categories, 40)
      categoryXs = _.indexBy(categories, "value")

    # Create map of category value to index
    categoryMap = _.object(_.map(categories, (c, i) -> [c.value, i]))

    # Create common x series
    columns.push(["x"].concat(_.pluck(categories, "label")))

    # For each layer
    _.each design.layers, (layer, layerIndex) =>
      # Get data of layer
      layerData = data["layer#{layerIndex}"]

      # Filter out categories that were removed
      if xType != "enumset"
        layerData = _.filter(layerData, (row) -> categoryXs[row.x]?)

      # Fix string y values
      layerData = @fixStringYValues(layerData)

      # Flatten if x-type is enumset. e.g. if one row has x = ["a", "b"], make into two rows with x="a" and x="b", summing if already exists
      if xType == "enumset"
        layerData = @flattenRowData(layerData)

      # If has color axis
      if layer.axes.color
        # Create a series for each color value
        colorValues = _.uniq(_.pluck(layerData, "color"))

        _.each colorValues, (colorValue) =>
          # One series for y values
          series = "#{layerIndex}:#{colorValue}"

          # Get specific color if present
          color = @axisBuilder.getValueColor(layer.axes.color, colorValue)
          color = color or layer.color
          if color
            colors[series] = color

          # Get rows for this series
          rows = _.where(layerData, color: colorValue)

          # Create empty series
          column = _.map(categories, (c) -> null)

          # Set rows
          _.each rows, (row) =>
            # Get index
            index = categoryMap[row.x]
            # Data arrives as string sometimes
            column[index] = if row.y then parseFloat(row.y) else null
            dataMap["#{series}:#{index}"] = { layerIndex: layerIndex, row: row }

          if layer.cumulative
            @makeCumulative(column)

          columns.push([series].concat(column))

          types[series] = @getLayerType(design, layerIndex)
          names[series] = @axisBuilder.formatValue(layer.axes.color, colorValue, locale)
          xs[series] = "x"

      else
        # One series for y
        series = "#{layerIndex}"

        # Create empty series
        column = _.map(categories, (c) -> null)

        # Set rows
        _.each layerData, (row) =>
          # Get index
          index = categoryMap[row.x]
          # Data arrives as string sometimes
          column[index] = if row.y then parseFloat(row.y) else null
          dataMap["#{series}:#{index}"] = { layerIndex: layerIndex, row: row }

        if layer.cumulative
          @makeCumulative(column)

        columns.push([series].concat(column))

        types[series] = @getLayerType(design, layerIndex)
        names[series] = layer.name or "Series #{layerIndex+1}"
        xs[series] = "x"
        colors[series] = layer.color

    # Stack by putting into groups
    if design.stacked
      groups = [_.keys(names)]

    # If proportional
    if design.proportional
      # Calculate total for each x
      xtotals = []
      for column in columns
        # Skip x column
        if column[0] == 'x'
          continue

        for i in [1...column.length]
          xtotals[i] = (xtotals[i] or 0) + (column[i] or 0)

      # Now make percentage with one decimal
      for column in columns
        # Skip x column
        if column[0] == 'x'
          continue

        for i in [1...column.length]
          if column[i] > 0
            column[i] = Math.round(100 * column[i] / xtotals[i] * 10) / 10

    return {
      columns: columns
      types: types
      names: names
      dataMap: dataMap
      colors: colors
      xs: xs
      groups: groups
      xAxisType: "category" 
      xAxisTickFit: xType != "date"   # Put a tick for each point since categorical unless date
      xAxisLabelText: @compileXAxisLabelText(design, locale)
      yAxisLabelText: @compileYAxisLabelText(design, locale)
      titleText: @compileTitleText(design, locale)
    }

  # Compile an expression
  compileExpr: (expr) ->
    exprCompiler = new ExprCompiler(@schema)
    return exprCompiler.compileExpr(expr: expr, tableAlias: "main")

  # Get layer type, defaulting to overall type
  getLayerType: (design, layerIndex) ->
    return design.layers[layerIndex].type or design.type

  # Determine if layer required grouping by x (and color)
  doesLayerNeedGrouping: (design, layerIndex) ->
    return @getLayerType(design, layerIndex) != "scatter"

  # Determine if layer can use x axis
  canLayerUseXExpr: (design, layerIndex) ->
    return @getLayerType(design, layerIndex) not in ['pie', 'donut']

  isXAxisRequired: (design, layerIndex) ->
    return @getLayerType(design, layerIndex) not in ['pie', 'donut']

  isColorAxisRequired: (design, layerIndex) ->
    return @getLayerType(design, layerIndex) in ['pie', 'donut']

  compileDefaultTitleText: (design, locale) ->
    # Don't default this for now
    return ""
    # if design.layers[0].axes.x
    #   return @compileYAxisLabelText(design) + " by " + @compileXAxisLabelText(design)
    # else
    #   return @compileYAxisLabelText(design) + " by " + @axisBuilder.summarizeAxis(design.layers[0].axes.color)

  compileDefaultYAxisLabelText: (design, locale) ->
    @axisBuilder.summarizeAxis(design.layers[0].axes.y, locale)

  compileDefaultXAxisLabelText: (design, locale) ->
    @axisBuilder.summarizeAxis(design.layers[0].axes.x, locale)

  compileTitleText: (design, locale) ->
    return design.titleText or @compileDefaultTitleText(design, locale)

  compileYAxisLabelText: (design, locale) ->
    if design.yAxisLabelText == ""
      return @compileDefaultYAxisLabelText(design, locale)
    return design.yAxisLabelText

  compileXAxisLabelText: (design, locale) ->
    if design.xAxisLabelText == ""
      return @compileDefaultXAxisLabelText(design, locale)
    return design.xAxisLabelText

  # Create a scope based on a row of a layer
  # Scope data is relevant data from row that uniquely identifies scope
  # plus a layer index
  createScope: (design, layerIndex, row, locale) ->
    expressionBuilder = new ExprUtils(@schema)

    # Get layer
    layer = design.layers[layerIndex]

    filters = []
    names = []
    data = { layerIndex: layerIndex }
    
    # If x
    if layer.axes.x
      # Handle special case of enumset which is flattened to enum type
      if @axisBuilder.getAxisType(layer.axes.x) == "enumset"
        filters.push({
          type: "op"
          op: "@>"
          exprs: [
            { type: "op", op: "::jsonb", exprs: [@axisBuilder.compileAxis(axis: layer.axes.x, tableAlias: "{alias}")] }
            { type: "op", op: "::jsonb", exprs: [JSON.stringify(row.x)] }
          ]
        })
        names.push(@axisBuilder.summarizeAxis(layer.axes.x, locale) + " includes " + @exprUtils.stringifyExprLiteral(layer.axes.x.expr, [row.x], locale))
        data.x = row.x
      else        
        filters.push(@axisBuilder.createValueFilter(layer.axes.x, row.x))
        names.push(@axisBuilder.summarizeAxis(layer.axes.x, locale) + " is " + @axisBuilder.formatValue(layer.axes.x, row.x, locale))
        data.x = row.x

    if layer.axes.color
      filters.push(@axisBuilder.createValueFilter(layer.axes.color, row.color))
      names.push(@axisBuilder.summarizeAxis(layer.axes.color, locale) + " is " + @axisBuilder.formatValue(layer.axes.color, row.color, locale))
      data.color = row.color

    if filters.length > 1
      filter = {
        table: layer.table
        jsonql: {
          type: "op"
          op: "and"
          exprs: filters
        }
      }
    else
      filter = {
        table: layer.table
        jsonql: filters[0]
      }

    scope = {
      name: ExprUtils.localizeString(@schema.getTable(layer.table).name, locale) + " " + names.join(" and ")
      filter: filter
      data: data
    }

    return scope

  # Converts an array [value, value...] to be cumulative
  makeCumulative: (column) ->
    total = 0
    for i in [0...column.length]
      total += column[i]
      column[i] = total