print(package.path)

local function tprint(tbl, indent)
	if not indent then
		indent = 0
	end
	local toprint = string.rep(" ", indent) .. "{\r\n"
	indent = indent + 2
	for k, v in pairs(tbl) do
		toprint = toprint .. string.rep(" ", indent)
		if type(k) == "number" then
			toprint = toprint .. "[" .. k .. "] = "
		elseif type(k) == "string" then
			toprint = toprint .. k .. "= "
		end
		if type(v) == "number" then
			toprint = toprint .. v .. ",\r\n"
		elseif type(v) == "string" then
			toprint = toprint .. '"' .. v .. '",\r\n'
		elseif type(v) == "table" then
			toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
		else
			toprint = toprint .. '"' .. tostring(v) .. '",\r\n'
		end
	end
	toprint = toprint .. string.rep(" ", indent - 2) .. "}"
	return toprint
end

local function table_merge_all(into, from)
	local stack = {}
	local node1 = into
	local node2 = from
	while true do
		for k, v in pairs(node2) do
			if type(v) == "table" and type(node1[k]) == "table" then
				table.insert(stack, { node1[k], node2[k] })
			else
				node1[k] = v
			end
		end
		if #stack > 0 then
			local t = stack[#stack]
			node1, node2 = t[1], t[2]
			stack[#stack] = nil
		else
			break
		end
	end
	return into
end

function mergeTables(original, modified)
	local merged = {}
	local keys = {}
	for k, v in pairs(original) do
		if type(v) == "table" and (k == "highlight" or k == "bookmarks") then
			keys = {}
			if modified[k] then
				merged[k] = mergeTables(v, modified[k])
			else
				merged[k] = v
			end
		elseif type(v) == "table" and isArray(v) and (k == "highlight" or k == "bookmarks") then
			if modified[k] and isArray(modified[k]) then
				merged[k] = {}
				for i, item in ipairs(v) do
					if not keys[i] then
						keys[i] = true
						table.insert(merged[k], item)
					end
				end
				for i, item in ipairs(modified[k]) do
					if not keys[i] then
						keys[i] = true
						table.insert(merged[k], item)
					end
				end
			else
				merged[k] = v
			end
		else
			merged[k] = v
		end
	end
	for k, v in pairs(modified) do
		if not merged[k] then
			merged[k] = v
		end
	end
	return merged
end

function mergeTablesSimple(original, modified)
	for k, v in pairs(modified) do
		if type(v) == "table" then
			if original[k] then
				mergeTables(original[k], v)
			else
				original[k] = v
			end
		else
			original[k] = v
		end
	end
	return original
end

function updateTables(original, modified)
	local keys = {}
	for k, v in pairs(modified) do
		if type(v) == "table" and (k == "highlight" or k == "bookmarks") then
			keys = {}
			if original[k] then
				original[k] = updateTables(original[k], v)
			else
				original[k] = v
			end
		elseif type(v) == "table" and isArray(v) and (k == "highlight" or k == "bookmarks") then
			if original[k] and isArray(original[k]) then
				for i, item in ipairs(v) do
					local key = i
					if not keys[key] then
						keys[key] = true
						if type(item) == "table" then
							for j, sub_item in ipairs(item) do
								if sub_item ~= nil then
									if type(sub_item) == "table" then
										for k, inner_sub_item in ipairs(sub_item) do
											if inner_sub_item ~= nil then
												original[k][i][j][k] = inner_sub_item
											end
										end
									else
										original[k][i][j] = sub_item
									end
								end
							end
						else
							original[k][i] = item
						end
					end
				end
			else
				original[k] = v
			end
		else
			original[k] = v
		end
	end
	return original
end

function writeTable(file, tbl)
	file:write("{\n")
	for k, v in pairs(tbl) do
		if type(k) == "string" then
			file:write("  [" .. string.format("%q", k) .. "] = ")
		else
			file:write("  [" .. tostring(k) .. "] = ")
		end
		if type(v) == "table" then
			if isArray(v) then
				writeArray(file, v)
			else
				writeTable(file, v)
			end
		elseif type(v) == "string" then
			file:write(string.format("%q", v) .. ",\n")
		else
			file:write(tostring(v) .. ",\n")
		end
	end
	file:write("},\n")
end

function writeArray(file, arr)
	file:write("{\n")
	for i, v in ipairs(arr) do
		if type(v) == "table" then
			writeTable(file, v)
		elseif type(v) == "string" then
			file:write("  " .. string.format("%q", v) .. ",\n")
		else
			file:write("  " .. tostring(v) .. ",\n")
		end
	end
	file:write("},\n")
end

function isArray(tbl)
	local maxIndex = 0
	for k, _ in pairs(tbl) do
		if type(k) == "number" and k > maxIndex then
			maxIndex = k
		end
	end
	return maxIndex == #tbl
end
local orig = require("metadata_og")
local conflict = require("metadata_conf")

-- local merged = mergeTablesSimple(orig, conflict)
local merged = mergeTablesSimple(conflict, orig)
-- local merged = updateTables(orig, conflict)
print(tprint(merged))

local file = io.open("TEST_MERGED.lua", "w")
file:write("return ")
writeTable(file, merged)
file:close()
