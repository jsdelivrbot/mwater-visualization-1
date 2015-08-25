React = require 'react'
H = React.DOM
_ = require 'lodash'
Draggable = require 'react-draggable'

module.exports = class FloatingWindowComponent extends React.Component
  @propTypes:
    initialBounds: React.PropTypes.object.isRequired  # x, y, width, height
    title: React.PropTypes.string
    onClose: React.PropTypes.func  # Called to close window

  # Reset drag if initial bounds change
  componentWillReceiveProps: (nextProps) ->
    if not _.isEqual(nextProps.initialBounds, @props.initialBounds)
      @refs.draggable.resetState()

  renderHeader: ->
    headerStyle = {
      height: 30
      backgroundColor: "#DDD"
      padding: 5
      textAlign: "center"
      borderBottom: "solid 1px #AAA"
      borderTopLeftRadius: 10
      borderTopRightRadius: 10
      fontWeight: "bold"
    }

    closeStyle = {
      position: "absolute"
      right: 8
      top: 6
      color: "#888"
    }

    H.div style: headerStyle, className: "floating-window-header",
      if @props.onClose
        H.div style: closeStyle, onClick: @props.onClose,
          H.span className: "glyphicon glyphicon-remove"
      @props.title
    

  render: ->
    windowStyle = {
      width: @props.initialBounds.width
      height: @props.initialBounds.height
      borderRadius: 10
      border: "solid 1px #aaa"
      backgroundColor: "#FFF"
      boxShadow: "5px 5px 12px 0px rgba(0,0,0,0.5)"
      position: "absolute"
      left: @props.initialBounds.x
      top: @props.initialBounds.y
    }

    contentsStyle = {
      overflowY: "auto"
      padding: 10  
      height: @props.initialBounds.height - 35
    }

    React.createElement(Draggable, ref: "draggable", handle: ".floating-window-header",
      H.div style: windowStyle,
        @renderHeader()
        H.div style: contentsStyle,
          @props.children
    )