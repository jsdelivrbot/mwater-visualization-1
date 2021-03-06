PropTypes = require('prop-types')
React = require 'react'
H = React.DOM
R = React.createElement

DragSourceComponent = require('../DragSourceComponent')("block-move")

# Item in a palette that can be dragged to add a widget or other item
module.exports = class PaletteItemComponent extends React.Component
  @propTypes:
    createItem: PropTypes.func.isRequired   # Create the drag item
    title: PropTypes.any
    subtitle: PropTypes.any

  render: ->
    R DragSourceComponent, 
      createDragItem: @props.createItem,
        H.div className: "mwater-visualization-palette-item",
          H.div className: "title", key: "title",
            @props.title
          H.div className: "subtitle", key: "subtitle",
            @props.subtitle
