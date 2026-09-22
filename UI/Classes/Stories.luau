--!strict
--!optimize 2
const Widget = require(script.Parent.Parent.Types.Widget)
const Logging = require(script.Parent.Parent.Utils.Logging)
const Space = require(script.Parent.Space)
-- Support for UILabs stories

local logger = Logging.getLogger("PeanutUI.Classes.Stories")
local Stories = {}

--- Makes simple story out of component
---
--- Should be used with UILabs or Flipbook.
---
--- @parameter fn Function that creates widget (or Component widget from defineComponent)
local function makeStory(fn: (...any) -> any)
    return function(target: Frame)
        local space = Space.createStorySpace(target)

        local widget = fn() :: Widget.BaseInterface

        if not widget then
            logger.warn("Widget was nil, so it may not be visible")
        elseif typeof(widget) ~= "table" or typeof(widget.isImplemented) ~= "function" then
            logger.warn("Widget has unexpected structure, so it may not be visible")
        elseif not widget.isImplemented("setParent") then
            logger.warn("Widget doesn't support parenting, so it may not be visible")
        else
            widget.setParent(space)
        end

        return function()
            space.destroy()
        end
    end
end

Stories.makeStory = makeStory

return Stories