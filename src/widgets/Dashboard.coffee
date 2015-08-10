React = require 'react'
H = React.DOM

DashboardViewComponent = require './DashboardViewComponent'
DashboardDesignerComponent = require './DashboardDesignerComponent'
AutoSizeComponent = require './../AutoSizeComponent'

# Top-level class which holds design of dashboard as state, the undo/redo stack and the DOM elements
# to render the view and optionally the designer
module.exports = class Dashboard
  # Pass in
  # design: Dashboard design
  # viewNode: DOM node to show dashboard view in
  # isDesigning: initial designing state. True to show designer
  # onShowDesigner: called to show the designer pane, returns DOM node
  # onHideDesigner: called to hide the designer pane
  # onDesignChange: called when design is changed (optional). Should save dashboard if desired
  # widgetFactory: WidgetFactory to use
  constructor: (options) ->
    @design = options.design
    @viewNode = options.viewNode
    @isDesigning = options.isDesigning
    @onShowDesigner = options.onShowDesigner
    @onHideDesigner = options.onHideDesigner
    @onDesignChange = options.onDesignChange
    @widgetFactory = options.widgetFactory

    # Currently selected widget starts as none
    @selectedWidgetId = null

    # Show designer if designing
    if @isDesigning
      @designerNode = @onShowDesigner()

  handleSelectedWidgetIdChange: (id) =>
    @selectedWidgetId = id
    @render()

  handleDesignChange: (design) =>
    @design = design
    if @onDesignChange
      @onDesignChange(design)
    @render()

  handleIsDesigningChange: (isDesigning) =>
    @isDesigning = isDesigning
    
    # Remove designer if now false
    if not @isDesigning and @designerNode
      React.unmountComponentAtNode(@designerNode)
      @designerNode = null
      @onHideDesigner()

    # Show designer if needed
    if @isDesigning and not @designerNode
      @designerNode = @onShowDesigner()      

    @render()

  # Renders components
  render: ->
    # Create elements
    viewElem = React.createElement(PrintableDashboard, {},
      React.createElement(AutoSizeComponent, { injectWidth: true }, 
        React.createElement(DashboardViewComponent, {
          design: @design
          onDesignChange: @handleDesignChange
          selectedWidgetId: @selectedWidgetId
          onSelectedWidgetIdChange: @handleSelectedWidgetIdChange
          isDesigning: @isDesigning
          onIsDesigningChange: @handleIsDesigningChange
          widgetFactory: @widgetFactory
        })
      )
    )

    React.render(viewElem, @viewNode)

    if @isDesigning
      designerElem = React.createElement(DashboardDesignerComponent, {
        design: @design
        onDesignChange: @handleDesignChange
        selectedWidgetId: @selectedWidgetId
        onSelectedWidgetIdChange: @handleSelectedWidgetIdChange
        isDesigning: @isDesigning
        onIsDesigningChange: @handleIsDesigningChange
        widgetFactory: @widgetFactory
        })
      React.render(designerElem, @designerNode)

  destroy: ->
    if @viewNode
      React.unmountComponentAtNode(@viewNode)

    if @designerNode
      React.unmountComponentAtNode(@designerNode)

# TODO REMOVE
class PrintableDashboard extends React.Component 
  render: ->
    # TODO REMOVE
    return H.div null,
      H.button type: "button", className: "btn btn-link", onClick: (=> @refs.view.callChild("print")),
        "Print"
      React.cloneElement(React.Children.only(@props.children), ref: "view")
