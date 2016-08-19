_ = require 'lodash'
querystring = require 'querystring'
MapDataSource = require './MapDataSource'
LayerFactory = require './LayerFactory'
injectTableAlias = require('mwater-expressions').injectTableAlias

# Get map urls for map stored on server
module.exports = class ServerMapDataSource extends MapDataSource
  # Create map url source that uses map design stored on server
  # options:
  #   apiUrl: API url to use for talking to mWater server
  #   client: client id to use for talking to mWater server
  #   design: design of entire map
  #   schema: schema to use
  #   share: share id to use for talking to mWater server
  #   mapId: map id to use on server
  constructor: (options) ->
    @options = options

  # Gets the data source for a layer
  getLayerDataSource: (layerId) ->
    return new ServerLayerDataSource(_.extend({}, @options, layerId: layerId))

class ServerLayerDataSource
  # Create map url source that uses map design stored on server
  # options:
  #   apiUrl: API url to use for talking to mWater server
  #   client: client id to use for talking to mWater server
  #   design: design of entire map
  #   schema: schema to use
  #   share: share id to use for talking to mWater server
  #   mapId: map id to use on server
  #   layerId: layer id to use on server
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

    return @createUrl(layerId, filters, "png") 

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

    return @createUrl(layerId, filters, "grid.json") 

  # Gets widget data source for a popup widget
  getPopupWidgetDataSource: (widgetId) -> 
    return new ServerMapLayerPopupWidgetDataSource({
      apiUrl: @options.apiUrl
      client: @options.client
      share: @options.share
      mapId: @options.mapId
      layerId: @options.layerId
      popupWidgetId: widgetId
    })

  createUrl: (layerId, filters, extension) ->
    query = {
      type: "maps"
      client: @options.client
      share: @options.share
      map: @options.mapId
      layer: @options.layerId
      filters: JSON.stringify(filters or [])
    }

    url = "#{@options.apiUrl}maps/tiles/{z}/{x}/{y}.#{extension}?" + querystring.stringify(query)

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

    if @options.client
      url += "&client=#{@options.client}"

    if @options.share
      url += "&share=#{@options.share}"
      
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

class ServerMapLayerPopupWidgetDataSource
  # options:
  #   apiUrl: API url to use for talking to mWater server
  #   client: client id to use for talking to mWater server
  #   share: share id to use for talking to mWater server
  #   mapId: map id to use on server
  #   layerId: layer id to use
  #   popupWidgetId: id of popup widget
  constructor: (options) ->
    @options = options

  # Get the data that the widget needs. The widget should implement getData method (see above) to get the actual data on the server
  #  filters: array of filters to apply. Each is { table: table id, jsonql: jsonql condition with {alias} for tableAlias. Use injectAlias to correct
  #  callback: (error, data)
  getData: (filters, callback) ->
    query = {
      client: @options.client
      share: @options.share
      filters: JSON.stringify(filters)
    }

    url = @options.apiUrl + "maps/#{@options.mapId}/layer/#{@options.layerId}/widgets/#{@options.popupWidgetId}/data?" + querystring.stringify(query)

    $.getJSON url, (data) =>
      callback(null, data)
    .fail (xhr) =>
      console.log xhr.responseText
      callback(new Error(xhr.responseText))

  # Get the url to download an image (by id from an image or imagelist column)
  # Height, if specified, is minimum height needed. May return larger image
  getImageUrl: (imageId, height) ->
    url = @options.apiUrl + "images/#{imageId}"
    if height
      url += "?h=#{height}"

    return url
  