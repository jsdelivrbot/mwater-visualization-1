var ActionCancelModalComponent, ExprComponent, ExprInsertModalComponent, ExprUtils, H, R, React, TableSelectComponent,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

React = require('react');

H = React.DOM;

R = React.createElement;

ExprUtils = require("mwater-expressions").ExprUtils;

ExprComponent = require("mwater-expressions-ui").ExprComponent;

ActionCancelModalComponent = require("react-library/lib/ActionCancelModalComponent");

TableSelectComponent = require('../../TableSelectComponent');

module.exports = ExprInsertModalComponent = (function(superClass) {
  extend(ExprInsertModalComponent, superClass);

  ExprInsertModalComponent.propTypes = {
    schema: React.PropTypes.object.isRequired,
    dataSource: React.PropTypes.object.isRequired,
    onInsert: React.PropTypes.func.isRequired
  };

  function ExprInsertModalComponent() {
    this.handleInsert = bind(this.handleInsert, this);
    this.handleTableChange = bind(this.handleTableChange, this);
    ExprInsertModalComponent.__super__.constructor.apply(this, arguments);
    this.state = {
      open: false,
      expr: null,
      table: null,
      includeLabel: true
    };
  }

  ExprInsertModalComponent.prototype.open = function() {
    return this.setState({
      open: true,
      expr: null
    });
  };

  ExprInsertModalComponent.prototype.handleTableChange = function(table) {
    return this.setState({
      table: table
    });
  };

  ExprInsertModalComponent.prototype.handleInsert = function(ev) {
    if (!this.state.expr) {
      return;
    }
    return this.setState({
      open: false
    }, (function(_this) {
      return function() {
        var label;
        label = new ExprUtils(_this.props.schema).summarizeExpr(_this.state.expr);
        return _this.props.onInsert(_this.state.expr, _this.state.includeLabel ? label : void 0);
      };
    })(this));
  };

  ExprInsertModalComponent.prototype.renderContents = function() {
    return H.div({
      className: "form-group"
    }, H.label({
      className: "text-muted"
    }, H.i({
      className: "fa fa-database"
    }), " ", "Data Source"), ": ", R(TableSelectComponent, {
      schema: this.props.schema,
      value: this.state.table,
      onChange: this.handleTableChange
    }), this.state.table ? H.div({
      className: "form-group"
    }, H.label({
      className: "text-muted"
    }, "Field"), ": ", R(ExprComponent, {
      schema: this.props.schema,
      dataSource: this.props.dataSource,
      table: this.state.table,
      types: ['text', 'number', 'enum', 'date', 'datetime', 'boolean'],
      value: this.state.expr,
      aggrStatuses: ["literal", "aggregate"],
      onChange: (function(_this) {
        return function(expr) {
          return _this.setState({
            expr: expr
          });
        };
      })(this)
    })) : void 0, this.state.table ? H.label({
      key: "includeLabel"
    }, H.input({
      type: "checkbox",
      checked: this.state.includeLabel,
      onChange: (function(_this) {
        return function(ev) {
          return _this.setState({
            includeLabel: ev.target.checked
          });
        };
      })(this)
    }), " Include Label") : void 0);
  };

  ExprInsertModalComponent.prototype.render = function() {
    if (!this.state.open) {
      return null;
    }
    return R(ActionCancelModalComponent, {
      size: "large",
      actionLabel: "Insert",
      onAction: this.handleInsert,
      onCancel: (function(_this) {
        return function() {
          return _this.setState({
            open: false
          });
        };
      })(this),
      title: "Insert Field"
    }, this.renderContents());
  };

  return ExprInsertModalComponent;

})(React.Component);