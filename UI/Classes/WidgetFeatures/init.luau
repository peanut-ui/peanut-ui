--!strict
--!optimize 2
const Widget = require(script.Parent.Parent.Types.Widget)
const Logging = require(script.Parent.Parent.Utils.Logging)

local Module = {}

function Module.requireFeature(logger: Logging.Instance, widget: Widget.WidgetLike, feature: string)
    if not widget.isImplemented(feature, true) then
        logger.error("Feature %s is required", feature)
    end
end

function Module.requireField(logger: Logging.Instance, widget: Widget.WidgetLike, field: string)
    if not widget.isImplemented(field) then
        logger.error("Field %s has to be implemented", field)
    end
end

return Module