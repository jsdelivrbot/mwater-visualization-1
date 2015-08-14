React = require 'react'
H = React.DOM

DashboardViewComponent = require './DashboardViewComponent'
DashboardDesignerComponent = require './DashboardDesignerComponent'
AutoSizeComponent = require './../AutoSizeComponent'

# Dashboard component that includes the designer, viewer and an action bar at the top
# Manages selected component and designer visible state
module.exports = class DashboardComponent extends React.Component
  @propTypes:
    design: React.PropTypes.object.isRequired
    onDesignChange: React.PropTypes.func.isRequired
    widgetFactory: React.PropTypes.object.isRequired
    initialIsDesigning: React.PropTypes.bool.isRequired

  constructor: (props) ->
    super
    @state = { 
      selectedWidgetId: null
      isDesigning: props.initialIsDesigning
    }

  handleSelectedWidgetIdChange: (selectedWidgetId) =>
    @setState(selectedWidgetId: selectedWidgetId)

  handlePrint: =>
    @refs.dashboardViewContainer.getChild().print()

  handleToggleDesigning: =>
    @setState(isDesigning: not @state.isDesigning)    

  renderActionLinks: ->
    H.div style: { textAlign: "right", position: "absolute", top: 0, right: 20 },
      H.a className: "btn btn-link btn-sm", onClick: @handleToggleDesigning,
        H.span(className: "glyphicon glyphicon-pencil")
        if @state.isDesigning then " Close Editor" else " Edit"
      H.a className: "btn btn-link btn-sm", onClick: @handlePrint,
        H.span(className: "glyphicon glyphicon-print")
        " Print"

  renderView: ->
    H.div key: "view", style: { height: "100%", overflowY: "auto", paddingTop: 30, paddingRight: 20, paddingLeft: 5, position: "relative" },
      @renderActionLinks()
      # Dashboard view requires width, so use auto size component to inject it
      React.createElement(AutoSizeComponent, { injectWidth: true, ref: "dashboardViewContainer" }, 
        React.createElement(DashboardViewComponent, {
          design: @props.design
          onDesignChange: @props.onDesignChange
          selectedWidgetId: @state.selectedWidgetId
          onSelectedWidgetIdChange: @handleSelectedWidgetIdChange
          isDesigning: @state.isDesigning
          onIsDesigningChange: null # TODO 
          widgetFactory: @props.widgetFactory
        })
      )

  renderDesigner: ->
    React.createElement(DashboardDesignerComponent, {
      key: "designer"
      design: @props.design
      onDesignChange: @props.onDesignChange
      selectedWidgetId: @state.selectedWidgetId
      onSelectedWidgetIdChange: @handleSelectedWidgetIdChange
      isDesigning: true # TODO keep this?
      onIsDesigningChange: null # TODO
      widgetFactory: @props.widgetFactory
    })

  render: ->
    if @state.isDesigning
      H.div className: "row", style: { height: "100%" },
        H.div className: "col-xs-8", style: { padding: 0, height: "100%" },
          @renderView()

        # Put a nice border to the left
        H.div className: "col-xs-4", style: { borderLeft: "solid 3px #AAA", height: "100%", paddingTop: 10, overflow: "auto" },
          @renderDesigner()
    else
      H.div className: "row", style: { height: "100%" },
        @renderView()