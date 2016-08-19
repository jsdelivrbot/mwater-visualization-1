_ = require 'lodash'
LayerFactory = require './LayerFactory'
injectTableAlias = require('mwater-expressions').injectTableAlias
MapDataSource = require './MapDataSource'
DirectWidgetDataSource = require '../widgets/DirectWidgetDataSource'
BlocksLayoutManager = require '../layouts/blocks/BlocksLayoutManager'
WidgetFactory = require '../widgets/WidgetFactory'

module.exports = class DirectMapDataSource extends MapDataSource
  # Create map url source that uses direct jsonql maps
  # options:
  #   schema: schema to use
  #   dataSource: general data source
  #   design: design of entire map
  #   apiUrl: API url to use for talking to mWater server
  #   client: client id to use for talking to mWater server
  constructor: (options) ->
    @options = options

  # Gets the data source for a layer
  getLayerDataSource: (layerId) ->
    new DirectLayerDataSource(_.extend({}, @options, layerId: layerId))

class DirectLayerDataSource
  # Create map url source that uses direct jsonql maps
  # options:
  #   schema: schema to use
  #   dataSource: general data source
  #   design: design of entire map
  #   layerId: id of layer
  #   apiUrl: API url to use for talking to mWater server
  #   client: client id to use for talking to mWater server
  constructor: (options) ->
    @options = options

  # Get the url for the image tiles with the specified filters applied
  # Called with (filters) where filters are filters to apply. Returns URL
  getTileUrl: (filters) -> 
    # Get layerView
    layerView = _.findWhere(@options.design.layerViews, { id: @options.layerId })
    if not layerView
      return null

    # Create layer
    layer = LayerFactory.createLayer(layerView.type)

    # Clean design (prevent ever displaying invalid/legacy designs)
    design = layer.cleanDesign(layerView.design, @options.schema)

    # Ignore if invalid
    if layer.validateDesign(design, @options.schema)
      return null

    # Handle special cases
    if layerView.type == "MWaterServer"
      return @createLegacyUrl(design, "png", filters)
    if layerView.type == "TileUrl"
      return design.tileUrl

    # Get JsonQLCss
    jsonqlCss = layer.getJsonQLCss(design, @options.schema, filters)

    return @createUrl("png", jsonqlCss) 

  # Get the url for the interactivity tiles with the specified filters applied
  # Called with (filters) where filters are filters to apply. Returns URL
  getUtfGridUrl: (filters) -> 
    # Get layerView
    layerView = _.findWhere(@options.design.layerViews, { id: @options.layerId })
    if not layerView
      return null

    # Create layer
    layer = LayerFactory.createLayer(layerView.type)

    # Clean design (prevent ever displaying invalid/legacy designs)
    design = layer.cleanDesign(layerView.design, @options.schema)

    # Ignore if invalid
    if layer.validateDesign(design, @options.schema)
      return null

    # Handle special cases
    if layerView.type == "MWaterServer"
      return @createLegacyUrl(design, "grid.json", filters)
    if layerView.type == "TileUrl"
      return null

    # Get JsonQLCss
    jsonqlCss = layer.getJsonQLCss(design, @options.schema, filters)

    return @createUrl("grid.json", jsonqlCss) 

  # Gets widget data source for a popup widget
  getPopupWidgetDataSource: (widgetId) -> 
    # Get layerView
    layerView = _.findWhere(@options.design.layerViews, { id: @options.layerId })
    if not layerView
      return null

    # Create layer
    layer = LayerFactory.createLayer(layerView.type)

    # Clean design (prevent ever displaying invalid/legacy designs)
    design = layer.cleanDesign(layerView.design, @options.schema)

    # Get widget
    { type, design } = new BlocksLayoutManager().getWidgetTypeAndDesign(design.popup.items, widgetId)

    # Create widget
    widget = WidgetFactory.createWidget(type)

    return new DirectWidgetDataSource({
      widget: widget
      design: design
      schema: @options.schema
      dataSource: @options.dataSource
      apiUrl: @options.apiUrl
      client: @options.client
    })

  # Create query string
  createUrl: (extension, jsonqlCss) ->
    query = "type=jsonql"
    if @options.client
      query += "&client=" + @options.client

    query += "&design=" + encodeURIComponent(JSON.stringify(jsonqlCss))

    url = "#{@options.apiUrl}maps/tiles/{z}/{x}/{y}.#{extension}?" + query

    # Add subdomains: {s} will be substituted with "a", "b" or "c" in leaflet for api.mwater.co only.
    # Used to speed queries
    if url.match(/^https:\/\/api\.mwater\.co\//)
      url = url.replace(/^https:\/\/api\.mwater\.co\//, "https://{s}-api.mwater.co/")

    return url

  # Create query string
  createLegacyUrl: (design, extension, filters) ->
    url = "#{@options.apiUrl}maps/tiles/{z}/{x}/{y}.#{extension}?type=#{design.type}&radius=1000"

    # Add subdomains: {s} will be substituted with "a", "b" or "c" in leaflet for api.mwater.co only.
    # Used to speed queries
    if url.match(/^https:\/\/api\.mwater\.co\//)
      url = url.replace(/^https:\/\/api\.mwater\.co\//, "https://{s}-api.mwater.co/")

    if @client
      url += "&client=#{@options.client}"
      
    # Add where for any relevant filters
    relevantFilters = _.where(filters, table: design.table)

    # If any, create and
    whereClauses = _.map(relevantFilters, (f) => injectTableAlias(f.jsonql, "main"))

    # Wrap if multiple
    if whereClauses.length > 1
      where = { type: "op", op: "and", exprs: whereClauses }
    else
      where = whereClauses[0]

    if where 
      url += "&where=" + encodeURIComponent(JSON.stringify(where))

    return url
