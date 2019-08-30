local form = {}

TEXT_WIDTH = 6
TEXT_HEIGHT = 10

--RULES OF THUMB
--it's the child's responsibility to report its own scale (_width / _height)
--it's the parent's responsibility to control the child's position (_x / _y)

local content --forward declaration
content = {
    _x = 0,
    _y = 0,
    _width = 0,
    _height = 0,

    _update_scale = function()
        error("unimplemented function '_update_scale'")
    end,
    _update_position = function()
        error("unimplemented function '_update_position'")
    end,
    
    draw = function()
        error("unimplemented function 'draw'")
    end
}

local content_meta = {__index = content}

local container_base
container_base = {
    x_align = -1,
    y_align = -1,
    width = 0,
    height = 0,
    margin  = { l = 0, u = 0, r = 0, d = 0, },
    padding = { l = 0, u = 0, r = 0, d = 0, },
    bg_color = 0x00000080,
    edge_color = 0x000000FF,

    _border = { l = 0, u = 0, r = 0, d = 0, },

    update = function(self)
        self:_update_scale()
        self:_update_position()
    end,

    _set_width = function(self, content_width)
        if self.width == 0 then
            self._width = self.margin.l + self.padding.l + content_width + self.padding.r + self.margin.r
        elseif self.width > 0 then
            self._width = self.margin.l + self.width + self.margin.r
        else
            error("width cannot be negative")
        end
    end,

    _set_height = function(self, content_height)
        if self.height == 0 then
            self._height = self.margin.u + self.padding.u + content_height + self.padding.d + self.margin.d
        elseif self.height > 0 then
            self._height = self.margin.u + self.height + self.margin.d
        else
            error("height cannot be negative")
        end
    end,

    _update_border = function(self)
        self._border = {
            l = self._x + self.margin.l,
            u = self._y + self.margin.u,
            r = self._x + self._width - self.margin.r,
            d = self._y + self._height - self.margin.d
        }
    end,

    _get_align_x = function(self, content_width)
        if self.x_align < 0 then
            return self._border.l + self.padding.l
        elseif self.x_align > 0 then
            return (self._border.r - self.padding.r) - content_width
        else
            return ((self._border.l + self.padding.l) + (self._border.r - self.padding.r) - content_width) / 2
        end
    end,

    _get_align_y = function(self, content_height)
        if self.y_align < 0 then
            return self._border.u + self.padding.u
        elseif self.y_align > 0 then
            return (self._border.d - self.padding.d) - content_height
        else
            return ((self._border.u + self.padding.u) + (self._border.d - self.padding.d) - content_height) / 2
        end
    end,

    _draw_base = function(self)
        gui.drawbox(self._border.l, self._border.u, self._border.r - 1, self._border.d - 1, self.bg_color, self.edge_color)
    end,
}
setmetatable(container_base, content_meta)
local container_base_meta = {__index = container_base}

form.container = {
    new = function()
        return setmetatable({}, {__index = form.container})
    end,

    child = false,

    _update_scale = function(self)
        local c = self.child

        local child_width = 0
        local child_height = 0
        if c then 
            c:_update_scale()
            child_width = c._width
            child_height = c._height
        end

        self:_set_width(child_width)
        self:_set_height(child_height)
    end,

    _update_position = function(self)
        self:_update_border()
        local c = self.child
        if c then
            c._x = self:_get_align_x(c._width)
            c._y = self:_get_align_y(c._height)

            c:_update_position()
        end
    end,

    draw = function(self)
        self:_draw_base()
        
        if self.child then
            self.child:draw()
        end
    end
}
setmetatable(form.container, container_base_meta)

form.stack_panel = {
    new = function()
        return setmetatable({}, {__index = form.stack_panel})
    end,

    children = {},
    _child_width_total = 0,
    _child_height_total = 0,

    update = function(self)
        self:_update_scale()
        self:_update_position()
    end,

    _update_scale = function(self)
        self._child_width_total = 0
        self._child_height_total = 0
        for _, c in ipairs(self.children) do
            c:_update_scale()
            if not self.vertical then
                self._child_width_total = self._child_width_total + c._width
                self._child_height_total = math.max(self._child_height_total, c._height)
            else
                self._child_width_total = math.max(self._child_width_total, c._width)
                self._child_height_total = self._child_height_total + c._height
            end
        end
        
        self:_set_width(self._child_width_total)
        self:_set_height(self._child_height_total)
    end,

    _update_position = function(self)
        self:_update_border()

        if not self.vertical then
            local x = self:_get_align_x(self._child_width_total)
        
            for _, c in ipairs(self.children) do
                c._x = x
                c._y = self:_get_align_y(c._height)
                c:_update_position()

                x = x + c._width
            end
        else
            local y = self:_get_align_y(self._child_height_total)
        
            for _, c in ipairs(self.children) do
                c._y = y
                c._x = self:_get_align_x(c._width)
                c:_update_position()

                y = y + c._height
            end
        end
    end,

    draw = function(self)
        self:_draw_base()

        for _, c in ipairs(self.children) do
            c:draw()
        end
    end
}
setmetatable(form.stack_panel, container_base_meta)

form.auto_grid = {
    new = function()
        return setmetatable({}, {__index = form.auto_grid})
    end,

    --vertical = false,
    binding_data = {},
    numbered = true,
    titled = true,

    _column_data = {},
    _rows = {},
    _border = { l = 0, u = 0, r = 0, d = 0, },

    add_binding = function(self, title, accessor)
        table.insert(self._column_data,{ title = title, accessor = accessor })
    end,

    update = function(self)
        self:_update_scale()
        self:_update_position()
    end,

    _update_scale = function(self)
        self._child_width_total = 0
        self._child_height_total = 0
        for _, c in ipairs(self.children) do
            c:_update_scale()
            if not self.vertical then
                self._child_width_total = self._child_width_total + c._width
                self._child_height_total = math.max(self._child_height_total, c._height)
            else
                self._child_width_total = math.max(self._child_width_total, c._width)
                self._child_height_total = self._child_height_total + c._height
            end
        end
        
        self:_set_width(self._child_width_total)
        self:_set_height(self._child_height_total)
    end,

    _update_position = function(self)
        self:_update_border()

        if not self.vertical then
            local x = self:_get_align_x(self._child_width_total)
        
            for _, c in ipairs(self.children) do
                c._x = x
                c._y = self:_get_align_y(c._height)
                c:_update_position()

                x = x + c._width
            end
        else
            local y = self:_get_align_y(self._child_height_total)
        
            for _, c in ipairs(self.children) do
                c._y = y
                c._x = self:_get_align_x(c._width)
                c:_update_position()

                y = y + c._height
            end
        end
    end,

    draw = function(self)
        self:_draw_base()

        for _, c in ipairs(self.children) do
            c:draw()
        end
    end
}
setmetatable(form.auto_grid, content_meta)

form.text = {
    new = function()
        return setmetatable({}, {__index = form.text})
    end,

    margin = { l = 2, u = 2, r = 2, d = 2, },

    _text = "",
    
    set_text = function(self, t)
        if (type(t)) ~= "string" then return end

        -- \r is evil
        t = t:gsub("\r","")
        local maxlen = 0
        local currentlen = 0
        local lines = 0
        if #t > 0 then lines = 1 end

        for i=1,#t do
            local c = t:sub(i,i)

            if c == '\n' then
                lines = lines + 1
                maxlen = math.max(maxlen, currentlen)
                currentlen = 0
            else
                currentlen = currentlen + 1
            end
        end
        maxlen = math.max(maxlen, currentlen)
        self._text = t
        self._width = maxlen * TEXT_WIDTH + self.margin.l + self.margin.r
        self._height = lines * TEXT_HEIGHT + self.margin.u + self.margin.d
    end,

    _update_scale = function() end,
    _update_position = function() end,

    draw = function(self)
        gui.drawtext(self._x + self.margin.l + 1, self._y + self.margin.u + 1, self._text)
    end
}
setmetatable(form.text, content_meta)

return form