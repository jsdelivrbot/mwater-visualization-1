_ = require 'lodash'
React = require 'react'
H = React.DOM
R = React.createElement
uuid = require 'node-uuid'

LayoutManager = require '../LayoutManager'

module.exports = class BlocksLayoutManager extends LayoutManager
  # Renders the layout as a react element
  # options:
  #  width: width of layout (ignored here) TODO use for printing? standardWidth?
  #  items: opaque items object that layout manager understands
  #  onItemsChange: Called when items changes
  #  renderWidget: called with ({ id:, type:, design:, onDesignChange:, width:, height:  })
  #  style: style to use for layout. null for default
  #  disableMaps: true to disable maps
  renderLayout: (options) ->
    BlocksDisplayComponent = require './BlocksDisplayComponent'
    return R BlocksDisplayComponent,
      items: options.items or { id: "root", type: "root", blocks: [] }
      onItemsChange: options.onItemsChange
      style: options.style
      renderWidget: options.renderWidget
      disableMaps: options.disableMaps

  # Tests if dashboard has any items
  isEmpty: (items) ->
    return not items or items.blocks?.length == 0

  # Gets { type, design } of a widget
  getWidgetTypeAndDesign: (items, widgetId) -> 
    if items.type == "widget" and items.id == widgetId
      return { type: items.widgetType, design: items.design }

    if items.blocks
      for block in items.blocks
        value = @getWidgetTypeAndDesign(block, widgetId)
        if value
          return value
        
    return null
