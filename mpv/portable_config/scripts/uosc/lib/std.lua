--[[ Stateless utilities missing in lua standard library ]]

---@param number number
function round(number) return math.floor(number + 0.5) end

---@param min number
---@param value number
---@param max number
function clamp(min, value, max) return math.max(min, math.min(value, max)) end

---@param rgba string `rrggbb` or `rrggbbaa` hex string.
function serialize_rgba(rgba)
	local a = rgba:sub(7, 8)
	return {
		color = rgba:sub(5, 6) .. rgba:sub(3, 4) .. rgba:sub(1, 2),
		opacity = clamp(0, tonumber(#a == 2 and a or 'ff', 16) / 255, 1),
	}
end

-- Trim any `char` from the end of the string.
---@param str string
---@param char string
---@return string
function trim_end(str, char)
	local char, end_i = char:byte(), 0
	for i = #str, 1, -1 do
		if str:byte(i) ~= char then
			end_i = i
			break
		end
	end
	return str:sub(1, end_i)
end

---@param str string
---@param pattern string
---@return string[]
function split(str, pattern)
	local list = {}
	local full_pattern = '(.-)' .. pattern
	local last_end = 1
	local start_index, end_index, capture = str:find(full_pattern, 1)
	while start_index do
		list[#list + 1] = capture
		last_end = end_index + 1
		start_index, end_index, capture = str:find(full_pattern, last_end)
	end
	if last_end <= (#str + 1) then
		capture = str:sub(last_end)
		list[#list + 1] = capture
	end
	return list
end

-- Get index of the last appearance of `sub` in `str`.
---@param str string
---@param sub string
---@return integer|nil
function string_last_index_of(str, sub)
	local sub_length = #sub
	for i = #str, 1, -1 do
		for j = 1, sub_length do
			if str:byte(i + j - 1) ~= sub:byte(j) then break end
			if j == sub_length then return i end
		end
	end
end

---@param itable table
---@param value any
---@return integer|nil
function itable_index_of(itable, value)
	for index, item in ipairs(itable) do
		if item == value then return index end
	end
end

---@param itable table
---@param value any
---@return boolean
function itable_has(itable, value)
	return itable_index_of(itable, value) ~= nil
end

---@param itable table
---@param compare fun(value: any, index: number)
---@param from? number Where to start search, defaults to `1`.
---@param to? number Where to end search, defaults to `#itable`.
---@return number|nil index
---@return any|nil value
function itable_find(itable, compare, from, to)
	from, to = from or 1, to or #itable
	for index = from, to, from < to and 1 or -1 do
		if index > 0 and index <= #itable and compare(itable[index], index) then
			return index, itable[index]
		end
	end
end

---@param itable table
---@param decider fun(value: any, index: number)
function itable_filter(itable, decider)
	local filtered = {}
	for index, value in ipairs(itable) do
		if decider(value, index) then filtered[#filtered + 1] = value end
	end
	return filtered
end

---@param itable table
---@param value any
function itable_delete_value(itable, value)
	for index = 1, #itable, 1 do
		if itable[index] == value then table.remove(itable, index) end
	end
	return itable
end

---@param itable table
---@param transformer fun(value: any, index: number) : any
function itable_map(itable, transformer)
	local result = {}
	for index, value in ipairs(itable) do
		result[index] = transformer(value, index)
	end
	return result
end

---@param itable table
---@param start_pos? integer
---@param end_pos? integer
function itable_slice(itable, start_pos, end_pos)
	start_pos = start_pos and start_pos or 1
	end_pos = end_pos and end_pos or #itable

	if end_pos < 0 then end_pos = #itable + end_pos + 1 end
	if start_pos < 0 then start_pos = #itable + start_pos + 1 end

	local new_table = {}
	for index, value in ipairs(itable) do
		if index >= start_pos and index <= end_pos then
			new_table[#new_table + 1] = value
		end
	end
	return new_table
end

---@generic T
---@param a T[]|nil
---@param b T[]|nil
---@return T[]
function itable_join(a, b)
	local result = {}
	if a then for _, value in ipairs(a) do result[#result + 1] = value end end
	if b then for _, value in ipairs(b) do result[#result + 1] = value end end
	return result
end

---@param target any[]
---@param source any[]
function itable_append(target, source)
	for _, value in ipairs(source) do target[#target + 1] = value end
	return target
end

---@param target any[]
---@param source any[]
---@param props? string[]
function table_assign(target, source, props)
	if props then
		for _, name in ipairs(props) do target[name] = source[name] end
	else
		for prop, value in pairs(source) do target[prop] = value end
	end
	return target
end

---@generic T
---@param table T
---@return T
function table_shallow_copy(table)
	local result = {}
	for key, value in pairs(table) do result[key] = value end
	return result
end

--[[ EASING FUNCTIONS ]]

function ease_out_quart(x) return 1 - ((1 - x) ^ 4) end
function ease_out_sext(x) return 1 - ((1 - x) ^ 6) end

--[[ CLASSES ]]

---@class Class
Class = {}
function Class:new(...)
	local object = setmetatable({}, {__index = self})
	object:init(...)
	return object
end
function Class:init() end
function Class:destroy() end

function class(parent) return setmetatable({}, {__index = parent or Class}) end

---@class CircularBuffer<T> : Class
CircularBuffer = class()

function CircularBuffer:new(max_size) return Class.new(self, max_size) --[[@as CircularBuffer]] end
function CircularBuffer:init(max_size)
	self.max_size = max_size
	self.size = 0
	self.pos = 0
	self.data = {}
end

function CircularBuffer:insert(item)
	self.pos = self.pos % self.max_size + 1
	self.data[self.pos] = item
	if self.size < self.max_size then self.size = self.size + 1 end
end

function CircularBuffer:get(i)
	return i <= self.size and self.data[(self.pos + i - 1) % self.size + 1] or nil
end

local function iter(self, i)
	if i == self.size then return nil end
	i = i + 1
	return i, self:get(i)
end

function CircularBuffer:iter()
	return iter, self, 0
end

local function iter_rev(self, i)
	if i == 1 then return nil end
	i = i - 1
	return i, self:get(i)
end

function CircularBuffer:iter_rev()
	return iter_rev, self, self.size + 1
end

function CircularBuffer:head()
	return self.data[self.pos]
end

function CircularBuffer:tail()
	if self.size < 1 then return nil end
	return self.data[self.pos % self.size + 1]
end

function CircularBuffer:clear()
	for i = self.size, 1, -1 do self.data[i] = nil end
	self.size = 0
	self.pos = 0
end
