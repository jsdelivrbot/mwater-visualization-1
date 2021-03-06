var $;

exports.CachingDataSource = require('./CachingDataSource');

exports.WidgetFactory = require('./widgets/WidgetFactory');

exports.UndoStack = require('./UndoStack');

exports.DashboardComponent = require('./dashboards/DashboardComponent');

exports.DashboardViewComponent = require('./dashboards/DashboardViewComponent');

exports.BingLayer = require('./maps/BingLayer');

exports.UtfGridLayer = require('./maps/UtfGridLayer');

exports.LeafletMapComponent = require('./maps/LeafletMapComponent');

exports.LayerFactory = require('./maps/LayerFactory');

exports.MapViewComponent = require('./maps/MapViewComponent');

exports.MapDesignerComponent = require('./maps/MapDesignerComponent');

exports.MapComponent = require('./maps/MapComponent');

exports.VerticalLayoutComponent = require('./VerticalLayoutComponent');

exports.RadioButtonComponent = require('./RadioButtonComponent');

exports.CheckboxComponent = require('./CheckboxComponent');

exports.mWaterLoader = require('./mWaterLoader');

exports.MWaterLoaderComponent = require('./MWaterLoaderComponent');

exports.LayeredChart = require('./widgets/charts/layered/LayeredChart');

exports.TableChart = require('./widgets/charts/table/TableChart');

exports.CalendarChart = require('./widgets/charts/calendar/CalendarChart');

exports.ImageMosaicChart = require('./widgets/charts/imagemosaic/ImageMosaicChart');

exports.ChartViewComponent = require('./widgets/charts/ChartViewComponent');

exports.WidgetScoper = require('./widgets/WidgetScoper');

exports.WidgetScopesViewComponent = require('./widgets/WidgetScopesViewComponent');

exports.TableSelectComponent = require('./TableSelectComponent');

exports.AxisBuilder = require('./axes/AxisBuilder');

exports.ColorSchemeFactory = require('./ColorSchemeFactory');

exports.DatagridComponent = require('./datagrids/DatagridComponent');

exports.DatagridViewComponent = require('./datagrids/DatagridViewComponent');

exports.DatagridUtils = require('./datagrids/DatagridUtils');

exports.ServerDashboardDataSource = require('./dashboards/ServerDashboardDataSource');

exports.DirectDashboardDataSource = require('./dashboards/DirectDashboardDataSource');

exports.DirectWidgetDataSource = require('./widgets/DirectWidgetDataSource');

exports.ServerMapDataSource = require('./maps/ServerMapDataSource');

exports.DirectMapDataSource = require('./maps/DirectMapDataSource');

exports.ServerDatagridDataSource = require('./datagrids/ServerDatagridDataSource');

exports.DirectDatagridDataSource = require('./datagrids/DirectDatagridDataSource');

exports.LabeledExprGenerator = require('./datagrids/LabeledExprGenerator');

exports.LayoutManager = require('./layouts/LayoutManager');

exports.RegionSelectComponent = require('./maps/RegionSelectComponent');

exports.DetailLevelSelectComponent = require('./maps/DetailLevelSelectComponent');

exports.MarkerSymbolSelectComponent = require('./maps/MarkerSymbolSelectComponent');

exports.AxisColorEditorComponent = require('./axes/AxisColorEditorComponent');

exports.RichTextComponent = require('./richtext/RichTextComponent');

exports.ItemsHtmlConverter = require('./richtext/ItemsHtmlConverter');

exports.DropdownWidgetComponent = require('./widgets/DropdownWidgetComponent');

exports.QuickfilterCompiler = require('./quickfilter/QuickfilterCompiler');

exports.DateRangeComponent = require('./DateRangeComponent');

require('./pathseg-polyfill.js');

$ = require('jquery');


$(document).on('show.bs.modal', '.modal', function () {
    var zIndex = 1040 + (10 * $('.modal:visible').length);
    $(this).css('z-index', zIndex);
    setTimeout(function() {
        $('.modal-backdrop').not('.modal-stack').css('z-index', zIndex - 1).addClass('modal-stack');
    }, 0);
});
$(document).on('hidden.bs.modal', '.modal', function () {
    $('.modal:visible').length && $(document.body).addClass('modal-open');
});
;
