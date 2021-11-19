-- ****************************************************************************
-- Config object
-- ****************************************************************************
local Config = {}

function Config:new(data)
    data = data or {}
    setmetatable(data, self)
    self.__index = self
    self.extensions = self.extensions or {}
    return data
end

function Config:ext_config(ext_name, default)
    return self.extensions[ext_name] or default
end

return Config
